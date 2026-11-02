import 'package:flutter/material.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show dotsAccentNow;

/// The chain page in the program's dot style: the same colours and the mono type as the home screen.
abstract class ChainLook {
  static bool dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color ink(BuildContext context) => dark(context) ? const Color(0xFFECECE8) : const Color(0xFF151515);

  static Color soft(BuildContext context) => dark(context) ? const Color(0xFF9A9A95) : const Color(0xFF6A6A66);

  static Color line(BuildContext context) => dark(context) ? const Color(0xFF464644) : const Color(0xFFC8C8C2);

  static Color get accent => dotsAccentNow;

  static TextStyle mono(double size, Color colour, {FontWeight weight = FontWeight.w500, double spacing = .6}) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: 1.3,
        color: colour,
      );
}
