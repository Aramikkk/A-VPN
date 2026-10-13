import 'package:flutter/foundation.dart';
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
  citrus(GlassVariant.liquid, Color(0xFFFF8A00), Color(0xFFF8F2EA), [
    Color(0xFFFFB347),
    Color(0xFFFFE66D),
    Color(0xFF7BE0AD),
  ]),
  bubblegum(GlassVariant.liquid, Color(0xFFFF4FB8), Color(0xFFF9EFF5), [
    Color(0xFFFF9ED8),
    Color(0xFF9EC8FF),
    Color(0xFFFFE29A),
  ]),
  sky(GlassVariant.liquid, Color(0xFF2E9BFF), Color(0xFFEEF4FA), [
    Color(0xFF7CC4FF),
    Color(0xFFB5E8FF),
    Color(0xFFC8B8FF),
  ]),
  berry(GlassVariant.liquid, Color(0xFFC2185B), Color(0xFFF7EEF2), [
    Color(0xFFFF6FA8),
    Color(0xFFB07CFF),
    Color(0xFFFF9E80),
  ]),
  tropic(GlassVariant.liquid, Color(0xFF00C2A8), Color(0xFFEEF7F3), [
    Color(0xFF4FF0C8),
    Color(0xFFFFE066),
    Color(0xFFFF8FA3),
  ]),
  coral(GlassVariant.liquid, Color(0xFFFF5A5F), Color(0xFFF9F0EE), [
    Color(0xFFFF9A8B),
    Color(0xFFFFD3A5),
    Color(0xFF8EC5FF),
  ]),
  grape(GlassVariant.liquid, Color(0xFF7B3FE4), Color(0xFFF3EFFA), [
    Color(0xFFB48CFF),
    Color(0xFFFF9ED8),
    Color(0xFF8FD3FF),
  ]),
  kiwi(GlassVariant.liquid, Color(0xFF5FAE22), Color(0xFFF2F7EC), [
    Color(0xFFB8F06A),
    Color(0xFFFFE46D),
    Color(0xFF7FD8C8),
  ]),
  candy(GlassVariant.liquid, Color(0xFFFF6F91), Color(0xFFF9F1F3), [
    Color(0xFFFFC0CB),
    Color(0xFFB5EAD7),
    Color(0xFFC7CEEA),
  ]),
  rainbow(GlassVariant.liquid, Color(0xFF5B6CFF), Color(0xFFF4F2F0), [
    Color(0xFFFF8A80),
    Color(0xFFFFE57F),
    Color(0xFF80D8FF),
  ]),
  ash(GlassVariant.liquid, Color(0xFF2B6CF0), Color(0xFFEDEDEF), [
    Color(0xFFD5D6DA),
    Color(0xFFE6E6E9),
    Color(0xFFC9CACF),
  ], calm: true),
  chalk(GlassVariant.liquid, Color(0xFFB58900), Color(0xFFF1F0EC), [
    Color(0xFFDEDCD5),
    Color(0xFFE9E8E3),
    Color(0xFFD2D0C8),
  ], calm: true),
  steel(GlassVariant.liquid, Color(0xFF1E7FD8), Color(0xFFE6E8EB), [
    Color(0xFFCDD1D6),
    Color(0xFFDDE0E4),
    Color(0xFFC2C7CD),
  ], calm: true),
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
  ember(GlassVariant.frost, Color(0xFFFF7A1A), Color(0xFF0B0705), [
    Color(0xFFFF5A1F),
    Color(0xFFFFB01F),
    Color(0xFF8A1F00),
  ]),
  cyber(GlassVariant.frost, Color(0xFFFF2BD6), Color(0xFF07050C), [
    Color(0xFFFF2BD6),
    Color(0xFF00E0FF),
    Color(0xFF6A00FF),
  ]),
  emerald(GlassVariant.frost, Color(0xFF00E676), Color(0xFF050A07), [
    Color(0xFF00C853),
    Color(0xFF00BFA5),
    Color(0xFF1DE9B6),
  ]),
  abyss(GlassVariant.frost, Color(0xFF00B0FF), Color(0xFF04070D), [
    Color(0xFF0040FF),
    Color(0xFF00B0FF),
    Color(0xFF00E5FF),
  ]),
  crimson(GlassVariant.frost, Color(0xFFFF3D5A), Color(0xFF0B0507), [
    Color(0xFFD50000),
    Color(0xFFFF4081),
    Color(0xFF7B0000),
  ]),
  gold(GlassVariant.frost, Color(0xFFFFC400), Color(0xFF0A0805), [
    Color(0xFFFFAB00),
    Color(0xFFFF6D00),
    Color(0xFFFFD740),
  ]),
  nebula(GlassVariant.frost, Color(0xFFD05CFF), Color(0xFF07050D), [
    Color(0xFF7C4DFF),
    Color(0xFFFF4081),
    Color(0xFF448AFF),
  ]),
  toxic(GlassVariant.frost, Color(0xFFC6FF00), Color(0xFF060905), [
    Color(0xFF76FF03),
    Color(0xFFC6FF00),
    Color(0xFF00E676),
  ]),
  ice(GlassVariant.frost, Color(0xFF80D8FF), Color(0xFF05080C), [
    Color(0xFF40C4FF),
    Color(0xFFB388FF),
    Color(0xFF84FFFF),
  ]),
  dusk(GlassVariant.frost, Color(0xFFFF6E40), Color(0xFF09060A), [
    Color(0xFFFF6E40),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
  ]),
  onyx(GlassVariant.frost, Color(0xFFFFD60A), Color(0xFF0A0A0B), [
    Color(0xFF2A2A2E),
    Color(0xFF1C1C20),
    Color(0xFF333338),
  ], calm: true),
  carbon(GlassVariant.frost, Color(0xFF4DA3FF), Color(0xFF0B0C0E), [
    Color(0xFF25282D),
    Color(0xFF1A1C20),
    Color(0xFF30343A),
  ], calm: true),
  smoke(GlassVariant.frost, Color(0xFFFFB020), Color(0xFF0C0C0C), [
    Color(0xFF303030),
    Color(0xFF222222),
    Color(0xFF3A3A3A),
  ], calm: true),
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
  ]),
  mist(GlassVariant.clear, Color(0xFF5C7CFA), Color(0xFFE3E7EF), [
    Color(0xFFC5D0F0),
    Color(0xFFE0E6F5),
    Color(0xFFB8C4E0),
  ]),
  linen(GlassVariant.clear, Color(0xFFC08A4A), Color(0xFFEDE6DC), [
    Color(0xFFE8D5BC),
    Color(0xFFF2E8DA),
    Color(0xFFD8C8B4),
  ]),
  slate(GlassVariant.clear, Color(0xFF3D5A80), Color(0xFFD8DEE6), [
    Color(0xFFA9B8CC),
    Color(0xFFD5DDE8),
    Color(0xFF8FA3BC),
  ]),
  quartz(GlassVariant.clear, Color(0xFFD9668A), Color(0xFFEEDFE4), [
    Color(0xFFF2C4D2),
    Color(0xFFF8E1E8),
    Color(0xFFE0C4D8),
  ]),
  seafoam(GlassVariant.clear, Color(0xFF2BAE9B), Color(0xFFDCE9E6), [
    Color(0xFFA8E0D4),
    Color(0xFFD6F0EA),
    Color(0xFFB8D8E0),
  ]),
  cloud(GlassVariant.clear, Color(0xFF6A7FA8), Color(0xFFE4E8EE), [
    Color(0xFFD0D8E4),
    Color(0xFFECEFF4),
    Color(0xFFBCC6D6),
  ]),
  apricot(GlassVariant.clear, Color(0xFFF08C4A), Color(0xFFEFE4DC), [
    Color(0xFFF6CBA8),
    Color(0xFFFBE3D0),
    Color(0xFFE8C8B8),
  ]),
  haze(GlassVariant.clear, Color(0xFF7E6BD9), Color(0xFFE4E0EE), [
    Color(0xFFD2C8F0),
    Color(0xFFECE6FA),
    Color(0xFFC8D0F0),
  ]),
  glacier(GlassVariant.clear, Color(0xFF3AA6C9), Color(0xFFDDE9EE), [
    Color(0xFFB8DFEC),
    Color(0xFFE2F2F7),
    Color(0xFFC0D8E4),
  ]),
  moss(GlassVariant.clear, Color(0xFF6B8E3A), Color(0xFFE0E6D8), [
    Color(0xFFC8D8B0),
    Color(0xFFE6EED8),
    Color(0xFFB8C8A0),
  ]),
  fog(GlassVariant.clear, Color(0xFF2563EB), Color(0xFFD9DADD), [
    Color(0xFFC4C6CB),
    Color(0xFFE2E3E6),
    Color(0xFFB9BCC2),
  ], calm: true),
  stone(GlassVariant.clear, Color(0xFFA87A00), Color(0xFFDAD8D3), [
    Color(0xFFC6C3BC),
    Color(0xFFE3E1DC),
    Color(0xFFBCB8B0),
  ], calm: true),
  silver(GlassVariant.clear, Color(0xFF0A74E0), Color(0xFFDEE0E3), [
    Color(0xFFC8CBD0),
    Color(0xFFE8E9EC),
    Color(0xFFBFC3C9),
  ], calm: true);

  const GlassScheme(this.variant, this.accent, this.base, this.spots, {this.calm = false});

  /// a quiet one: grey or black, the colour only on the text and the lines (a chosen row, a toggle that's on and the
  /// chosen tab are lit in grey, not in the colour)
  final bool calm;

  /// the scheme's own kind of glass: milky (Liquid), smoky (Frost) or clear
  final GlassVariant variant;

  /// the colour of the chosen server, the connect button, the menu's chosen tab and the figures
  final Color accent;

  /// the backdrop's own colour, in the scheme's own brightness (Frost dark, the others light)
  final Color base;

  /// the soft colour spots on the backdrop: top left, right, bottom left
  final List<Color> spots;

  static const fallback = lemonade;

  /// The scheme by day or by night: every scheme has both. By night the backdrop goes near-black with the same
  /// colour spots glowing through smoky glass (Clear keeps its brighter edges); by day it goes light with milky
  /// glass (Clear: nearly clear).
  GlassLook look(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final native = variant.dark == dark;
    final kind = dark
        ? (variant == GlassVariant.clear ? GlassVariant.clear : GlassVariant.frost)
        : (variant == GlassVariant.clear ? GlassVariant.clear : GlassVariant.liquid);
    final base = native
        ? this.base
        : dark
        ? Color.lerp(const Color(0xFF07070B), spots.first, .05)!
        : Color.lerp(const Color(0xFFF6F5F2), spots.first, .07)!;
    // a near-black accent (Graphite) turns near-white by night
    final accent = dark && this.accent.computeLuminance() < .05 ? const Color(0xFFE8E8EE) : this.accent;
    return GlassLook(
      dark: dark,
      calm: calm,
      kind: kind,
      accent: accent,
      base: base,
      spots: spots,
      strength: dark
          ? (kind == GlassVariant.clear ? const [.32, .4, .28] : const [.4, .45, .22])
          : (kind == GlassVariant.clear ? const [.55, .7, .6] : const [.85, .75, .6]),
      panel: switch ((kind, dark)) {
        (GlassVariant.clear, true) => Colors.white.withValues(alpha: .06),
        (_, true) => Colors.white.withValues(alpha: .08),
        (GlassVariant.clear, false) => Colors.white.withValues(alpha: .3),
        (_, false) => Colors.white.withValues(alpha: .4),
      },
      edge: switch ((kind, dark)) {
        (GlassVariant.clear, true) => Colors.white.withValues(alpha: .26),
        (_, true) => Colors.white.withValues(alpha: .16),
        (GlassVariant.clear, false) => Colors.white.withValues(alpha: .9),
        (_, false) => Colors.white.withValues(alpha: .75),
      },
    );
  }
}

