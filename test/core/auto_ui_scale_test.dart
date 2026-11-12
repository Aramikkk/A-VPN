import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/widget/ui_scale.dart';

void main() {
  test('a phone, folded or unfolded, and any portrait screen keep the size', () {
    expect(autoUiScale(const Size(411, 900)), 1);
    expect(autoUiScale(const Size(750, 832)), 1);
    expect(autoUiScale(const Size(900, 411)), 1);
    expect(autoUiScale(const Size(1200, 1600)), 1);
  });

  test('a big landscape screen is made larger, the wider the larger, up to a ceiling', () {
    final a = autoUiScale(const Size(1000, 600));
    final b = autoUiScale(const Size(1280, 800));
    final c = autoUiScale(const Size(1920, 1200));
    final d = autoUiScale(const Size(4000, 2000));
    expect(a, 1.0); // too low to be made larger: the page would lose its blocks
    expect(b, closeTo(1.33, .01));
    expect(b, greaterThan(a));
    expect(1280 / b, greaterThan(0));
    expect(800 / b, greaterThanOrEqualTo(600));
    expect(c, 1.8);
    expect(d, 1.8);
  });
}
