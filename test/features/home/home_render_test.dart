// Renders the home screen in Graphite and Editorial, by day and by night, connected and not, with Sigma's servers,
// to look at the styles: RENDER=1 flutter test --update-goldens test/features/home/home_render_test.dart
@Tags(['render'])
library;

import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/router/adaptive_layout/nav_icons.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_path_resolver.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

var _connected = true;

class _Conn extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(_connected ? const Connected() : const Disconnected());
}

final _servers = [
  ('lowest', '', 0, true),
  ('fi', '🇫🇮 Доступ - Финляндия', 49, false),
  ('se2', '🇸🇪 Доступ - Швеция 2', 64, false),
  ('nl', '🇳🇱 Доступ - Нидерланды', 71, false),
  ('de', '🇩🇪 Доступ - Германия', 83, false),
  ('pl5', '🇵🇱 Доступ - Польша § 5', 108, false),
  ('us', '🇺🇸 Доступ - США', 162, false),
  ('gb', '🇬🇧 Доступ - Великобритания', 78, false),
  ('fit', '🇫🇮 Доступ - Финляндия (Тестовый)', 66, false),
  ('ee', '🇪🇪 Доступ - Эстония', 88, false),
  ('sk', '🇸🇰 Доступ - Словакия', 90, false),
];

class _Proxies extends ProxiesOverviewNotifier {
  @override
  Stream<OutboundGroup?> build() => Stream.value(
    _connected
        ? OutboundGroup(
            tag: 'select',
            selected: 'lowest',
            items: [
              for (final (tag, display, delay, group) in _servers)
                OutboundInfo(
                  tag: tag,
                  tagDisplay: display,
                  type: group ? 'urltest' : 'vless',
                  urlTestDelay: group ? 108 : delay,
                  isGroup: group,
                  isVisible: true,
                  groupSelectedTag: group ? 'pl5' : null,
                ),
            ],
          )
        : null,
  );
}

class _Profile extends ActiveProfile {
  @override
  Stream<ProfileEntity?> build() => Stream.value(
    ProfileEntity.remote(
      id: 'sigma',
      active: true,
      name: 'Доступ',
      url: 'https://example.invalid',
      lastUpdate: DateTime(2026, 10, 12, 15),
      subInfo: SubscriptionInfo(
        upload: 1 << 30,
        download: 11 << 30,
        total: 100 << 30,
        expire: DateTime.now().add(const Duration(days: 23, hours: 2)),
      ),
    ),
  );
}

class _Stats extends StatsNotifier {
  @override
  Stream<SystemInfo> build() => Stream.value(
    SystemInfo(uplink: Int64(640 * 1024), downlink: Int64(12 * 1024 * 1024 + 420 * 1024), connectionsIn: 31),
  );
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final f = File(file);
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    const fonts = 'assets/fonts';
    await _loadFont('Manrope', [
      for (final w in [400, 500, 600, 700, 800]) '$fonts/Manrope-$w.ttf',
    ]);
    await _loadFont('Golos Text', [
      for (final w in [400, 500, 600, 700, 800]) '$fonts/GolosText-$w.ttf',
    ]);
    await _loadFont('Unbounded', ['$fonts/Unbounded-600.ttf', '$fonts/Unbounded-800.ttf']);
    await _loadFont('JetBrains Mono', [
      for (final w in [500, 700, 800]) '$fonts/JetBrainsMono-$w.ttf',
    ]);
    await _loadFont('Emoji', ['$fonts/Emoji.ttf']);
    await _loadFont('MaterialIcons', [
      './tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final style in [AraStyle.graphite, AraStyle.editorial, AraStyle.cyberpunk]) {
    for (final (dark, connected) in [(true, true), (false, false), (false, true), (true, false)]) {
      final name = '${style.name}_${dark ? 'night' : 'day'}_${connected ? 'on' : 'off'}';
      testWidgets('home: $name', (tester) async {
        _connected = connected;
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(390, 844));
        final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
        final prefs = await tester.runAsync(SharedPreferences.getInstance);
        final accent = AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'monoRed');
        final theme = AppTheme(AppThemeMode.system, '', accent: accent, style: style);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationsProvider.overrideWith((ref) async => t),
              sharedPreferencesProvider.overrideWith((ref) async => prefs!),
              connectionNotifierProvider.overrideWith(_Conn.new),
              proxiesOverviewNotifierProvider.overrideWith(_Proxies.new),
              activeProfileProvider.overrideWith(_Profile.new),
              statsNotifierProvider.overrideWith(_Stats.new),
              profilePathResolverProvider.overrideWithValue(ProfilePathResolver(Directory.systemTemp)),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? theme.darkTheme(null) : theme.lightTheme(null),
              home: Consumer(
                builder: (context, ref, _) =>
                    !ref.watch(translationsProvider).hasValue || !ref.watch(sharedPreferencesProvider).hasValue
                    ? const SizedBox()
                    : Scaffold(
                        appBar: AppBar(title: const Text('A-VPN')),
                        body: const AraHomeBody(),
                        bottomNavigationBar: NavigationBar(
                          destinations: [
                            for (final (svg, label) in [
                              (NavIcons.home, 'Главная'),
                              (NavIcons.stats, 'Статистика'),
                              (NavIcons.connections, 'Соединения'),
                              (NavIcons.topology, 'Топология'),
                              (NavIcons.settings, 'Настройки'),
                            ])
                              NavigationDestination(
                                icon: NavIcon(svg),
                                selectedIcon: NavIcon(svg, selected: true),
                                label: label,
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(AraHomeBody), findsOneWidget);
        if (Platform.environment['RENDER'] == '1') {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_$name.png'));
        }
        // the timers (the clock, the ring) end with the widget
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
