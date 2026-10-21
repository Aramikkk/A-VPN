import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Every Glass scheme, by day and by night, keeps its text readable on its blocks (the layout is Contrast's; Glass
/// gives it the page and the block colours): the main text at least 4.5:1, the quieter one and the accent (the
/// figures, the chosen tab) at least 3:1.
void main() {
  for (final scheme in GlassScheme.values) {
    for (final brightness in Brightness.values) {
      test('${scheme.name} ${brightness.name}', () {
        final dark = brightness == Brightness.dark;
        final colours = GlassColours(scheme);
        final pane = colours.pane(dark);
        final theme = AppTheme(AppThemeMode.system, '', style: AraStyle.glass, glassScheme: scheme);
        final data = dark ? theme.darkTheme(null) : theme.lightTheme(null);
        final c = data.colorScheme;
        expect(AraLook.contrast(c.onSurface, pane), greaterThanOrEqualTo(4.5), reason: 'text');
        expect(AraLook.contrast(c.onSurfaceVariant, pane), greaterThanOrEqualTo(3), reason: 'muted text');
        expect(AraLook.contrast(c.primary, pane), greaterThanOrEqualTo(3), reason: 'accent');
      });
    }
  }
}
