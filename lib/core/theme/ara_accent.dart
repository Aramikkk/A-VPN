import 'package:flutter/material.dart';

/// The app's accent: its colour and the gradient on the speed block, the provider badge and the
/// connection card. Picked in Settings → General.
enum AraAccent {
  /// A-VPN's own look: black, graphite, grey and white with a red accent, after the Mono emblem.
  /// Graphite blocks with white text by day and by night.
  monoRed(
    seed: Color(0xFFEE4245),
    lightPrimary: Color(0xFFE0353A),
    darkPrimary: Color(0xFFFF5A5D),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'red',
  ),

  /// Mono in blue.
  monoBlue(
    seed: Color(0xFF2F7BFF),
    lightPrimary: Color(0xFF1F66E5),
    darkPrimary: Color(0xFF5C9BFF),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'blue',
  ),

  /// Mono in emerald.
  monoEmerald(
    seed: Color(0xFF16C47F),
    lightPrimary: Color(0xFF0E9F66),
    darkPrimary: Color(0xFF3DDC97),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'emerald',
  ),

  /// Mono in orange.
  monoOrange(
    seed: Color(0xFFFF7A1A),
    lightPrimary: Color(0xFFE5650A),
    darkPrimary: Color(0xFFFF9547),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'orange',
  ),

  /// Mono in violet.
  monoViolet(
    seed: Color(0xFF8B5CF6),
    lightPrimary: Color(0xFF7341E6),
    darkPrimary: Color(0xFFA78BFA),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'violet',
  ),

  /// Mono in teal.
  monoTeal(
    seed: Color(0xFF14C8D4),
    lightPrimary: Color(0xFF0E9FAA),
    darkPrimary: Color(0xFF3FDDE8),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'teal',
  ),

  /// Mono in gold.
  monoGold(
    seed: Color(0xFFE8B500),
    lightPrimary: Color(0xFFB38A00),
    darkPrimary: Color(0xFFF5C518),
    lightGradient: _graphiteLight,
    darkGradient: _graphiteDark,
    icon: 'gold',
  ),

  /// A-VPN's earlier acid green; dark text on it.
  acid(
    seed: Color(0xFF9EFF1F),
    lightPrimary: Color(0xFF3B8A00),
    darkPrimary: Color(0xFF9EFF1F),
    lightGradient: [Color(0xFF2E7D00), Color(0xFF5DBB0A), Color(0xFF9EE832)],
    darkGradient: [Color(0xFF6FD400), Color(0xFF9EFF1F), Color(0xFFD2FF70)],
    darkOnGradient: Color(0xFF0B1400),
  ),

  /// Windows 11 blue (the desktop's default).
  windows(
    seed: Color(0xFF0078D4),
    lightPrimary: Color(0xFF005FB8),
    darkPrimary: Color(0xFF60CDFF),
    lightGradient: [Color(0xFF0050A8), Color(0xFF0A7BD8), Color(0xFF46B0F2)],
    darkGradient: [Color(0xFF0B3F8C), Color(0xFF1269C7), Color(0xFF3FA9F5)],
  ),

  /// Violet into magenta.
  aurora(
    seed: Color(0xFF8B3FE8),
    lightPrimary: Color(0xFF7A2FD6),
    darkPrimary: Color(0xFFD3A6FF),
    lightGradient: [Color(0xFF5B21D6), Color(0xFF9B30E0), Color(0xFFE548B8)],
    darkGradient: [Color(0xFF4A1DB8), Color(0xFF8E2BD6), Color(0xFFD9409F)],
  ),

  /// Coral into amber.
  sunset(
    seed: Color(0xFFFF5A36),
    lightPrimary: Color(0xFFC8381B),
    darkPrimary: Color(0xFFFFA27A),
    lightGradient: [Color(0xFFE8265E), Color(0xFFFF5A36), Color(0xFFFFA62B)],
    darkGradient: [Color(0xFFC21E52), Color(0xFFE84A2C), Color(0xFFF59321)],
  ),

  /// Teal into mint.
  lagoon(
    seed: Color(0xFF00A99D),
    lightPrimary: Color(0xFF00796F),
    darkPrimary: Color(0xFF5FE3C8),
    lightGradient: [Color(0xFF006D8F), Color(0xFF00A99D), Color(0xFF4FD98B)],
    darkGradient: [Color(0xFF005A78), Color(0xFF00917F), Color(0xFF3CC47A)],
  ),

  /// Electric blue through violet into hot pink.
  neon(
    seed: Color(0xFF6A3CFF),
    lightPrimary: Color(0xFF4F33E0),
    darkPrimary: Color(0xFFA9A0FF),
    lightGradient: [Color(0xFF1F5BFF), Color(0xFF7A3CFF), Color(0xFFFF3CA6)],
    darkGradient: [Color(0xFF1A4ADB), Color(0xFF6A2FE6), Color(0xFFE6338F)],
  ),

  /// Black and white, the most contrast: graphite into black on light, white into silver on dark.
  mono(
    seed: Color(0xFF5F6368),
    lightPrimary: Color(0xFF111111),
    darkPrimary: Color(0xFFFFFFFF),
    lightGradient: [Color(0xFF000000), Color(0xFF2B2B2B), Color(0xFF5A5A5A)],
    darkGradient: [Color(0xFFFFFFFF), Color(0xFFD9D9D9), Color(0xFFA8A8A8)],
    darkOnGradient: Color(0xFF000000),
  ),

  /// Soft lavender, peach and mint: low contrast, easy on the eyes; dark text on it.
  pastel(
    seed: Color(0xFFB39DDB),
    lightPrimary: Color(0xFF7E57C2),
    darkPrimary: Color(0xFFD1C4E9),
    lightGradient: [Color(0xFFD7C8F5), Color(0xFFF6D3E1), Color(0xFFFFE3C8)],
    darkGradient: [Color(0xFFB9A6E8), Color(0xFFE6B7CC), Color(0xFFF3CBA8)],
    lightOnGradient: Color(0xFF2B1F45),
    darkOnGradient: Color(0xFF2B1F45),
  ),

  /// Signal yellow into orange: loud and high contrast, black text on it.
  cyber(
    seed: Color(0xFFFFD600),
    lightPrimary: Color(0xFF8A6D00),
    darkPrimary: Color(0xFFFFE135),
    lightGradient: [Color(0xFFFFE135), Color(0xFFFFB300), Color(0xFFFF6D00)],
    darkGradient: [Color(0xFFFFF04D), Color(0xFFFFC400), Color(0xFFFF8F00)],
    lightOnGradient: Color(0xFF1A1400),
    darkOnGradient: Color(0xFF1A1400),
  ),

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

// the Mono themes' graphite blocks, white text on them by day and by night
const _graphiteLight = [Color(0xFF0E0E0E), Color(0xFF2B2B2B), Color(0xFF474747)];
const _graphiteDark = [Color(0xFF2B2B2B), Color(0xFF1C1C1C), Color(0xFF0E0E0E)];
