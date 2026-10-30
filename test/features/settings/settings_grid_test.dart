import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/overview/settings_page.dart';

void main() {
  test('a phone keeps two columns at the usual size', () {
    for (final width in [360.0, 411.0, 500.0]) {
      final l = settingsGridLayout(width);
      expect(l.columns, 2, reason: '$width');
      expect(l.scale, lessThan(1.35), reason: '$width');
    }
    expect(settingsGridLayout(360).scale, lessThan(1.1));
  });

  test('a wider screen takes more columns and bigger tiles', () {
    final tablet = settingsGridLayout(760);
    final wide = settingsGridLayout(1280);
    final huge = settingsGridLayout(1900);
    expect(tablet.columns, 3);
    expect(wide.columns, 4);
    expect(huge.columns, 6);
    expect(wide.scale, greaterThan(tablet.scale));
    expect(wide.scale, greaterThan(1.4));
    expect(huge.scale, greaterThan(1.4));
  });

  test('the size has a ceiling, and the twelve sections never leave a lone tile', () {
    for (final width in [320.0, 600.0, 900.0, 1300.0, 2400.0, 4000.0]) {
      final l = settingsGridLayout(width);
      expect(l.scale, inInclusiveRange(1, 2.2));
      if (l.columns > 2) expect(12 % l.columns, 0, reason: '$width');
    }
  });
}
