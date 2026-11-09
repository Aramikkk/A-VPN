import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show dotsAccentNow, homeLookNow;

/// How a thin strip over the screen (the update offer, a notification) looks in the theme in use: Dots (an inked frame),
/// Bento (a solid tile), Glass (a frosted pane) or Contrast (a see-through white or dark block). The colours and the corners
/// of each, in one place, so every strip of the app agrees with the home screen's blocks.
class StripLook {
  const StripLook._({
    required this.fill,
    required this.edge,
    required this.edgeWidth,
    required this.ink,
    required this.btnFill,
    required this.btnInk,
    required this.accent,
    required this.radius,
    required this.dots,
    required this.bento,
    required this.glass,
  });

  /// the strip's background and its edge (transparent: none)
  final Color fill;
  final Color edge;
  final double edgeWidth;

  /// the text on it, and the main button's fill and text
  final Color ink;
  final Color btnFill;
  final Color btnInk;

  /// the theme's accent
  final Color accent;
  final double radius;
  final bool dots;
  final bool bento;
  final bool glass;

  Color get soft => ink.withValues(alpha: .68);

  /// The text style of the strip: Dots has its own monospace capitals.
  TextStyle text(double size, Color colour, {FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: dots ? 'JetBrains Mono' : null,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: dots ? .8 : 0,
    color: colour,
    height: 1.25,
  );

  BoxDecoration get decoration => BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: edge == Colors.transparent ? null : Border.all(color: edge, width: edgeWidth),
  );

  static StripLook of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final glass = theme.glassLook;
    final look = homeLookNow;
    final dots = glass == null && look == HomeLayout.dots;
    final bento = glass == null && look == HomeLayout.bento;
    final accent = dots ? dotsAccentNow : theme.araAccent;
    if (glass != null) {
      return StripLook._(
        fill: glass.panel,
        edge: glass.edge,
        edgeWidth: 1,
        ink: scheme.onSurface,
        btnFill: scheme.onSurface,
        btnInk: scheme.surface,
        accent: accent,
        radius: 22,
        dots: false,
        bento: false,
        glass: true,
      );
    }
    if (dots) {
      final ink = dark ? const Color(0xFFECECE8) : const Color(0xFF151515);
      return StripLook._(
        // the paper under it, or a toast would let the screen show through
        fill: dark ? const Color(0xFF111111) : const Color(0xFFF2F2EE),
        edge: dark ? const Color(0xFF555555) : const Color(0xFF9A9A95),
        edgeWidth: 1.2,
        ink: ink,
        btnFill: ink,
        btnInk: dark ? const Color(0xFF111111) : const Color(0xFFF2F2EE),
        accent: accent,
        radius: 8,
        dots: true,
        bento: false,
        glass: false,
      );
    }
    if (bento) {
      return StripLook._(
        fill: dark ? const Color(0xFF3A3A40) : const Color(0xFFF0F0F2),
        edge: Colors.transparent,
        edgeWidth: 1,
        ink: scheme.onSurface,
        btnFill: accent,
        btnInk: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : const Color(0xFF111111),
        accent: accent,
        radius: 22,
        dots: false,
        bento: true,
        glass: false,
      );
    }
    return StripLook._(
      fill: dark ? scheme.surfaceContainerHigh.withValues(alpha: .72) : Colors.white.withValues(alpha: .72),
      edge: dark ? Colors.white.withValues(alpha: .1) : scheme.outlineVariant.withValues(alpha: .25),
      edgeWidth: 1,
      ink: scheme.onSurface,
      btnFill: dark ? const Color(0xFFF3F1EC) : const Color(0xFF111111),
      btnInk: dark ? const Color(0xFF111111) : Colors.white,
      accent: accent,
      radius: 22,
      dots: false,
      bento: false,
      glass: false,
    );
  }
}
