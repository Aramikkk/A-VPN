import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/ara_style.dart';

/// Glass's own colour schemes (apart from the accents the other looks share): each one picks the kind of glass,
/// the backdrop under it (a base colour and three soft colour spots) and the accent.
enum GlassScheme {
  // Liquid: milky panels over bright spots
  lemonade(GlassVariant.liquid, Color(0xFFFFE600), Color(0xFFF4F1EA), [
    Color(0xFFFFE600),
    Color(0xFF6AA8FF),
    Color(0xFFFF8FB1),
  ]),
  lagoon(GlassVariant.liquid, Color(0xFF00B4D8), Color(0xFFEEF6F8), [
    Color(0xFF48E0F0),
    Color(0xFF7BE8C4),
    Color(0xFF6A8CFF),
  ]),
  sunset(GlassVariant.liquid, Color(0xFFFF6B3D), Color(0xFFF8F0EC), [
    Color(0xFFFF8A4C),
    Color(0xFFFF6FA8),
    Color(0xFFA77BFF),
  ]),
  sakura(GlassVariant.liquid, Color(0xFFFF5C93), Color(0xFFF9F0F3), [
    Color(0xFFFF9EC0),
    Color(0xFFFFC9A8),
    Color(0xFFC9A8FF),
  ]),
  mint(GlassVariant.liquid, Color(0xFF18C29C), Color(0xFFEFF7F3), [
    Color(0xFF6FF0C8),
    Color(0xFFC8F06A),
    Color(0xFF7CC8FF),
  ]),
  lavender(GlassVariant.liquid, Color(0xFF8B6CFF), Color(0xFFF3F0FA), [
    Color(0xFFA98CFF),
    Color(0xFFFF9ED8),
    Color(0xFF7FB2FF),
  ]),
  peach(GlassVariant.liquid, Color(0xFFFF9F43), Color(0xFFF9F3EC), [
    Color(0xFFFFB86B),
    Color(0xFFFFE27A),
    Color(0xFFFF8A80),
  ]),
  // Frost: smoky panels over black, the colour glowing through
  midnight(GlassVariant.frost, Color(0xFFFFE600), Color(0xFF07070B), [
    Color(0xFFFFE600),
    Color(0xFF3D5BFF),
    Color(0xFFFFE600),
  ]),
  neon(GlassVariant.frost, Color(0xFF00F0FF), Color(0xFF05070C), [
    Color(0xFF00E0FF),
    Color(0xFFFF2BD6),
    Color(0xFF00E0FF),
  ]),
  aurora(GlassVariant.frost, Color(0xFF3DFFA0), Color(0xFF050A0A), [
    Color(0xFF2BFFA0),
    Color(0xFF1FB8C8),
    Color(0xFF7B5CFF),
  ]),
  magma(GlassVariant.frost, Color(0xFFFF5A36), Color(0xFF0B0606), [
    Color(0xFFFF3D1F),
    Color(0xFFFF9A2E),
    Color(0xFFB0102E),
  ]),
  violet(GlassVariant.frost, Color(0xFFB57BFF), Color(0xFF08060D), [
    Color(0xFF9B5CFF),
    Color(0xFF4A3DFF),
    Color(0xFFE05CFF),
  ]),
  ocean(GlassVariant.frost, Color(0xFF4D9BFF), Color(0xFF05080D), [
    Color(0xFF2E7BFF),
    Color(0xFF00C2C2),
    Color(0xFF2E3DFF),
  ]),
  rose(GlassVariant.frost, Color(0xFFFF4FA3), Color(0xFF0C0609), [
    Color(0xFFFF3D9A),
    Color(0xFF9B3DFF),
    Color(0xFFFF7A5C),
  ]),
  // Clear: nearly clear panels with bright edges over a calm backdrop
  frostbite(GlassVariant.clear, Color(0xFF2F7BFF), Color(0xFFDCE3EE), [
    Color(0xFF8FB8FF),
    Color(0xFFB8C8E0),
    Color(0xFFE6ECF5),
  ]),
  pearl(GlassVariant.clear, Color(0xFFFFD600), Color(0xFFD9DEE6), [
    Color(0xFFFFE600),
    Color(0xFF9FB4D8),
    Color(0xFFEEF0F4),
  ]),
  sage(GlassVariant.clear, Color(0xFF2FAF7A), Color(0xFFDDE5DF), [
    Color(0xFF9FD8B8),
    Color(0xFFC8D8C0),
    Color(0xFFEEF2EC),
  ]),
  sand(GlassVariant.clear, Color(0xFFE0902F), Color(0xFFE8E1D6), [
    Color(0xFFF2C48A),
    Color(0xFFD8C8B0),
    Color(0xFFF4EFE6),
  ]),
  graphite(GlassVariant.clear, Color(0xFF1C1C22), Color(0xFFD6D8DD), [
    Color(0xFFB0B4BE),
    Color(0xFFE4E6EA),
    Color(0xFF9DA2AD),
  ]),
  lilac(GlassVariant.clear, Color(0xFF9A6BFF), Color(0xFFE2DDEC), [
    Color(0xFFC8B0FF),
    Color(0xFFE6C8F0),
    Color(0xFFD0D8F0),
  ]);