/// A Glass scheme as it is drawn by day or by night.
@immutable
class GlassLook {
  const GlassLook({
    required this.dark,
    this.calm = false,
    required this.kind,
    required this.accent,
    required this.base,
    required this.spots,
    required this.strength,
    required this.panel,
    required this.edge,
  });

  final bool dark;

  /// lit in grey rather than in the accent (see [GlassScheme.calm])
  final bool calm;

  /// the glass drawn: milky, smoky or clear
  final GlassVariant kind;

  final Color accent;

  /// the backdrop's colour
  final Color base;

  /// the backdrop's soft colour spots and how strong each one is
  final List<Color> spots;
  final List<double> strength;

  /// the panels' see-through fill and their bright edge
  final Color panel;
  final Color edge;

  /// The accent laid over a pane at [alpha] (the chosen server's row, a toggle that's on), as strong as it can be
  /// while [ink] (the text on it) still reads at 4.5:1: a dark accent by day or a light one by night is let fainter.
  Color tint(Color ink, double alpha) {
    // a calm scheme lights them in grey: white on the dark glass, a shade on the light
    final colour = calm ? (dark ? Colors.white : Colors.black) : accent;
    var a = calm ? alpha * (dark ? .45 : .14) : alpha;
    var fill = Color.alphaBlend(colour.withValues(alpha: a), panelOnBase);
    while (a > .05 && _contrast(ink, fill) < 4.5) {
      a -= .03;
      fill = Color.alphaBlend(colour.withValues(alpha: a), panelOnBase);
    }
    return colour.withValues(alpha: a);
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return ((la > lb ? la : lb) + .05) / ((la > lb ? lb : la) + .05);
  }

