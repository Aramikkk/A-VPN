import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/notification/themed_toast.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget toast, {bool dark = true, double width = 320}) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(alignment: Alignment.bottomCenter, child: toast),
          ),
        ),
      ),
    );
  }

  testWidgets('a notification shows its text, and a tap closes it', (tester) async {
    var closed = 0;
    await show(
      tester,
      ThemedToast(message: 'Лучший сервер: Германия · 56 мс', kind: ToastKind.success, onClose: () => closed++),
    );
    expect(find.text('Лучший сервер: Германия · 56 мс'), findsOneWidget);
    await tester.tap(find.byType(ThemedToast));
    expect(closed, 1);
  });

  testWidgets('the button closes the notification and does its thing', (tester) async {
    var closed = 0;
    var done = 0;
    await show(
      tester,
      ThemedToast(
        message: 'Удалено',
        kind: ToastKind.info,
        onClose: () => closed++,
        actionLabel: 'Вернуть',
        onAction: () => done++,
      ),
    );
    await tester.tap(find.text('Вернуть'));
    expect(done, 1);
    expect(closed, 1);
  });

  testWidgets('a long text on a narrow phone overflows nowhere, by day and by night', (tester) async {
    final long = List.filled(14, 'очень длинное уведомление').join(' ');
    for (final dark in [true, false]) {
      for (final kind in ToastKind.values) {
        await show(
          tester,
          ThemedToast(message: long, kind: kind, onClose: () {}, actionLabel: 'Вернуть', onAction: () {}),
          dark: dark,
          width: 320,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
