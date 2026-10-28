import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/widget/ui_scale.dart';

void main() {
  testWidgets('the app is laid out in a screen 1/scale as large, touches map back, text has its own factor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    Size? seen;
    double? text;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UiScale(
          scale: 2,
          fontScale: 1.5,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              text = MediaQuery.textScalerOf(context).scale(10);
              return GestureDetector(onTap: () => taps++, child: const ColoredBox(color: Colors.red, child: SizedBox.expand()));
            },
          ),
        ),
      ),
    );
    expect(seen, const Size(200, 400));
    expect(text, 15);
    // a touch at the corner of the real screen is at the corner of the scaled one
    await tester.tapAt(const Offset(395, 795));
    expect(taps, 1);
  });

  testWidgets('scale 1 and font 1 leave everything as it is', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    Size? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: UiScale(
          scale: 1,
          fontScale: 1,
          child: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(seen, tester.view.physicalSize / tester.view.devicePixelRatio);
  });
}
