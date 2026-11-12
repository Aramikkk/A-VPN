import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/feature_dialog.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  Future<void> open(WidgetTester tester, {required bool on, required void Function(bool) choose}) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showFeatureDialog(
              context,
              title: 'Меньше прыжков',
              body: 'Сервер остаётся, пока стабилен.',
              stateText: on ? 'Сейчас: включено' : 'Сейчас: выключено',
              on: on,
              onLabel: 'Включить',
              offLabel: 'Выключить',
              closeLabel: 'Закрыть',
              onChoose: choose,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('it shows the name, the explanation, the state in force and the two choices', (tester) async {
    await open(tester, on: false, choose: (_) {});
    expect(find.text('Меньше прыжков'), findsOneWidget);
    expect(find.text('Сервер остаётся, пока стабилен.'), findsOneWidget);
    expect(find.text('Сейчас: выключено'), findsOneWidget);
    expect(find.text('Включить'), findsOneWidget);
    expect(find.text('Выключить'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
  });

  testWidgets('turning on passes true and the window closes', (tester) async {
    bool? chosen;
    await open(tester, on: false, choose: (v) => chosen = v);
    await tester.tap(find.text('Включить'));
    await tester.pumpAndSettle();
    expect(chosen, isTrue);
    expect(find.text('Сервер остаётся, пока стабилен.'), findsNothing);
  });

  testWidgets('turning off passes false', (tester) async {
    bool? chosen;
    await open(tester, on: true, choose: (v) => chosen = v);
    await tester.tap(find.text('Выключить'));
    await tester.pumpAndSettle();
    expect(chosen, isFalse);
  });

  testWidgets('the state in force is the selected segment, and a tap on it changes nothing', (tester) async {
    bool? chosen;
    await open(tester, on: true, choose: (v) => chosen = v);
    final control = tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
    expect(control.selected, {true});
    await tester.tap(find.text('Включить'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
  });

  testWidgets('close leaves it as it was', (tester) async {
    bool? chosen;
    await open(tester, on: false, choose: (v) => chosen = v);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    expect(find.text('Сервер остаётся, пока стабилен.'), findsNothing);
  });
}
