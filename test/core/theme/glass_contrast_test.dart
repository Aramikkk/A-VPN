import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Every Glass scheme, by day and by night, keeps its text readable on its panes: the main text at least 4.5:1,
/// the quieter one and the accent (the figures, the chosen tab) at least 3:1; the text on the chosen server's row and
/// on a toggle that's on (both tinted with the accent) at least 4.5:1.
void main() {
  for (final scheme in GlassScheme.values) {
    for (final brightness in Brightness.values) {
      test('${scheme.name} ${brightness.name}', () {
        final look = scheme.look(brightness);
        final pane = look.panelOnBase;
        final theme = AppTheme(AppThemeMode.system, '', style: AraStyle.glass, glassScheme: scheme);
        final data = brightness == Brightness.dark ? theme.darkTheme(null) : theme.lightTheme(null);
        final c = data.colorScheme;
        expect(AraLook.contrast(c.onSurface, pane), greaterThanOrEqualTo(4.5), reason: 'text');
        expect(AraLook.contrast(c.onSurfaceVariant, pane), greaterThanOrEqualTo(3), reason: 'muted text');
        expect(AraLook.contrast(c.primary, pane), greaterThanOrEqualTo(3), reason: 'accent');
        // the chosen server's row and a toggle that's on are tinted with the accent; the text stays on them
        final row = Color.alphaBlend(look.tint(c.onSurface, look.dark ? .22 : .5), pane);
        final toggle = Color.alphaBlend(look.tint(c.onSurface, look.dark ? .3 : .75), pane);
        expect(AraLook.contrast(c.onSurface, row), greaterThanOrEqualTo(4.5), reason: 'chosen row');
        expect(AraLook.contrast(c.onSurface, toggle), greaterThanOrEqualTo(4.5), reason: 'toggle on');
      });
    }
  }
}
