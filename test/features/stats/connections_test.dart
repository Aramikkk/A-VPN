import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/features/route_rules/notifier/rule_groups.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/topology_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

Map<String, dynamic> _clash(String id, String host, String process, List<String> chains, {int down = 1000}) => {
  'id': id,
  'metadata': {
    'network': 'tcp',
    'destinationIP': '203.0.113.7',
    'destinationPort': '443',
    'host': host,
    'processPath': process,
  },
  'upload': 100,
  'download': down,
  'start': '2026-10-12T14:00:00.000+03:00',
  'chains': chains,
  'rule': host == 'api.telegram.org'
      ? 'final'
      : chains.first == 'direct'
      ? 'rule_set=[ru-sites] => route(direct)'
      : chains.first == 'block'
      ? 'rule_set=[ads] => reject'
      : 'rule_set=[blocked] => route(select)',
};

final _sample = [
  for (final (i, (host, app, chains, down)) in [
    (
      'rr4---sn.googlevideo.com',
      'com.google.android.youtube',
      ['🇸🇪 Доступ - Швеция 2', 'lowest', 'select'],
      182000000,
    ),
    ('i.ytimg.com', 'com.google.android.youtube', ['🇸🇪 Доступ - Швеция 2', 'lowest', 'select'], 4200000),
    ('instagram.com', 'com.instagram.android', ['🇳🇱 Доступ - Нидерланды', 'lowest', 'select'], 23000000),
    ('disk.yandex.ru', 'ru.yandex.disk', ['direct'], 640000000),
    ('yandex.ru', 'ru.yandex.disk', ['direct'], 120000),
    ('api.telegram.org', 'org.telegram.messenger', ['🇸🇪 Доступ - Швеция 2', 'lowest', 'select'], 3100000),
    ('gosuslugi.ru', 'ru.rostel', ['direct'], 900000),
    ('connectivitycheck.gstatic.com', '1000 (android.uid.system)', ['direct'], 2000),
    ('doubleclick.net', 'com.android.chrome', ['block'], 0),
    ('rutracker.org', 'com.android.chrome', ['🇳🇱 Доступ - Нидерланды', 'lowest', 'select'], 8800000),
  ].indexed)
    SeenConnection.fromClash(_clash('$i', host, app, chains, down: down))!,
];

class _Fake extends Connections {
  @override
  ConnectionsState build() => ConnectionsState(items: _sample);
}

/// one big connection: the case that drew full-height walls
class _FakeOne extends Connections {
  @override
  ConnectionsState build() => ConnectionsState(items: [_sample[2]]);
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
  test('a Clash API entry: app, site, route and server', () {
    final c = _sample.first;
    expect(c.app, 'com.google.android.youtube');
    expect(c.host, 'rr4---sn.googlevideo.com');
    expect(c.route, ConnectionRoute.vpn);
    expect(c.outbound, '🇸🇪 Швеция 2');
    expect(c.port, 443);
    expect(_sample[3].route, ConnectionRoute.direct);
    expect(_sample[3].outbound, '');
    expect(_sample[8].route, ConnectionRoute.block);
    expect(_sample[7].app, 'android.uid.system');
    expect(
      SeenConnection.appOf(r'C:\Program Files\Google\Chrome\Application\chrome.exe (exclu)'),
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    );
    expect(SeenConnection.fromClash({'id': 'x'}), isNull);
    // no host: the address
    final bare = _clash('b', '', 'x', ['direct'])..['metadata']['host'] = '';
    expect(SeenConnection.fromClash(bare)!.host, '203.0.113.7');
  });

  test('a connection saved and read back', () {
    final c = _sample.first;
    final back = SeenConnection.fromJson(c.toJson())!;
    expect(
      (back.id, back.app, back.host, back.route, back.outbound, back.down),
      (c.id, c.app, c.host, c.route, c.outbound, c.down),
    );
    expect(back.active, isFalse);
    expect(SeenConnection.fromJson({'id': 1}), isNull);
  });

