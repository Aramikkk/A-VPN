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
  const AraLook({this.gradient, this.onGradient = Colors.white, required this.fastPing, this.border, this.data});

  /// the colour of measurements (the ping and its bars) when the accent colour would read as an alarm (a red
  /// accent); null: the accent colour
  final Color? data;

  /// The ping's colours from fast to slow (≤100, ≤150, ≤250, ≤500 ms), drawn from the theme's accent: in the red
  /// theme red, orange, amber, yellow. Slower than that is grey.
  List<Color> get pingColors => pingScale(fastPing);

  /// The colour for a ping of [ms] milliseconds; [muted] for slower than 500 ms.
  Color pingColor(int ms, Color muted) => switch (ms) {
    <= 100 => pingColors[0],
    <= 150 => pingColors[1],
    <= 250 => pingColors[2],
    <= 500 => pingColors[3],
    _ => muted,
  };

  /// Four steps from [base]: the hue turns a little warmer each step and the colour softens.
  static List<Color> pingScale(Color base) {
    final hsl = HSLColor.fromColor(base);
    return [
      for (var i = 0; i < 4; i++)
        hsl
            .withHue((hsl.hue + i * 18) % 360)
            .withSaturation((hsl.saturation * (1 - i * .08)).clamp(0.0, 1.0))
            .toColor(),
    ];
  }

  final Gradient? gradient;

  /// an outline for the gradient blocks, when they're the same colour as the background (the OLED theme)
  final Color? border;
  final Color onGradient;
  final Color fastPing;

  @override
  AraLook copyWith({Gradient? gradient, Color? onGradient, Color? fastPing, Color? border, Color? data}) => AraLook(
    gradient: gradient ?? this.gradient,
    onGradient: onGradient ?? this.onGradient,
    fastPing: fastPing ?? this.fastPing,
    border: border ?? this.border,
    data: data ?? this.data,
  );

  @override
  AraLook lerp(covariant ThemeExtension<AraLook>? other, double t) {
    if (other is! AraLook) return this;
    return AraLook(
      gradient: Gradient.lerp(gradient, other.gradient, t),
      onGradient: Color.lerp(onGradient, other.onGradient, t)!,
      fastPing: Color.lerp(fastPing, other.fastPing, t)!,
      border: Color.lerp(border, other.border, t),
      data: Color.lerp(data, other.data, t),
    );
  }
}

extension AraLookOf on ThemeData {
  AraLook get araLook => extension<AraLook>() ?? AraLook(fastPing: colorScheme.primary);
}
