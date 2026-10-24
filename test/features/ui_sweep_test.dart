// Goes through every screen in every style, by day and by night, on a phone, a small phone, the unfolded Fold and
// a PC window, taps the switches, chips and pickers on it, and fails on any error or overflowing text.
// Pictures on request: RENDER=1 flutter test --update-goldens test/features/ui_sweep_test.dart
@Tags(['render'])
library;

import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/features/settings/overview/sections/routing_options_page.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
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
import 'package:hiddify/features/settings/overview/sections/general_page.dart';
import 'package:hiddify/features/settings/overview/sections/themes_page.dart';
import 'package:hiddify/features/settings/overview/sections/sites_page.dart';
import 'package:hiddify/features/settings/overview/settings_page.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/speed_page.dart';
import 'package:hiddify/features/stats/widget/topology_page.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Conn extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(const Connected());
}

final _servers = [
  ('lowest', '', 0, true),
  ('fi', '🇫🇮 Доступ - Финляндия', 49, false),
  ('se2', '🇸🇪 Доступ - Швеция 2', 64, false),
  ('nl', '🇳🇱 Доступ - Нидерланды', 71, false),
  ('pl5', '🇵🇱 Доступ - Польша § 5', 108, false),
  ('us', '🇺🇸 Доступ - США', 162, false),
  ('gb', '🇬🇧 Доступ - Великобритания', 78, false),
  ('fit', '🇫🇮 Доступ - Финляндия (Тестовый)', 66, false),
  ('gr', '🇬🇷 Доступ - Греция', 0, false),
];

class _Proxies extends ProxiesOverviewNotifier {
  @override
  Stream<OutboundGroup?> build() => Stream.value(
    OutboundGroup(
      tag: 'select',
      selected: 'lowest',
      items: [
        for (final (tag, display, delay, group) in _servers)
          OutboundInfo(
            tag: tag,
            tagDisplay: display,
            type: group ? 'urltest' : 'vless',
            urlTestDelay: group ? 108 : (delay == 0 ? 65535 : delay),
            isGroup: group,
            isVisible: true,
            groupSelectedTag: group ? 'pl5' : null,
          ),
      ],
    ),
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
        expire: DateTime.now().add(const Duration(days: 23)),
      ),
    ),
  );
}

class _Stats extends StatsNotifier {
  @override
  Stream<SystemInfo> build() => Stream.value(
    SystemInfo(
        uplink: Int64(138),
        downlink: Int64(151),
        uplinkTotal: Int64(13 * 1024 * 1024),
        downlinkTotal: Int64(122 * 1024 * 1024),
        connectionsIn: 52,
      )
      ..unknownFields.mergeVarintField(100, Int64(9 * 1024 * 1024))
      ..unknownFields.mergeVarintField(101, Int64(127 * 1024 * 1024)),
  );
}

class _History extends SpeedHistory {
  @override
  List<({int down, int up})> build() => [
    for (var i = 0; i < 60; i++) (down: i % 7 == 3 ? 31000 : 300, up: i % 9 == 2 ? 28000 : 150),
  ];
}

/// a steady ping with one stray spike and a lost probe: the case that squashed every other bar
class _Quality extends ConnectionQuality {
  @override
  List<int?> build() => [for (var i = 0; i < 30; i++) i == 18 ? 1409 : (i == 19 ? null : 112 + (i * 7) % 60)];
}

Map<String, dynamic> _clash(int i, String host, String app, List<String> chains, int down) => {
  'id': '$i',
  'metadata': {
    'network': 'tcp',
    'destinationIP': '203.0.113.7',
    'destinationPort': '443',
    'host': host,
    'processPath': app,
  },
  'upload': down ~/ 10,
  'download': down,
  'start': '2026-10-12T14:00:00.000+03:00',
  'chains': chains,
  'rule': chains.first == 'direct'
      ? 'domain_suffix=[ru su xn--p1ai yandex.net] => route(direct)'
      : 'domain_suffix=[10minutemail.com 1337x.to 24.kg ...] => route(select)',
};

