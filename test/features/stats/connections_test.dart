import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
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
  'rule': 'rule_set=[blocked] => route(select)',
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
    final accent = AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'monoRed');
    final theme = AppTheme(AppThemeMode.dark, '', accent: accent);
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
}