  /// What a panel looks like laid on the backdrop, for working out readable colours on it.
  Color get panelOnBase => Color.alphaBlend(panel, Color.lerp(base, spots.first, dark ? .15 : .25)!);

  @override
  bool operator ==(Object other) =>
      other is GlassLook &&
      other.dark == dark &&
      other.calm == calm &&
      other.kind == kind &&
      other.accent == accent &&
      other.base == base &&
      other.panel == panel &&
      other.edge == edge &&
      listEquals(other.spots, spots) &&
      listEquals(other.strength, strength);

  @override
  int get hashCode => Object.hash(dark, kind, accent, base, panel, edge, Object.hashAll(spots));
}

/// The backdrop behind every Glass screen: the base colour with three soft colour spots.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.look});

  final GlassLook look;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _BackdropPainter(look), child: const SizedBox.expand()),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.look);

  final GlassLook look;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = look.base);
    final strength = look.strength;
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

    spot(Offset(w * .05, h * .2), w * .85, look.spots[0], strength[0]);
    spot(Offset(w * 1.0, h * .5), w * .8, look.spots[1], strength[1]);
    spot(Offset(w * .1, h * .85), w * .75, look.spots[2], strength[2]);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.look != look;
}

/// A floating pane of glass: the scheme's fill lit along its top and a bright edge. The menu, the toggles and the
/// connect panel are drawn on it.
class GlassPane extends StatelessWidget {
  const GlassPane({super.key, required this.look, required this.child, this.radius = 30, this.padding});

  final GlassLook look;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    // no shadow (it shows through the see-through pane as a dirty band along its bottom) and no live blur: the
    // backdrop under the panes is soft already, and a blur redone every frame made swipes stutter (the connect
    // panel slides with its tab)
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: look.edge),
        // the light catching the top edge
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: look.dark ? .05 : .12), look.panel),
            look.panel,
          ],
        ),
      ),
      child: child,
    );
  }
}
