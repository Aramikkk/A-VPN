import 'package:flutter/material.dart';

/// The app's accent: its colour and the gradient on the speed block, the provider badge and the
/// connection card. Picked in Settings → General.
enum AraAccent {
  /// For OLED screens: pure black with white at night, pure white with black by day, no colour; the blocks get a
  /// thin outline instead of a coloured gradient.
  oled(
    seed: Color(0xFF808080),
    lightPrimary: Color(0xFF000000),
    darkPrimary: Color(0xFFFFFFFF),
    lightGradient: [Color(0xFFFFFFFF), Color(0xFFFAFAFA), Color(0xFFF0F0F0)],
    darkGradient: [Color(0xFF000000), Color(0xFF060606), Color(0xFF111111)],
    lightOnGradient: Color(0xFF000000),
    pure: true,
  ),

  /// True black (white by day) flooded with yellow: the chosen server, the connect ring and the speed block.
  neonYellow(
    seed: Color(0xFFFCEE0A),
    lightPrimary: Color(0xFFFCEE0A),
    darkPrimary: Color(0xFFFCEE0A),
    lightGradient: [Color(0xFFFCEE0A), Color(0xFFFCEE0A), Color(0xFFFCEE0A)],
    darkGradient: [Color(0xFFFCEE0A), Color(0xFFFCEE0A), Color(0xFFFCEE0A)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with red: the chosen server, the connect ring and the speed block.
  neonRed(
    seed: Color(0xFFFF1A4B),
    lightPrimary: Color(0xFFFF1A4B),
    darkPrimary: Color(0xFFFF1A4B),
    lightGradient: [Color(0xFFFF1A4B), Color(0xFFFF1A4B), Color(0xFFFF1A4B)],
    darkGradient: [Color(0xFFFF1A4B), Color(0xFFFF1A4B), Color(0xFFFF1A4B)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with blue: the chosen server, the connect ring and the speed block.
  neonBlue(
    seed: Color(0xFF00B4FF),
    lightPrimary: Color(0xFF00B4FF),
    darkPrimary: Color(0xFF00B4FF),
    lightGradient: [Color(0xFF00B4FF), Color(0xFF00B4FF), Color(0xFF00B4FF)],
    darkGradient: [Color(0xFF00B4FF), Color(0xFF00B4FF), Color(0xFF00B4FF)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with green: the chosen server, the connect ring and the speed block.
  neonGreen(
    seed: Color(0xFF39FF14),
    lightPrimary: Color(0xFF39FF14),
    darkPrimary: Color(0xFF39FF14),
    lightGradient: [Color(0xFF39FF14), Color(0xFF39FF14), Color(0xFF39FF14)],
    darkGradient: [Color(0xFF39FF14), Color(0xFF39FF14), Color(0xFF39FF14)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with orange: the chosen server, the connect ring and the speed block.
  neonOrange(
    seed: Color(0xFFFF7A1A),
    lightPrimary: Color(0xFFFF7A1A),
    darkPrimary: Color(0xFFFF7A1A),
    lightGradient: [Color(0xFFFF7A1A), Color(0xFFFF7A1A), Color(0xFFFF7A1A)],
    darkGradient: [Color(0xFFFF7A1A), Color(0xFFFF7A1A), Color(0xFFFF7A1A)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with amber: the chosen server, the connect ring and the speed block.
  neonAmber(
    seed: Color(0xFFFFB300),
    lightPrimary: Color(0xFFFFB300),
    darkPrimary: Color(0xFFFFB300),
    lightGradient: [Color(0xFFFFB300), Color(0xFFFFB300), Color(0xFFFFB300)],
    darkGradient: [Color(0xFFFFB300), Color(0xFFFFB300), Color(0xFFFFB300)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with coral: the chosen server, the connect ring and the speed block.
  neonCoral(
    seed: Color(0xFFFF6B57),
    lightPrimary: Color(0xFFFF6B57),
    darkPrimary: Color(0xFFFF6B57),
    lightGradient: [Color(0xFFFF6B57), Color(0xFFFF6B57), Color(0xFFFF6B57)],
    darkGradient: [Color(0xFFFF6B57), Color(0xFFFF6B57), Color(0xFFFF6B57)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with pink: the chosen server, the connect ring and the speed block.
  neonPink(
    seed: Color(0xFFFF3D8B),
    lightPrimary: Color(0xFFFF3D8B),
    darkPrimary: Color(0xFFFF3D8B),
    lightGradient: [Color(0xFFFF3D8B), Color(0xFFFF3D8B), Color(0xFFFF3D8B)],
    darkGradient: [Color(0xFFFF3D8B), Color(0xFFFF3D8B), Color(0xFFFF3D8B)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with fuchsia: the chosen server, the connect ring and the speed block.
  neonFuchsia(
    seed: Color(0xFFE040FB),
    lightPrimary: Color(0xFFE040FB),
    darkPrimary: Color(0xFFE040FB),
    lightGradient: [Color(0xFFE040FB), Color(0xFFE040FB), Color(0xFFE040FB)],
    darkGradient: [Color(0xFFE040FB), Color(0xFFE040FB), Color(0xFFE040FB)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with violet: the chosen server, the connect ring and the speed block.
  neonViolet(
    seed: Color(0xFF9D5CFF),
    lightPrimary: Color(0xFF9D5CFF),
    darkPrimary: Color(0xFF9D5CFF),
    lightGradient: [Color(0xFF9D5CFF), Color(0xFF9D5CFF), Color(0xFF9D5CFF)],
    darkGradient: [Color(0xFF9D5CFF), Color(0xFF9D5CFF), Color(0xFF9D5CFF)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with indigo: the chosen server, the connect ring and the speed block.
  neonIndigo(
    seed: Color(0xFF5468FF),
    lightPrimary: Color(0xFF5468FF),
    darkPrimary: Color(0xFF5468FF),
    lightGradient: [Color(0xFF5468FF), Color(0xFF5468FF), Color(0xFF5468FF)],
    darkGradient: [Color(0xFF5468FF), Color(0xFF5468FF), Color(0xFF5468FF)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with turquoise: the chosen server, the connect ring and the speed block.
  neonTurquoise(
    seed: Color(0xFF00D1C1),
    lightPrimary: Color(0xFF00D1C1),
    darkPrimary: Color(0xFF00D1C1),
    lightGradient: [Color(0xFF00D1C1), Color(0xFF00D1C1), Color(0xFF00D1C1)],
    darkGradient: [Color(0xFF00D1C1), Color(0xFF00D1C1), Color(0xFF00D1C1)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with mint: the chosen server, the connect ring and the speed block.
  neonMint(
    seed: Color(0xFF2EF2A0),
    lightPrimary: Color(0xFF2EF2A0),
    darkPrimary: Color(0xFF2EF2A0),
    lightGradient: [Color(0xFF2EF2A0), Color(0xFF2EF2A0), Color(0xFF2EF2A0)],
    darkGradient: [Color(0xFF2EF2A0), Color(0xFF2EF2A0), Color(0xFF2EF2A0)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  ),

  /// True black (white by day) flooded with lavender: the chosen server, the connect ring and the speed block.
  neonLavender(
    seed: Color(0xFFC6A8FF),
    lightPrimary: Color(0xFFC6A8FF),
    darkPrimary: Color(0xFFC6A8FF),
    lightGradient: [Color(0xFFC6A8FF), Color(0xFFC6A8FF), Color(0xFFC6A8FF)],
    darkGradient: [Color(0xFFC6A8FF), Color(0xFFC6A8FF), Color(0xFFC6A8FF)],
    lightOnGradient: Color(0xFF000000),
    darkOnGradient: Color(0xFF000000),
    pure: true,
    filled: true,
  );

  const AraAccent({
    required this.seed,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.lightGradient,
    required this.darkGradient,
    this.lightOnGradient = Colors.white,
    this.darkOnGradient = Colors.white,
    this.pure = false,
    this.filled = false,
    this.icon,
  });

  final Color seed;
  final Color lightPrimary;
  final Color darkPrimary;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
  final Color lightOnGradient;
  final Color darkOnGradient;

  /// pure black / pure white backgrounds and outlined blocks (the OLED theme)
  final bool pure;

  /// the neon floods the chosen server, the connect button and the speed block (with black text on it)
  final bool filled;

  /// the home-screen icon in this colour (Android): one of the launcher aliases; other themes keep the red one
  final String? icon;

  static AraAccent get platformDefault => oled;

  /// Text and icons on the gradient.
  Color onGradient(Brightness brightness) => brightness == Brightness.dark ? darkOnGradient : lightOnGradient;

  LinearGradient gradient(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark ? darkGradient : lightGradient,
  );
}