  const GlassScheme(this.variant, this.accent, this.base, this.spots);

  /// the kind of glass: milky (Liquid), smoky (Frost) or clear
  final GlassVariant variant;

  /// the colour of the chosen server, the connect button, the menu's chosen tab and the figures
  final Color accent;

  /// the backdrop's own colour
  final Color base;

  /// the soft colour spots on the backdrop: top left, right, bottom left
  final List<Color> spots;

  bool get dark => variant.dark;

  static const fallback = lemonade;

  /// The panels' fill: milky white, smoky, or nearly clear.
  Color get panel => switch (variant) {
    GlassVariant.liquid => Colors.white.withValues(alpha: .4),
    GlassVariant.frost => Colors.white.withValues(alpha: .08),
    GlassVariant.clear => Colors.white.withValues(alpha: .3),
  };

  /// The panels' edge: a bright line, softer on Frost.
  Color get edge => switch (variant) {
    GlassVariant.liquid => Colors.white.withValues(alpha: .75),
    GlassVariant.frost => Colors.white.withValues(alpha: .16),
    GlassVariant.clear => Colors.white.withValues(alpha: .9),
  };

  /// What a panel looks like laid on the backdrop, for working out readable colours on it.
  Color get panelOnBase => Color.alphaBlend(panel, Color.lerp(base, spots.first, dark ? .15 : .25)!);
}

/// The backdrop behind every Glass screen: the scheme's base colour with its three soft colour spots.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.scheme});

  final GlassScheme scheme;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _BackdropPainter(scheme), child: const SizedBox.expand()),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.scheme);

  final GlassScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.base);
    final strength = switch (scheme.variant) {
      GlassVariant.liquid => [.85, .75, .6],
      GlassVariant.frost => [.4, .45, .22],
      GlassVariant.clear => [.55, .7, .6],
    };
    final w = size.width;
    final h = size.height;
    // a spot: the colour fading out to nothing, as a blurred circle would
    void spot(Offset centre, double radius, Color colour, double alpha) {
      final rect = Rect.fromCircle(center: centre, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colour.withValues(alpha: alpha),
              colour.withValues(alpha: alpha * .45),
              colour.withValues(alpha: 0),
            ],
            stops: const [0, .45, 1],
          ).createShader(rect),
      );
    }

    spot(Offset(w * .05, h * .2), w * .85, scheme.spots[0], strength[0]);
    spot(Offset(w * 1.0, h * .5), w * .8, scheme.spots[1], strength[1]);
    spot(Offset(w * .1, h * .85), w * .75, scheme.spots[2], strength[2]);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.scheme != scheme;
}

/// A floating pane of glass: what's behind it blurred, the scheme's fill, a bright edge and a soft shadow. The menu
/// and the connect panel are drawn on it; the cards in the pages are plain see-through fills (blurring each one
/// would cost too much on a long list).
class GlassPane extends StatelessWidget {
  const GlassPane({super.key, required this.scheme, required this.child, this.radius = 30, this.padding});

  final GlassScheme scheme;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            // faint: it shows through the see-through pane
            color: Colors.black.withValues(alpha: scheme.dark ? .25 : .05),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: scheme.edge),
              // the light catching the top edge
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(Colors.white.withValues(alpha: scheme.dark ? .05 : .12), scheme.panel),
                  scheme.panel,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