  test('the app own rules read by name', () async {
    final t = await AppLocale.ru.build();
    expect(ruleLabel('domain_suffix=[ru su xn--p1ai yandex.net] => route(direct)', t), 'Российские сайты');
    expect(ruleLabel('package_name=[ru.yandex.music ru.yandex.taxi] => route(direct)', t), 'Российские приложения');
    String first(List<String> list) => 'domain_suffix=[${list.take(3).join(' ')} ...] => route(select)';
    expect(ruleLabel(first(aiDomains), t), 'ИИ');
    expect(ruleLabel(first(googleDomains), t), 'Google и YouTube');
    expect(ruleLabel(first(socialDomains), t), 'Соцсети и мессенджеры');
    expect(ruleLabel(first(otherBlockedDomains), t), 'Прочее заблокированное');
    expect(ruleLabel('package_name=[${aiApps.take(3).join(' ')} ...] => route(select)', t), 'ИИ');
    expect(ruleLabel('package_name=[${googleApps.take(3).join(' ')} ...] => route(select)', t), 'Google и YouTube');
    expect(
      ruleLabel('ip_cidr=[5.28.192.0/18 5.200.14.128/25 31.13.24.0/21 ...] => route(select)', t),
      startsWith('Соцсети и мессенджеры'),
    );
    expect(
      ruleLabel('ip_cidr=[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8 ...] => route(direct)', t),
      'Локальная сеть',
    );
    expect(ruleLabel('final', t), isNull);
    expect(ruleLabel('rule_set=[ads] => reject', t), 'ads');
  });

  test('two programs with the same file name are told apart by their folders', () async {
    final t = await AppLocale.ru.build();
    const desktop = r'C:\Program Files\WindowsApps\Claude_2.31226.1.0_x64__pzs8sxrjxfjjc\app\claude.exe';
    const code =
        r'C:\Users\u\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code\2.1.295\d2e29494ec83\claude.exe';
    expect(connectionAppName(t, const {}, r'C:\Program Files\Google\Chrome\Application\chrome.exe'), 'chrome');
    connectionAppName(t, const {}, desktop);
    connectionAppName(t, const {}, code);
    expect(connectionAppName(t, const {}, desktop), 'Claude');
    expect(connectionAppName(t, const {}, code), 'Claude Code');
  });

  test('older closed connections added up keep their traffic and their count', () {
    final a = _sample[3].closed();
    final b = _sample[4].closed();
    final sum = a.plus(b, 'sum:x');
    expect((sum.down, sum.up, sum.count, sum.active), (a.down + b.down, a.up + b.up, 2, false));
    final back = SeenConnection.fromJson(sum.toJson())!;
    expect(back.count, 2);
    final group = groupConnections([sum, _sample[6]], (c) => c.app).firstWhere((g) => g.key == 'ru.yandex.disk');
    expect((group.count, group.direct, group.total), (2, 2, sum.total));
  });

  test('servers in short: one by name, several by their flags, each country once', () {
    expect(serverFlags(['🇸🇪 Швеция 3']), '🇸🇪 Швеция 3');
    expect(serverFlags(['🇸🇪 Швеция 3', '🇸🇪 Швеция 2', '🇫🇮 Финляндия']), '🇸🇪 🇫🇮');
    expect(serverFlags(['🇸🇪 Швеция 3', 'Дом']), '🇸🇪 Дом');
    expect(serverFlags(const []), '');
  });

  test('grouped by app, the most traffic first, both ways counted', () {
    final groups = groupConnections(_sample, (c) => c.app);
    expect(groups.first.key, 'ru.yandex.disk');
    expect(groups.first.mainRoute, ConnectionRoute.direct);
    final chrome = groups.firstWhere((g) => g.key == 'com.android.chrome');
    expect(chrome.mixed, isTrue);
    expect(chrome.servers, {'🇳🇱 Нидерланды'});
  });

  test('ping spread: average, fastest, slowest and jitter of the answered probes', () {
    expect(pingSpread(const []), isNull);
    expect(pingSpread(const [null, null]), isNull);
    final s = pingSpread(const [50, null, 70, 60])!;
    expect((s.avg, s.min, s.max, s.jitter), (60, 50, 70, 15));
  });