class _Connections extends Connections {
  @override
  ConnectionsState build() => ConnectionsState(
    items: [
      for (final (i, (host, app, chains, down)) in [
        ('rr4---sn.googlevideo.com', 'com.google.android.youtube', ['🇬🇷 Доступ - Греция', 'lowest', 'select'], 182e6),
        ('instagram.com', 'com.instagram.android', ['🇳🇱 Доступ - Нидерланды', 'lowest', 'select'], 23e6),
        ('disk.yandex.ru', 'ru.yandex.disk', ['direct'], 640e6),
        (
          'api.anthropic.com',
          r'C:\Users\user\AppData\Local\AnthropicClaude\claude.exe',
          ['🇬🇷 Доступ - Греция'],
          4e6,
        ),
        ('gosuslugi.ru', 'ru.rostel', ['direct'], 9e5),
        ('a-very-long-host-name.with.many.parts.example-cdn-edge-node.net', 'com.android.chrome', ['direct'], 2e6),
      ].indexed)
        SeenConnection.fromClash(_clash(i, host, app, chains, down.toInt()))!,
    ],
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

typedef _Screen = ({String name, Widget Function() page, List<Finder Function()> taps});

final _screens = <_Screen>[
  (
    name: 'home',
    page: () => const Scaffold(body: AraHomeBody()),
    taps: [() => find.textContaining('Нидерланды'), () => find.textContaining('Финляндия')],
  ),
  (
    name: 'speed',
    page: SpeedPage.new,
    taps: [() => find.text('10м'), () => find.text('1ч'), () => find.text('24ч'), () => find.text('Всё')],
  ),
  (
    name: 'connections',
    page: ConnectionsPage.new,
    taps: [() => find.byType(FilterChip), () => find.byType(ChoiceChip)],
  ),
  (name: 'topology', page: TopologyPage.new, taps: [() => find.byType(FilterChip), () => find.byType(ChoiceChip)]),
  (name: 'settings', page: SettingsPage.new, taps: []),
  (name: 'general', page: GeneralPage.new, taps: [() => find.byType(Switch)]),
  (name: 'launch', page: () => const GeneralPage(connection: true), taps: []),
  (name: 'servers', page: ServersOptionsPage.new, taps: [() => find.byType(Switch)]),
  (name: 'themes', page: ThemesPage.new, taps: []),
  (name: 'sites', page: SitesPage.new, taps: [() => find.byType(Switch)]),
  (name: 'routing', page: () => const RoutingOptionsPage(routeRule: null), taps: []),
];

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
    await _loadFont('Segoe UI', ['C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/seguisb.ttf']);
    // the classic style's default font, which tests otherwise draw as boxes: Segoe UI stands in for Android's Roboto
    await _loadFont('Roboto', ['C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/seguisb.ttf']);
    await _loadFont('MaterialIcons', [
      './tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  final only = Platform.environment['SCREEN'];
  for (final screen in _screens.where((s) => only == null || s.name == only)) {
    for (final style in AraStyle.values) {
      testWidgets('${screen.name}: ${style.name}', (tester) async {
        final problems = <String>[];
        final previous = FlutterError.onError;
        var where = '';
        FlutterError.onError = (details) {
          final text = details.exceptionAsString().split('\n').first;
          if (problems.isEmpty && Platform.environment['STACK'] == '1') previous?.call(details);
          // the test's own limits, not the app's: no router for the settings' sections, no Windows autostart
          if (text.contains('unknown route name') || text.contains('Unsupported operation: enable')) return;
          problems.add('$where: $text');
        };
        try {
          final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
          for (final (size, sizeName) in [
            (const Size(390, 844), 'phone'),
            (const Size(320, 640), 'small'),
            (const Size(880, 900), 'unfolded'),
            (const Size(760, 1000), 'pc'),
          ]) {
            for (final dark in [true, false]) {
              // ACCENTS=oledYellow,oledRed picks the themes (and names the pictures after them)
              final picked = Platform.environment['ACCENTS']?.split(',').map(AraAccent.values.byName).toList();
              for (final accent in picked ?? [AraAccent.oled, AraAccent.neonRed, AraAccent.neonYellow]) {
                where = '${screen.name} ${style.name} ${accent.name} ${dark ? 'night' : 'day'} $sizeName';
                SharedPreferences.setMockInitialValues({'ara_style': style.name});
                final prefs = await tester.runAsync(SharedPreferences.getInstance);
                await tester.binding.setSurfaceSize(size);
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
                      speedHistoryProvider.overrideWith(_History.new),
                      connectionQualityProvider.overrideWith(_Quality.new),
                      connectionsProvider.overrideWith(_Connections.new),
                      installedAppsProvider.overrideWith((ref) async => const {}),
                      profilePathResolverProvider.overrideWithValue(ProfilePathResolver(Directory.systemTemp)),
                      appDirectoriesProvider.overrideWith(_Dirs.new),
                    ],
                    child: MaterialApp.router(
                      debugShowCheckedModeBanner: false,
                      theme: dark ? theme.darkTheme(null) : theme.lightTheme(null),
                      routerConfig: GoRouter(
                        routes: [
                          GoRoute(
                            path: '/',
                            builder: (_, _) => Consumer(
                              builder: (context, ref, _) =>
                                  !ref.watch(translationsProvider).hasValue ||
                                      !ref.watch(sharedPreferencesProvider).hasValue ||
                                      !ref.watch(appDirectoriesProvider).hasValue
                                  ? const SizedBox()
                                  : screen.page(),
                            ),
                            // the settings' sections by name, as blank pages: the settings list links to them
                            routes: [
                              for (final name in const [
                                'profiles',
                                'general',
                                'connectionOptions',
                                'themes',
                                'routingOptions',
                                'serversOptions',
                                'dnsOptions',
                                'inboundOptions',
                                'logs',
                                'about',
                              ])
                                GoRoute(name: name, path: name, builder: (_, _) => const SizedBox()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                for (var i = 0; i < 6; i++) {
                  await tester.pump(const Duration(milliseconds: 200));
                }
                for (final tap in screen.taps) {
                  final found = tap();
                  final n = found.evaluate().length;
                  for (var k = 0; k < n && k < 4; k++) {
                    final one = tap().at(k);
                    if (one.evaluate().isEmpty) break;
                    await tester.ensureVisible(one);
                    await tester.pump();
                    await tester.tap(one, warnIfMissed: false);
                    for (var i = 0; i < 3; i++) {
                      await tester.pump(const Duration(milliseconds: 200));
                    }
                  }
                }
                if (Platform.environment['RENDER'] == '1' &&
                    (picked != null || accent == AraAccent.oled) &&
                    sizeName != 'small') {
                  await expectLater(
                    find.byType(Router<Object>),
                    matchesGoldenFile(
                      'goldens/sweep/${screen.name}_${style.name}${picked == null ? '' : '_${accent.name}'}_${dark ? 'night' : 'day'}_$sizeName.png',
                    ),
                  );
                }
                await tester.pumpWidget(const SizedBox());
                await tester.pump(const Duration(seconds: 1));
              }
            }
          }
        } finally {
          FlutterError.onError = previous;
        }
        expect(problems.toSet().toList(), isEmpty);
      });
    }
  }
}

/// A fresh folder each time, so the routing list starts as on a new install.
class _Dirs extends AppDirectories {
  @override
  Future<Directories> build() async {
    final dir = Directory.systemTemp.createTempSync('ara_sweep');
    return (baseDir: dir, workingDir: dir, tempDir: dir);
  }
}
