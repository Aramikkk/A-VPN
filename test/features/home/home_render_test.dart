// Renders the home screen in Graphite and Editorial, by day and by night, connected and not, with Sigma's servers,
// to look at the styles: RENDER=1 flutter test --update-goldens test/features/home/home_render_test.dart
@Tags(['render'])
library;

import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/router/adaptive_layout/my_adaptive_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/router/adaptive_layout/nav_icons.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/connection/notifier/shown_connection.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_path_resolver.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/stats/notifier/site_latency.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/traffic_panel.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

var _connected = true;
late StreamController<SystemInfo> _statsUpdates;

class _Conn extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(_connected ? const Connected() : const Disconnected());
}

class _ShownConnection extends ShownConnection {
  @override
  ConnectionStatus build() => _connected ? const Connected() : const Disconnected();
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
  ('lte', '🇵🇱 Доступ - Польша LTE Only', 95, false),
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
                  // WL=1: Auto on a whitelist server; AUTO=<tag>: on that one
                  groupSelectedTag: group
                      ? ((Platform.environment['AUTO'] ?? '').isNotEmpty
                            ? Platform.environment['AUTO']
                            : (Platform.environment['WL'] == '1' ? 'lte' : 'pl5'))
                      : null,
                ),
            ],
          )
        : null,
  );
}

class _ActiveProxy extends ActiveProxyNotifier {
  @override
  Stream<OutboundInfo> build() =>
      Stream.value(OutboundInfo(tag: 'pl5', tagDisplay: '🇵🇱 Доступ - Польша', urlTestDelay: 108));
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

class _SessionTotals extends SessionTotalsNotifier {
  @override
  SessionTotals build() => (up: 2 * 1024 * 1024, down: 8 * 1024 * 1024, vpnUp: 0, vpnDown: 8 * 1024 * 1024);
}

class _Stats extends StatsNotifier {
  @override
  Stream<SystemInfo> build() async* {
    yield SystemInfo(uplink: Int64(640 * 1024), downlink: Int64(12 * 1024 * 1024 + 420 * 1024), connectionsIn: 31)
      // the session's start (the core's field 102), long before the connections listed
      ..unknownFields.mergeVarintField(
        102,
        Int64(DateTime.now().subtract(const Duration(hours: 1, minutes: 14)).millisecondsSinceEpoch),
      );
    yield* _statsUpdates.stream;
  }
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

