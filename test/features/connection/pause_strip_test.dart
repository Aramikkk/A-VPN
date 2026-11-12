import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';
import 'package:hiddify/features/connection/widget/pause_strip.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Pause extends VpnPauseNotifier {
  _Pause(this._raw);

  final String _raw;

  @override
  VpnPause build() => parseVpnPause(_raw);
}

void main() {
  Future<void> show(WidgetTester tester, String raw) async {
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          translationsProvider.overrideWith((ref) async => t),
          vpnPauseProvider.overrideWith(() => _Pause(raw)),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: PauseStrip()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('not paused: no strip, no room taken', (tester) async {
    await show(tester, '');
    expect(find.byKey(const Key('pause-strip')), findsNothing);
    expect(tester.getSize(find.byType(PauseStrip)).height, 0);
  });

  testWidgets('a home Wi-Fi: the strip says the home mode is on and the VPN is paused', (tester) async {
    await show(tester, 'home');
    expect(find.byKey(const Key('pause-strip')), findsOneWidget);
    expect(find.textContaining('Домашний'), findsOneWidget);
    expect(find.textContaining('пауз'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an app on screen: the strip names it', (tester) async {
    await show(tester, 'app:Госуслуги');
    expect(find.textContaining('Госуслуги'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
