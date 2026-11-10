import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() => homeLookNow = HomeLayout.classic);

  testWidgets('Dots: an app without a picture gets a dotted square with its letter, not a filled tint', (tester) async {
    homeLookNow = HomeLayout.dots;
    await tester.pumpWidget(_app(const ConnectionAppIcon(icon: null, name: 'Система')));
    expect(find.byKey(const Key('dots-fallback-icon')), findsOneWidget);
    expect(find.text('С'), findsOneWidget);
  });

  testWidgets('the other looks keep their tinted tile', (tester) async {
    homeLookNow = HomeLayout.classic;
    await tester.pumpWidget(_app(const ConnectionAppIcon(icon: null, name: 'Система')));
    expect(find.byKey(const Key('dots-fallback-icon')), findsNothing);
    expect(find.text('С'), findsOneWidget);
  });
}