  testWidgets('the Connections tab renders', (tester) async {
    await _loadFont('Segoe UI Variable Text', [r'C:\Windows\Fonts\SegUIVar.ttf']);
    await _loadFont('MaterialIcons', [
      r'./tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
    await _loadFont('MaterialIcons', [
      r'C:\dev	oolslutterin\cachertifacts\material_fonts\MaterialIcons-Regular.otf',
    ]);
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    final accent = AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'neonRed');
    final theme = AppTheme(
      AppThemeMode.dark,
      '',
      accent: accent,
      style: AraStyle.values.byName(Platform.environment['STYLE'] ?? 'classic'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationsProvider.overrideWith((ref) async => t),
          connectionsProvider.overrideWith(_Fake.new),
          installedAppsProvider.overrideWith((ref) async => const {}),
        ],
        child: MaterialApp(
          theme: theme.darkTheme(null),
          home: Consumer(
            builder: (context, ref, _) =>
                !ref.watch(translationsProvider).hasValue ? const SizedBox() : const ConnectionsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Яндекс'), findsNothing);
    expect(find.textContaining('Швеция 2'), findsWidgets);
    if (Platform.environment['RENDER'] == '1') {
      await tester.tap(find.text('com.google.android.youtube').first);
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/connections.png'));
    }
  });

  for (final (name, size, one, dark) in [
    ('topology_phone', const Size(400, 860), false, true),
    ('topology_unfolded', const Size(880, 860), false, false),
    ('topology_one', const Size(400, 860), true, false),
  ]) {
    testWidgets('the Topology tab renders: $name', (tester) async {
      await _loadFont('Segoe UI', [r'C:/Windows/Fonts/segoeui.ttf', r'C:/Windows/Fonts/seguisb.ttf']);
      await _loadFont('MaterialIcons', [
        r'./tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ]);
      await tester.binding.setSurfaceSize(size);
      final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
      final accent = AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'neonRed');
      final theme = AppTheme(
        dark ? AppThemeMode.dark : AppThemeMode.light,
        '',
        accent: accent,
        style: AraStyle.values.byName(Platform.environment['STYLE'] ?? 'classic'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationsProvider.overrideWith((ref) async => t),
            connectionsProvider.overrideWith(one ? _FakeOne.new : _Fake.new),
            installedAppsProvider.overrideWith((ref) async => const {}),
          ],
          child: MaterialApp(
            theme: dark ? theme.darkTheme(null) : theme.lightTheme(null),
            home: Consumer(
              builder: (context, ref, _) =>
                  !ref.watch(translationsProvider).hasValue ? const SizedBox() : const TopologyPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
      if (Platform.environment['RENDER'] == '1') {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      }
    });
  }

  test('the Connections and Topology day runs from 03:00 to 03:00', () {
    expect(statsDayStart(DateTime(2026, 10, 13, 2, 59)), DateTime(2026, 10, 12, 3));
    expect(statsDayStart(DateTime(2026, 10, 13, 3)), DateTime(2026, 10, 13, 3));
    expect(statsDayStart(DateTime(2026, 10, 13, 23, 59)), DateTime(2026, 10, 13, 3));
    expect(statsDayStart(DateTime(2026, 11, 1, 1)), DateTime(2026, 10, 31, 3));
  });

  test('a whitelist server keeps its mark next to the country', () {
    expect(SeenConnection.serverName('🇸🇪 LTE Only - Швеция'), '🇸🇪 Швеция · БС');
    expect(SeenConnection.serverName('🇸🇪 БС - Швеция'), '🇸🇪 Швеция · БС');
    expect(SeenConnection.serverName('🇸🇪 Доступ - Швеция 2'), '🇸🇪 Швеция 2');
    expect(serverFlags(['🇸🇪 Швеция · БС', '🇸🇪 Швеция 2', '🇫🇮 Финляндия']), '🇸🇪БС 🇸🇪 🇫🇮');
  });
}