  for (final style in [AraStyle.graphite, AraStyle.contrast, AraStyle.glass]) {
    for (final (dark, connected) in [(true, true), (false, false), (false, true), (true, false)]) {
      final name = '${style.name}_${dark ? 'night' : 'day'}_${connected ? 'on' : 'off'}';
      testWidgets('home: $name', (tester) async {
        final network = Platform.environment['NETWORK'] == 'mobile' ? 'mobile' : 'wifi';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('com.aravpn.app/network'),
          (call) async => call.method == 'underlyingNetwork' ? network : null,
        );
        tester.binding.defaultBinaryMessenger.setMockStreamHandler(
          const EventChannel('com.aravpn.app/network/events'),
          MockStreamHandler.inline(
            onListen: (_, sink) {
              sink.success(network);
              return null;
            },
          ),
        );
        _connected = connected;
        _statsUpdates = StreamController<SystemInfo>();
        addTearDown(() => _statsUpdates.close());
        // BG=<backdrop>, PAL=<palette>: Contrast's look
        SharedPreferences.setMockInitialValues({
          if ((Platform.environment['BG'] ?? '').isNotEmpty) 'contrast_backdrop': Platform.environment['BG']!,
          if ((Platform.environment['PAL'] ?? '').isNotEmpty) 'contrast_palette': Platform.environment['PAL']!,
          // CLARITY=<weak|medium|strong>: how see-through the blocks are
          if ((Platform.environment['CLARITY'] ?? '').isNotEmpty) 'contrast_clarity': Platform.environment['CLARITY']!,
        });
        // UNFOLDED=1: the inner screen, 1968 x 2184 at 2.625 (about 750 x 832), servers left and traffic right
        final pcw = Platform.environment['PCW'] == '1';
        final unfolded = Platform.environment['UNFOLDED'] == '1' || pcw;
        // PC=1: the computer's home pane in the default window (1048 x 904 less the side bar and the title bar)
        final pc = Platform.environment['PC'] == '1';
        // LAND=1: the folded phone turned, about 960 x 411
        final land = Platform.environment['LAND'] == '1';
        await tester.binding.setSurfaceSize(
          pcw
              ? const Size(960, 828)
              : pc
              ? const Size(745, 870)
              : (unfolded ? const Size(750, 832) : (land ? const Size(960, 411) : const Size(411, 960))),
        );
        // the screen size the app reads too (MediaQuery), not only the surface drawn on
        // the folded Fold 7: 1080 x 2520 at 2.625, about 411 x 960
        tester.view.physicalSize = pcw
            ? const Size(960, 828)
            : pc
            ? const Size(745, 870)
            : (unfolded ? const Size(1968, 2184) : (land ? const Size(2520, 1080) : const Size(1080, 2520)));
        tester.view.devicePixelRatio = pc || pcw ? 1 : 2.625;
        if (land) {
          tester.view.padding = const FakeViewPadding(top: 24 * 2.625, bottom: 24 * 2.625);
          tester.view.viewPadding = const FakeViewPadding(top: 24 * 2.625, bottom: 24 * 2.625);
        }
        addTearDown(tester.view.reset);
        final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
        final prefs = await tester.runAsync(SharedPreferences.getInstance);
        final accent = AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'neonRed');
        // GLASS=<scheme>: Glass in that scheme, by day or by night as the others
        final glassScheme = GlassScheme.values.byName(Platform.environment['GLASS'] ?? 'lemonade');
        final glass = style == AraStyle.glass;
        final theme = AppTheme(
          AppThemeMode.system,
          '',
          accent: accent,
          style: style,
          glassScheme: glassScheme,
          contrastPalette: ContrastPalette.values.byName(
            (Platform.environment['PAL'] ?? '').isEmpty ? 'claude' : Platform.environment['PAL']!,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationsProvider.overrideWith((ref) async => t),
              sharedPreferencesProvider.overrideWith((ref) async => prefs!),
              connectionNotifierProvider.overrideWith(_Conn.new),
              shownConnectionProvider.overrideWith(_ShownConnection.new),
              proxiesOverviewNotifierProvider.overrideWith(_Proxies.new),
              activeProxyNotifierProvider.overrideWith(_ActiveProxy.new),
              activeProfileProvider.overrideWith(_Profile.new),
              statsNotifierProvider.overrideWith(_Stats.new),
              sessionTotalsProvider.overrideWith(_SessionTotals.new),
              profilePathResolverProvider.overrideWithValue(ProfilePathResolver(Directory.systemTemp)),
              connectionsProvider.overrideWith(_Connections.new),
              connectionQualityProvider.overrideWith(_Quality.new),
              siteLatencyProvider.overrideWith(_Sites.new),
              // SITEFLAGS=1: each site through its own server (Settings → Ping → Sites), its flag on the tile
              if (Platform.environment['SITEFLAGS'] == '1')
                siteServersProvider.overrideWith(
                  (ref) => Stream.value(const {
                    'instagram': '🇫🇮 Финляндия',
                    'whatsapp': '🇵🇱 Польша',
                    'telegram': '🇱🇻 Латвия',
                    'chatgpt': '🇵🇱 Польша 2',
                    'youtube': '🇫🇮 Финляндия 3',
                  }),
                ),
              installedAppsProvider.overrideWith(
                (ref) async => {
                  'com.google.android.youtube': (name: 'YouTube', icon: null),
                  'com.instagram.android': (name: 'Instagram', icon: null),
                  'com.anthropic.claude': (name: 'Claude', icon: null),
                  'ru.yandex.disk': (name: 'Яндекс Диск', icon: null),
                  'ru.sberbankmobile': (name: 'СберБанк', icon: null),
                },
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? theme.darkTheme(null) : theme.lightTheme(null),
              builder: (context, child) => style == AraStyle.contrast
                  ? ContrastGlow(child: child!)
                  : glass
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: GlassBackdrop(look: glassScheme.look(dark ? Brightness.dark : Brightness.light)),
                        ),
                        child!,
                      ],
                    )
                  : child!,
              home: Consumer(
                builder: (context, ref, _) =>
                    !ref.watch(translationsProvider).hasValue || !ref.watch(sharedPreferencesProvider).hasValue
                    ? const SizedBox()
                    : Scaffold(
                        // Contrast: the page on its light, as the home page draws it
                        backgroundColor: style == AraStyle.contrast ? Colors.transparent : null,
                        appBar: AppBar(
                          title: const Text('A-VPN'),
                          backgroundColor: style == AraStyle.contrast ? Colors.transparent : null,
                        ),
                        body: unfolded && style == AraStyle.contrast
                            // Contrast unfolded: the folded column on the left, the connections on the right, the
                            // panel under both
                            ? const Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(flex: 11, child: AraHomeBody()),
                                        Expanded(flex: 10, child: _ShellPage(child: ConnectionsPage(embedded: true))),
                                      ],
                                    ),
                                  ),
                                  ContrastShellDock(),
                                ],
                              )
                            : unfolded
                            ? const Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 11, child: AraHomeBody(traffic: false)),
                                  Expanded(
                                    flex: 9,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(0, 4, 16, 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 10), child: Text('ТРАФИК')),
                                          Expanded(child: TrafficPanel()),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : style == AraStyle.contrast
                            // Contrast: the panel under the page, as the shell draws it
                            ? Flex(
                                direction: land ? Axis.horizontal : Axis.vertical,
                                children: [
                                  const Expanded(child: AraHomeBody()),
                                  ContrastShellDock(side: land),
                                ],
                              )
                            : const AraHomeBody(),
                        bottomNavigationBar: pc
                            ? null
                            : style == AraStyle.contrast
                            ? NavigationBar(
                                height: 62,
                                elevation: 0,
                                backgroundColor: contrastPanelColor(dark),
                                // PCW=1: a computer's menu, every page in it
                                selectedIndex: pcw ? 2 : 1,
                                destinations: [
                                  for (final (svg, label) in [
                                    if (pcw) (NavIcons.connections, 'Соединения'),
                                    (NavIcons.stats, 'Статистика'),
                                    (NavIcons.home, 'Главная'),
                                    (NavIcons.topology, 'Топология'),
                                    if (pcw) (NavIcons.settings, 'Настройки'),
                                  ])
                                    NavigationDestination(
                                      icon: NavIcon(svg),
                                      selectedIcon: NavIcon(svg, selected: true),
                                      label: label,
                                    ),
                                ],
                              )
                            : NavigationBar(
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
        expect(find.textContaining('Обычные'), findsNothing);
        expect(t.avpn.autoBestHint, 'Сервер с наименьшим пингом');
        if (connected && style == AraStyle.contrast) {
          for (final amount in ['8 МБ', '2 МБ']) {
            expect(
              find.byWidgetPredicate((w) => w is Text && w.textSpan?.toPlainText() == amount),
              findsOneWidget,
              reason: 'top counters show native session totals, not daily history',
            );
          }
        }
        // Contrast: the delay to the sites in place of the traffic (that is in Topology), six tiles
        if (connected && style == AraStyle.contrast) {
          final sites = find.byKey(const Key('contrast-sites'));
          expect(sites, findsOneWidget);
          expect(find.byKey(const Key('contrast-traffic')), findsNothing);
          for (final name in ['Instagram', 'WhatsApp', 'Telegram', 'ChatGPT', 'YouTube', 'Google Диск']) {
            expect(find.descendant(of: sites, matching: find.text(name)), findsOneWidget);
          }
        }
        // TAP=<text>: a tap on it first, to look at what it opens
        final tap = Platform.environment['TAP'];
        if (tap != null && tap.isNotEmpty) {
          await tester.tap(find.text(tap).first);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 400));
        }
        if (Platform.environment['RENDER'] == '1') {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_$name.png'));
        }
        // the timers (the clock, the ring) end with the widget
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

