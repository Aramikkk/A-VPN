import 'dart:io';

import 'package:flutter/material.dart';

/// The app's accent: its colour and the gradient on the speed block, the provider badge and the
/// connection card. Picked in Settings → General.
enum AraAccent {
  /// A-VPN's own acid green (the phone's default); dark text on it.
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
  );

  const AraAccent({
    required this.seed,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.lightGradient,
    required this.darkGradient,
    this.darkOnGradient = Colors.white,
  });

  final Color seed;
  final Color lightPrimary;
  final Color darkPrimary;
  final List<Color> lightGradient;
  final List<Color> darkGradient;
  final Color darkOnGradient;

  static AraAccent get platformDefault => Platform.isAndroid || Platform.isIOS ? acid : windows;

  /// Text and icons on the gradient.
  Color onGradient(Brightness brightness) => brightness == Brightness.dark ? darkOnGradient : Colors.white;

  LinearGradient gradient(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark ? darkGradient : lightGradient,
  );
}
