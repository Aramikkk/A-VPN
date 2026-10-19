import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/contrast_look.dart';

void main() {
  test('a fresh install uses the current light Citrus Contrast look', () {
    expect(AppThemeMode.fallback, AppThemeMode.light);
    expect(AraStyle.fallback, AraStyle.contrast);
    expect(ContrastPalette.fallback, ContrastPalette.citrus);
    expect(
      ContrastPalette.values,
      containsAll([
        ContrastPalette.rosewood,
        ContrastPalette.glacier,
        ContrastPalette.sage,
        ContrastPalette.sakura,
        ContrastPalette.twilight,
        ContrastPalette.copper,
      ]),
    );
    expect(ContrastClarity.fallback, ContrastClarity.strong);
    expect(ContrastBackdrop.fallback, ContrastBackdrop.pinstripes);
  });
}