/// Today's connections, so the strip map under the servers has something to draw.
class _Connections extends Connections {
  @override
  ConnectionsState build() {
    final items = [
      // EMPTY=1: no traffic yet, the placeholder picture
      if (Platform.environment['EMPTY'] != '1')
        for (final (i, (app, route, server, down)) in [
          ('com.google.android.youtube', ConnectionRoute.vpn, '🇵🇱 Польша', 182e6),
          ('com.instagram.android', ConnectionRoute.vpn, '🇵🇱 Польша', 41e6),
          ('com.anthropic.claude', ConnectionRoute.vpn, '🇫🇮 Финляндия', 22e6),
          ('org.telegram.messenger', ConnectionRoute.vpn, '🇵🇱 Польша', 14e6),
          ('com.openai.chatgpt', ConnectionRoute.vpn, '🇵🇱 Польша', 9e6),
          ('com.whatsapp', ConnectionRoute.vpn, '🇵🇱 Польша', 6e6),
          ('com.spotify.music', ConnectionRoute.vpn, '🇵🇱 Польша', 4e6),
          ('com.discord', ConnectionRoute.vpn, '🇵🇱 Польша', 3e6),
          ('com.pinterest', ConnectionRoute.vpn, '🇵🇱 Польша', 2e6),
          ('ru.ozon.app.android', ConnectionRoute.direct, '', 5e6),
          ('ru.yandex.disk', ConnectionRoute.direct, '', 96e6),
          ('ru.sberbankmobile', ConnectionRoute.direct, '', 8e6),
        ].indexed)
          SeenConnection(
            id: '$i',
            app: app,
            host: 'example.com',
            port: 443,
            network: 'tcp',
            route: route,
            outbound: server,
            rule: '',
            start: DateTime.now().subtract(const Duration(minutes: 30)),
            up: (down / 20).round(),
            down: down.round(),
            active: false,
            count: 1,
          ),
    ];
    return ConnectionsState(
      items: items,
      sessionItems: items,
      routeUsage: {
        ConnectionRoute.vpn: {
          'com.google.android.youtube': [
            (
              DateTime.now().subtract(const Duration(minutes: 50)).millisecondsSinceEpoch,
              DateTime.now().millisecondsSinceEpoch,
            ),
          ],
          'com.instagram.android': [
            (
              DateTime.now().subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
              DateTime.now().millisecondsSinceEpoch,
            ),
          ],
        },
        ConnectionRoute.direct: {
          'ru.yandex.disk': [
            (
              DateTime.now().subtract(const Duration(minutes: 12)).millisecondsSinceEpoch,
              DateTime.now().millisecondsSinceEpoch,
            ),
          ],
        },
      },
    );
  }
}

/// A minute of probes through the VPN: 64 ms, one lost.
class _Quality extends ConnectionQuality {
  @override
  List<int?> build() {
    sinceConnect = ConnectionQuality.length;
    return [for (var i = 0; i < ConnectionQuality.length; i++) i == 30 ? null : 64];
  }
}

/// A page as Contrast's shell shows it: see-through over the light.
class _ShellPage extends StatelessWidget {
  const _ShellPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(data: contrastPageTheme(Theme.of(context)), child: child);
}

/// The sites' delays as measured: SITES=<ms,...> in the order of latencySites ('-' for no answer).
class _Sites extends SiteLatency {
  @override
  SiteLatencyState build() {
    final given = (Platform.environment['SITES'] ?? '53,61,180,244,320,51').split(',');
    return (
      ms: {for (final (i, site) in latencySites.indexed) site.key: i < given.length ? int.tryParse(given[i]) : null},
      at: DateTime(2026),
      testing: false,
      done: latencySites.length,
    );
  }

  @override
  Future<void> test() async {}
}
