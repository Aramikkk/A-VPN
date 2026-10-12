import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/utils/smooth_wheel.dart';

void main() {
  testWidgets('a wheel step comes out in pieces over the next frames and adds up to the whole step', (tester) async {
    final pieces = <double>[];
    final others = <PointerData>[];
    final wheel = SmoothWheel.forTest((packet) {
      for (final d in packet.data) {
        if (d.signalKind == PointerSignalKind.scroll) {
          pieces.add(d.scrollDeltaY);
        } else {
          others.add(d);
        }
      }
    });
    wheel.handle(
      const PointerDataPacket(
        data: [
          PointerData(kind: PointerDeviceKind.mouse, signalKind: PointerSignalKind.scroll, scrollDeltaY: 120),
          PointerData(kind: PointerDeviceKind.mouse, change: PointerChange.hover),
        ],
      ),
    );
    // anything that isn't the wheel goes straight through
    expect(others, hasLength(1));
    expect(pieces, isEmpty);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 4));
    }
    expect(pieces.length, greaterThan(5));
    expect(pieces.reduce((a, b) => a + b), closeTo(120, .001));
    // easing out: the first piece is the biggest
    expect(pieces.first, greaterThan(pieces.last));
  });
}
