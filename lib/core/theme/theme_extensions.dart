import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';

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
    this.graphDown,
    this.graphUp,
    this.style = AraStyle.classic,
    this.iconGradient,
    this.pingOn,
    this.neonFill,
    this.glass,
  });

  /// the Glass scheme the theme was built for: panels see-through, the menu and the connect panel floating;
  /// null: not Glass
  final GlassScheme? glass;

  /// the neon the chosen server and the connect button are filled with (black text on it); null: not filled
  final Color? neonFill;

  /// a neon gradient the icons are painted in (Cyberpunk); null: plain icons
  final Gradient? iconGradient;

  /// the cards the ping colours have to read on; null: white (or near-black) cards
  final Color? pingOn;

  /// the look the theme was built for: the home screen and a few blocks draw themselves to match it
  final AraStyle style;

  /// the speed graph's download and upload colours on the speed block; null: the text colour on it
  final Color? graphDown;
  final Color? graphUp;

  /// a dark theme: the ping scale is kept readable on dark cards instead of light ones
  final bool dark;

  /// the colour of measurements (the ping and its bars) when the accent colour would read as an alarm (a red
  /// accent); null: the accent colour
  final Color? data;

  /// The ping's colours from fast to slow (≤100, ≤150, ≤250, ≤500 ms), drawn from the theme's accent: in the red
  /// theme red, orange, amber, yellow. Slower than that is grey.
  List<Color> get pingColors => pingScale(fastPing, dark: dark, card: pingOn);

  /// The colour for a ping of [ms] milliseconds; [muted] for slower than 500 ms.
  Color pingColor(int ms, Color muted) => switch (ms) {
    <= 100 => pingColors[0],
    <= 150 => pingColors[1],
    <= 250 => pingColors[2],
    <= 500 => pingColors[3],
    _ => muted,
  };

  /// Four steps from [base]: the hue turns a little warmer each step and the colour softens; a colourless accent
  /// (Monochrome, OLED) fades from black (or white) towards grey instead. Every step is darkened (light theme) or lightened
  /// (dark theme) as far as needed to stay readable on the cards: contrast at least 3:1.
  static List<Color> pingScale(Color base, {bool dark = false, Color? card}) {
    final hsl = HSLColor.fromColor(base);
    final colourless = hsl.saturation < .12;
    final on = card ?? (dark ? const Color(0xFF17171A) : const Color(0xFFFBFBFB));
    return [
      for (var i = 0; i < 4; i++)
        _readable(
          colourless
              // black (or white) fading to grey: the theme's own colour, not a traffic light
              ? hsl.withLightness((dark ? hsl.lightness - i * .15 : hsl.lightness + i * .15).clamp(0.0, 1.0))
              : hsl.withHue((hsl.hue + i * 18) % 360).withSaturation((hsl.saturation * (1 - i * .08)).clamp(0.0, 1.0)),
          on,
          dark: dark,
        ),
    ];
  }

  /// [colour] lightened (on a dark [background]) or darkened (on a light one) until it reads on it: contrast at
  /// least 3:1.
  static Color readableOn(Color colour, Color background) {
    final bg = _solid(background);
    return _readable(HSLColor.fromColor(colour), bg, dark: bg.computeLuminance() < .4);
  }

  /// A see-through colour (Glass's panels) as it reads: a faint white wash lies on a dark backdrop, a milky one
  /// on a light backdrop.
  static Color _solid(Color c) =>
      c.a >= 1 ? c : Color.alphaBlend(c, c.a < .25 ? const Color(0xFF0E0E12) : const Color(0xFFEDEDF0));

  static Color _readable(HSLColor colour, Color background, {required bool dark}) {
    final card = _solid(background);
    var c = colour;
    for (var i = 0; i < 40 && _contrast(c.toColor(), card) < 3.0; i++) {
      c = c.withLightness((c.lightness + (dark ? .02 : -.02)).clamp(0.0, 1.0));
    }
    return c.toColor();
  }

  /// The WCAG contrast ratio of two colours (1 to 21).
  static double contrast(Color a, Color b) => _contrast(a, b);

  static double _contrast(Color a, Color b) {
    final la = _solid(a).computeLuminance();
    final lb = _solid(b).computeLuminance();
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
    graphDown: graphDown,
    graphUp: graphUp,
    style: style,
    iconGradient: iconGradient,
    pingOn: pingOn,
    neonFill: neonFill,
    glass: glass,
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
      graphDown: Color.lerp(graphDown, other.graphDown, t),
      graphUp: Color.lerp(graphUp, other.graphUp, t),
      style: t < .5 ? style : other.style,
      iconGradient: Gradient.lerp(iconGradient, other.iconGradient, t),
      pingOn: Color.lerp(pingOn, other.pingOn, t),
      neonFill: Color.lerp(neonFill, other.neonFill, t),
      glass: t < .5 ? glass : other.glass,
    );
  }
}

extension AraLookOf on ThemeData {
  AraLook get araLook =>
      extension<AraLook>() ?? AraLook(fastPing: colorScheme.primary, dark: brightness == Brightness.dark);
}

/// Paints [child] (an icon) in the theme's neon icon gradient when it has one.
class AraIconPaint extends StatelessWidget {
  const AraIconPaint({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// false: leave the icon as it is (an unselected tab, a muted state)
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final gradient = Theme.of(context).araLook.iconGradient;
    if (gradient == null || !enabled) return child;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: child,
    );
  }
}
