import 'package:flutter/material.dart';

class ConnectionButtonTheme extends ThemeExtension<ConnectionButtonTheme> {
  const ConnectionButtonTheme({this.idleColor, this.connectedColor});

  final Color? idleColor;
  final Color? connectedColor;

  static const ConnectionButtonTheme light = ConnectionButtonTheme(
    idleColor: Color(0xFF4a4d8b),
    connectedColor: Color(0xFF44a334),
  );

  @override
  ThemeExtension<ConnectionButtonTheme> copyWith({Color? idleColor, Color? connectedColor}) => ConnectionButtonTheme(
    idleColor: idleColor ?? this.idleColor,
    connectedColor: connectedColor ?? this.connectedColor,
  );

  @override
  ThemeExtension<ConnectionButtonTheme> lerp(covariant ThemeExtension<ConnectionButtonTheme>? other, double t) {
    if (other is! ConnectionButtonTheme) {
      return this;
    }
    return ConnectionButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t),
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t),
    );
  }
}

/// A-VPN's accent gradient, the colour of text on it, and the colour for a fast ping.
class AraLook extends ThemeExtension<AraLook> {
  const AraLook({this.gradient, this.onGradient = Colors.white, required this.fastPing});

  final Gradient? gradient;
  final Color onGradient;
  final Color fastPing;

  @override
  AraLook copyWith({Gradient? gradient, Color? onGradient, Color? fastPing}) => AraLook(
    gradient: gradient ?? this.gradient,
    onGradient: onGradient ?? this.onGradient,
    fastPing: fastPing ?? this.fastPing,
  );

  @override
  AraLook lerp(covariant ThemeExtension<AraLook>? other, double t) {
    if (other is! AraLook) return this;
    return AraLook(
      gradient: Gradient.lerp(gradient, other.gradient, t),
      onGradient: Color.lerp(onGradient, other.onGradient, t)!,
      fastPing: Color.lerp(fastPing, other.fastPing, t)!,
    );
  }
}

extension AraLookOf on ThemeData {
  AraLook get araLook => extension<AraLook>() ?? AraLook(fastPing: colorScheme.primary);
}
