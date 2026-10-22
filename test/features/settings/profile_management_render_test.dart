import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/country_ping.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_path_resolver.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/settings/overview/sections/profile_management_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Conn extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(const Connected());
}

class _Profiles extends ProfilesNotifier {
  @override
  Stream<List<ProfileEntity>> build() => Stream.value([
    ProfileEntity.local(id: 'p1', active: true, name: 'Sigma', lastUpdate: DateTime(2026, 10, 22)),
    ProfileEntity.local(id: 'p2', active: false, name: 'Второй провайдер', lastUpdate: DateTime(2026, 10, 22)),
  ]);
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final f = File(file);
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

Map<String, dynamic> _server(String tag, String host) => {
  'type': 'vless',
  'tag': tag,
  'server': host,
  'server_port': 443,
  'uuid': host,
};

void main() {
  testWidgets('Profile management lists the countries with their ping, per network', (tester) async {
    await _loadFont('MaterialIcons', [
      r'./tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
    await _loadFont('Segoe UI', [r'C:/Windows/Fonts/segoeui.ttf', r'C:/Windows/Fonts/seguisb.ttf']);
    await _loadFont('Segoe UI Variable Text', [r'C:\Windows\Fonts\SegUIVar.ttf']);
    await tester.binding.setSurfaceSize(const Size(400, 860));
    final dir = Directory.systemTemp.createTempSync('pm_test');
    final resolver = ProfilePathResolver(dir);
    resolver.directory.createSync(recursive: true);
    resolver
        .file('p1')
        .writeAsStringSync(
          jsonEncode({
            'outbounds': [
              _server('🇸🇪 Доступ - Швеция § 1', 'se1.example'),
              _server('🇸🇪 Доступ - Швеция 2 § 2', 'se2.example'),
              _server('🇩🇪 Доступ - Германия § 3', 'de1.example'),
              _server('🇫🇮 Доступ - Финляндия § 4', 'fi1.example'),
              _server('🇸🇪 LTE Only - Швеция § 9', 'se9.example'),
              _server('🇪🇪 LTE Only - Эстония § 5', 'ee1.example'),
              _server('🇵🇱 LTE Only - Польша § 6', 'pl1.example'),
              _server('🇳🇱 Доступ - Нидерланды § 7', 'nl1.example'),
              _server('🇯🇵 Доступ - Япония § 8', 'jp1.example'),
            ],
          }),
        );
    resolver
        .file('p2')
        .writeAsStringSync(
          jsonEncode({
            'outbounds': [_server('🇱🇻 Латвия § 1', 'lv1.example'), _server('🇱🇹 Литва § 2', 'lt1.example')],
          }),
        );
    // the pings stand-in: a number by the name
    CountryPing.connector = (host, port, timeout) async => switch (host.substring(0, 2)) {
      'se' => 48,
      'de' => 72,
      'fi' => 56,
      'ee' => 130,
      'pl' => 95,
      'nl' => 220,
      'jp' => 260,
      _ => null,
    };
    SharedPreferences.setMockInitialValues({
      'europe-only-servers': true,
      'profile_countries_off': jsonEncode({
        'p1': {
          'mobile': ['DE', 'NL', 'PL:bs'],
          'wifi': ['EE', 'PL'],
        },
      }),
    });
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    final theme = AppTheme(AppThemeMode.dark, '', accent: AraAccent.neonRed, style: AraStyle.contrast);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationsProvider.overrideWith((ref) async => t),
          sharedPreferencesProvider.overrideWith((ref) async => prefs!),
          connectionNotifierProvider.overrideWith(_Conn.new),
          profilesNotifierProvider.overrideWith(_Profiles.new),
          profilePathResolverProvider.overrideWithValue(resolver),
        ],
        child: MaterialApp(
          theme: theme.darkTheme(null),
          home: Consumer(
            builder: (context, ref, _) =>
                !ref.watch(translationsProvider).hasValue || !ref.watch(sharedPreferencesProvider).hasValue
                ? const SizedBox()
                : const ProfileManagementPage(),
          ),
        ),
      ),
    );
    // the file is read for real: give it the time, a frame at a time
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    }
    await tester.pump(const Duration(milliseconds: 600));
    // the active profile is open at once; its countries are listed, with the ping
    expect(find.textContaining('Швеция'), findsWidgets);
    expect(find.textContaining('48 ms'), findsWidgets);
    expect(find.textContaining('Германия'), findsWidgets);
    expect(find.textContaining('Wi‑Fi'), findsWidgets);
    expect(find.textContaining('LTE'), findsWidgets);
    expect(find.textContaining('Япония'), findsOneWidget);
    if (Platform.environment['RENDER'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_management.png'));
    }
    // the LTE list: its own, with its own countries switched off
    await tester.tap(find.text('LTE').first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Германия'), findsWidgets);
    // the whitelist servers are a list of their own, with the country's mark
    expect(find.textContaining('Эстония БС'), findsOneWidget);
    expect(find.textContaining('БЕЛЫЕ СПИСКИ'), findsWidgets);
    if (Platform.environment['RENDER'] == '1') {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/profile_management_lte.png'));
    }
  });
}
