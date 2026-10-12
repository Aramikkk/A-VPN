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
  const AraLook({
    this.gradient,
    this.onGradient = Colors.white,
    required this.fastPing,
    this.border,
    this.data,
    this.dark = false,
  });

  /// a dark theme: the ping scale is kept readable on dark cards instead of light ones
  final bool dark;

  /// the colour of measurements (the ping and its bars) when the accent colour would read as an alarm (a red
  /// accent); null: the accent colour
  final Color? data;

  /// The ping's colours from fast to slow (≤100, ≤150, ≤250, ≤500 ms), drawn from the theme's accent: in the red
  /// theme red, orange, amber, yellow. Slower than that is grey.
  List<Color> get pingColors => pingScale(fastPing, dark: dark);

  /// The colour for a ping of [ms] milliseconds; [muted] for slower than 500 ms.
  Color pingColor(int ms, Color muted) => switch (ms) {
    <= 100 => pingColors[0],
    <= 150 => pingColors[1],
    <= 250 => pingColors[2],
    <= 500 => pingColors[3],
    _ => muted,
  };

  /// Four steps from [base]: the hue turns a little warmer each step and the colour softens; a colourless accent
  /// (Mono, OLED) steps in lightness instead, towards grey. Every step is darkened (light theme) or lightened
  /// (dark theme) as far as needed to stay readable on the cards: contrast at least 3:1.
  static List<Color> pingScale(Color base, {bool dark = false}) {
    final hsl = HSLColor.fromColor(base);
    final colourless = hsl.saturation < .12;
    final card = dark ? const Color(0xFF17171A) : const Color(0xFFFBFBFB);
    return [
      for (var i = 0; i < 4; i++)
        _readable(
          colourless
              ? hsl.withLightness((dark ? hsl.lightness - i * .14 : hsl.lightness + i * .14).clamp(0.0, 1.0))
              : hsl.withHue((hsl.hue + i * 18) % 360).withSaturation((hsl.saturation * (1 - i * .08)).clamp(0.0, 1.0)),
          card,
          dark: dark,
        ),
    ];
  }

  static Color _readable(HSLColor colour, Color card, {required bool dark}) {
    var c = colour;
    for (var i = 0; i < 40 && _contrast(c.toColor(), card) < 3.0; i++) {
      c = c.withLightness((c.lightness + (dark ? .02 : -.02)).clamp(0.0, 1.0));
    }
    return c.toColor();
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return ((la > lb ? la : lb) + .05) / ((la > lb ? lb : la) + .05);
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
    dark: dark,
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
      dark: t < .5 ? dark : other.dark,
    );
  }
}

extension AraLookOf on ThemeData {
  AraLook get araLook =>
      extension<AraLook>() ?? AraLook(fastPing: colorScheme.primary, dark: brightness == Brightness.dark);
}
