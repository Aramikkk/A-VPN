import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _PaintCounter extends CustomPainter {
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}

void main() {
  testWidgets('static popup content is not repainted on every opening frame', (tester) async {
    final painter = _PaintCounter();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGlassPopup(
                context,
                CustomPaint(painter: painter, child: const SizedBox(width: 300, height: 400)),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      painter.paints,
      lessThanOrEqualTo(2),
      reason: 'static content should be retained while only the transition moves',
    );
    await tester.pumpAndSettle();
    // the popup goes with the tree; the page under it is let back a moment after
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
