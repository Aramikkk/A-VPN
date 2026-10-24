import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/traffic_sankey.dart';

SankeyFlow flow(String app, String site, String out, double kb, {double kbps = 0, String id = ''}) => SankeyFlow(
  app: app,
  rule: 'r',
  out: out,
  route: ConnectionRoute.vpn,
  weight: kb * 1024,
  host: site,
  site: site,
  speed: kbps * 1024,
  id: id.isEmpty ? '$app$site' : id,
);

Widget app(List<SankeyFlow> flows, {Future<void> Function(SankeySelection)? onSelect, double height = 520}) {
  final theme = AppTheme(AppThemeMode.system, '', accent: AraAccent.neonRed, style: AraStyle.contrast);
  return MaterialApp(
    theme: theme.lightTheme(null),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SankeyDiagram(
          flows: flows,
          value: (w) => '${(w / 1024).round()} KB',
          speedValue: (w) => '${(w / 1024).round()} KB/s',
          even: true,
          calm: true,
          chips: true,
          headers: const ['Apps', 'Sites', 'To'],
          height: height,
          otherApp: 'Other',
          otherRule: 'Other',
          otherOut: 'Other',
          onSelect: onSelect,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every route is on the plates: app, site, server, with traffic and speed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 800));
    await tester.pumpWidget(app([flow('Claude', 'claude.ai', '🇩🇪 Германия', 294), flow('ChatGPT', 'chatgpt.com', '🇱🇻 Латвия', 298, kbps: 24)]));
    for (final text in ['Claude', 'claude.ai', 'Германия', 'ChatGPT', 'chatgpt.com', 'Латвия']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // the speed is written only where something moves
    expect(find.text('294 KB'), findsWidgets);
    expect(find.text('298 KB · 24 KB/s'), findsWidgets);
    expect(find.text('APPS'), findsOneWidget);
  });

  testWidgets('a tap on a plate picks the route out and reports it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 800));
    SankeySelection? got;
    await tester.pumpWidget(
      app([flow('Claude', 'claude.ai', 'DE', 294), flow('ChatGPT', 'chatgpt.com', 'LV', 298)], onSelect: (s) async => got = s),
    );
    await tester.tap(find.text('claude.ai'));
    await tester.pump();
    expect(got?.title, 'claude.ai');
    expect(got?.flows.length, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('plates keep their rows when a route comes: the old ones do not move', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 800));
    final first = [flow('Zed', 'z.com', 'DE', 100)];
    await tester.pumpWidget(app(first));
    final before = tester.getTopLeft(find.text('Zed'));
    await tester.pumpWidget(app([...first, flow('Alpha', 'a.com', 'DE', 100)]));
    expect(tester.getTopLeft(find.text('Zed')), before);
  });

  testWidgets('more routes than rows: the rest is added up as other, nothing overflows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 800));
    await tester.pumpWidget(app([for (var i = 0; i < 30; i++) flow('App$i', 'site$i.com', 'Server${i % 5}', 100.0 + i)], height: 420));
    expect(tester.takeException(), isNull);
    expect(find.text('Other'), findsWidgets);
  });
}
