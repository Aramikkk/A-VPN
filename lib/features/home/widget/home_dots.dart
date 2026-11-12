part of 'avpn_home_body.dart';

// ───────────────────────────── Dots ─────────────────────────────

/// Dots: paper with a fine dot grid, figures drawn as a matrix of dots, a monospaced face, black and grey with one red.
abstract final class _Dots {
  static Color paper(bool dark) => dark ? const Color(0xFF151515) : const Color(0xFFEAE9E5);
  static Color ink(bool dark) => dark ? const Color(0xFFEDEDE8) : const Color(0xFF111111);
  static Color grid(bool dark) => dark ? const Color(0xFF2C2C2C) : const Color(0xFFCDCCC7);
  static Color soft(bool dark) => dark ? const Color(0xFF9A9A95) : const Color(0xFF6A6A66);

  /// the style's one colour (the owner's choice in Settings → Themes; red until picked)
  static Color get red => dotsAccentNow;

  static TextStyle mono(double size, Color colour, {FontWeight weight = FontWeight.w500, double spacing = 1.4}) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: 1.25,
        color: colour,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// A sheet of the dotted paper with [child] on it.
Widget _dotPaper(
  BuildContext context,
  Widget child, {
  EdgeInsets padding = const EdgeInsets.fromLTRB(16, 11, 16, 11),
  bool highlight = false,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      // the chosen one (a server in the list): framed in the accent and a little lighter
      color: highlight ? Color.alphaBlend(_Dots.red.withValues(alpha: .1), _Dots.paper(dark)) : _Dots.paper(dark),
      borderRadius: BorderRadius.circular(dotsRadius),
      border: highlight
          ? Border.all(color: _Dots.red, width: 2)
          : Border.all(color: _Dots.ink(dark).withValues(alpha: .28)),
    ),
    child: child,
  );
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.paper, required this.dot});

  final Color paper;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    // the whole screen's dots in one call (thousands of separate circles were slow to draw)
    canvas.drawPoints(
      ui.PointMode.points,
      [
        for (var y = 6.0; y < size.height; y += 10)
          for (var x = 6.0; x < size.width; x += 10) Offset(x, y),
      ],
      Paint()
        ..color = dot
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.paper != paper || old.dot != dot;
}

/// The ink that reads on the accent (Bento's hero tile, its chips and its connect button): dark on a light accent,
/// white on a dark one (the OLED palette's accent is black, and the dark ink vanished on it)
Color _onAccent(Color accent) => accent.computeLuminance() > .4 ? ContrastPalette.ink : Colors.white;

/// The "clear" sign of the stats pages: in Dots a small bin of dots (a lid and a body, the body's sides lit), else the
/// sweep sign.
Widget clearIcon({Color? color, double size = 24}) {
  if (homeLookNow != HomeLayout.dots) return Icon(Icons.delete_sweep_rounded, color: color, size: size);
  return Builder(
    builder: (context) => CustomPaint(
      size: Size.square(size),
      painter: _DotsBinPainter(
        color ?? IconTheme.of(context).color ?? _Dots.ink(Theme.of(context).brightness == Brightness.dark),
      ),
    ),
  );
}

class _DotsBinPainter extends CustomPainter {
  _DotsBinPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 8;
    final lit = Paint()..color = colour;
    final dim = Paint()..color = colour.withValues(alpha: .3);
    final r = step * .38;
    Offset at(num i, num j) => Offset((i + .5) * step, (j + .5) * step);
    // the handle and the lid
    for (final i in const [3, 4]) {
      canvas.drawCircle(at(i, 0), r, lit);
    }
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(at(i, 1.6), r, lit);
    }
    // the body: its sides and bottom lit, the middle faint
    for (var j = 3; j < 8; j++) {
      for (var i = 1; i <= 6; i++) {
        final edge = i == 1 || i == 6 || j == 7;
        canvas.drawCircle(at(i, j), edge ? r : r * .55, edge ? lit : dim);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsBinPainter old) => old.colour != colour;
}

/// A shield of dots (the Dots look's shield): a field of dots in the shape of a shield, its edge dots bolder and the
/// inner ones fainter; [hollow]: only its edge (a shield with nothing in it: traffic that goes without the VPN).
void paintDotShield(Canvas canvas, Rect box, Color colour, {bool hollow = false, bool struck = false}) {
  const cols = 7;
  const rows = 8;
  final sx = box.width / cols;
  final sy = box.height / rows;
  bool inside(int i, int j) {
    if (i < 0 || i >= cols || j < 0 || j >= rows) return false;
    final u = ((i + .5) / cols) * 2 - 1;
    final v = (j + .5) / rows;
    final w = v < .5 ? 1.0 : math.sqrt(math.max(0.0, 1 - math.pow((v - .5) / .5, 2)));
    return u.abs() <= w * .95;
  }

  final r = math.min(sx, sy) * .42;
  final bold = Paint()..color = colour;
  final soft = Paint()..color = colour.withValues(alpha: .5);
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      if (!inside(i, j)) continue;
      final edge = !inside(i - 1, j) || !inside(i + 1, j) || !inside(i, j - 1) || !inside(i, j + 1);
      if (hollow && !edge) continue;
      canvas.drawCircle(
        Offset(box.left + (i + .5) * sx, box.top + (j + .5) * sy),
        edge ? r : r * .55,
        edge ? bold : soft,
      );
    }
  }
  // struck out: a line of dots across it, from the upper left to the lower right (a little over the edges)
  if (struck) {
    const n = 7;
    for (var k = 0; k < n; k++) {
      final t = k / (n - 1);
      canvas.drawCircle(Offset(box.left - 2 + (box.width + 4) * t, box.top - 1 + (box.height + 2) * t), r * 1.05, bold);
    }
  }
}

class _DotShieldPainter extends CustomPainter {
  _DotShieldPainter(this.colour, this.hollow);

  final Color colour;
  final bool hollow;

  @override
  void paint(Canvas canvas, Size size) => paintDotShield(canvas, Offset.zero & size, colour, hollow: hollow);

  @override
  bool shouldRepaint(_DotShieldPainter old) => old.colour != colour || old.hollow != hollow;
}

/// The shield sign in the Dots look (of dots), as an icon [size] high.
Widget shieldSign({Color? color, double size = 24, bool hollow = false}) => Builder(
  builder: (context) => CustomPaint(
    size: Size(size * .88, size),
    painter: _DotShieldPainter(color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface, hollow),
  ),
);

/// A sample of the figures in one of the looks (Settings → Themes), on the black of the Dots.
class DotsDigitsSample extends StatelessWidget {
  const DotsDigitsSample(this.look, this.text, {super.key});

  final DotsDigits look;
  final String text;

  @override
  Widget build(BuildContext context) =>
      _DotNumber(text, cell: 3.4, colour: const Color(0xFFF2F2EE), faint: const Color(0xFF3A3A3A), look: look);
}

/// A number drawn as a 5×7 matrix of dots for each figure: the lit dots in the ink, the rest faint.
class _DotNumber extends StatelessWidget {
  const _DotNumber(this.text, {required this.cell, required this.colour, required this.faint, this.look});

  /// how the figures are drawn: null, as the settings have it ([dotsDigitsNow]); a sample in Themes shows each of them
  final DotsDigits? look;

  final String text;
  final double cell;
  final Color colour;
  final Color faint;

  static const _glyphs = {
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    '—': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
    '.': ['0', '0', '0', '0', '0', '0', '1'],
    '%': ['11001', '11010', '00010', '00100', '01000', '01011', '10011'],
  };

  /// the columns a glyph takes with the gap after it
  static int advance(String c) => _glyphs[c]![0].length + 1;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('').where(_glyphs.containsKey).toList();
    final width = chars.isEmpty ? 0.0 : (chars.fold<int>(0, (n, c) => n + advance(c)) - 1) * cell;
    // the figures are seven rows high, the bolt nine
    final rows = chars.fold<int>(7, (n, c) => math.max(n, _glyphs[c]!.length));
    final style = look ?? dotsDigitsNow;
    // solid figures in a font: as high as the matrix would be, about as wide
    if ((style == DotsDigits.mono || style == DotsDigits.wide) && !chars.any((c) => _glyphs[c]!.length > 7)) {
      return _SolidDigits(chars.join(), cell: cell, colour: colour, wide: style == DotsDigits.wide);
    }
    return CustomPaint(
      size: Size(width, rows * cell),
      painter: _DotNumberPainter(
        chars: chars,
        cell: cell,
        colour: colour,
        faint: faint,
        solid: style == DotsDigits.blocks,
      ),
    );
  }
}

/// How many rows of the bolt are charged at [progress] (0 to 1) of a charge: from the bottom up, the last part of the
/// cycle all of them (the flash), then it starts over.
int boltChargedRows(double progress, int rows) => (progress.clamp(0.0, 1.0) * (rows + 2)).floor().clamp(0, rows);

/// Figures in a thick font standing on the line the matrix stands on, their capitals as high as its seven rows.
class _SolidDigits extends StatelessWidget {
  const _SolidDigits(this.text, {required this.cell, required this.colour, required this.wide});

  final String text;
  final double cell;
  final Color colour;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final height = 7 * cell;
    // the share of the size the capitals take (the font's own): the size that makes them seven rows high
    final capital = wide ? .70 : .73;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: wide ? 'Unbounded' : 'JetBrains Mono',
          fontWeight: wide ? FontWeight.w800 : FontWeight.w700,
          fontSize: height / capital,
          height: 1,
          letterSpacing: wide ? -1 : 0,
          color: colour,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    return CustomPaint(size: Size(painter.width, height), painter: _TextOnLinePainter(painter, height - baseline));
  }
}

class _TextOnLinePainter extends CustomPainter {
  const _TextOnLinePainter(this.painter, this.dy);

  final TextPainter painter;
  final double dy;

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas, Offset(0, dy));

  @override
  bool shouldRepaint(_TextOnLinePainter old) => true;
}

class _DotNumberPainter extends CustomPainter {
  _DotNumberPainter({
    required this.chars,
    required this.cell,
    required this.colour,
    required this.faint,
    this.solid = false,
  });

  /// the lit cells as solid squares, the rest nothing (the pixels look of the figures)
  final bool solid;

  final List<String> chars;
  final double cell;
  final Color colour;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = colour;
    final off = Paint()..color = faint;
    final r = cell * .42;
    var column = 0;
    for (final c in chars) {
      final rows = _DotNumber._glyphs[c]!;
      for (var y = 0; y < rows.length; y++) {
        for (var x = 0; x < rows[y].length; x++) {
          final centre = Offset((column + x + .5) * cell, (y + .5) * cell);
          if (solid) {
            if (rows[y][x] == '1')
              canvas.drawRect(Rect.fromCenter(center: centre, width: cell * .96, height: cell * .96), on);
            continue;
          }
          canvas.drawCircle(centre, rows[y][x] == '1' ? r : r * .45, rows[y][x] == '1' ? on : off);
        }
      }
      column += _DotNumber.advance(c);
    }
  }

  @override
  bool shouldRepaint(_DotNumberPainter old) =>
      old.chars.join() != chars.join() ||
      old.cell != cell ||
      old.colour != colour ||
      old.faint != faint ||
      old.solid != solid;
}

/// Ten small dots, [lit] of them in [colour] and the rest faint: the dock's loss and servers answering
Widget _dotMeter(BuildContext context, int lit, Color colour) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 10; i++)
        Container(
          width: 4.5,
          height: 4.5,
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < lit ? colour : _Dots.ink(dark).withValues(alpha: .18),
          ),
        ),
    ],
  );
}

/// A line of the dotted sheet: a label in small capitals on the left, the value on the right.
Widget _dotRow(BuildContext context, String label, String value, {Color? valueColour, String? country}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final row = Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _Dots.mono(11, _Dots.soft(dark)),
        ),
      ),
      const Gap(8),
      // the sites' lines: the country in a column of its own between the name and the delay, where the site's server
      // is in another country than the main one (blank where it is the same), the delay in a column too
      if (country != null) ...[
        SizedBox(
          width: 112,
          child: Text(
            country.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _Dots.mono(10, _Dots.ink(dark), spacing: 1),
          ),
        ),
        SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: _Dots.mono(15, valueColour ?? _Dots.ink(dark), weight: FontWeight.w800, spacing: .5),
            ),
          ),
        ),
      ] else
        Text(value, style: _Dots.mono(15, valueColour ?? _Dots.ink(dark), weight: FontWeight.w800, spacing: .5)),
    ],
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    // a site in another country than the main one: a faint plate under the whole line (name, country, delay)
    child: country != null && country.isNotEmpty
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -6,
                right: -6,
                top: -2,
                bottom: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _Dots.ink(dark).withValues(alpha: dark ? .09 : .07),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              row,
            ],
          )
        : row,
  );
}

Widget _dotRule(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Container(height: 1, color: _Dots.ink(dark).withValues(alpha: .7)),
  );
}

/// Dots' server: the flag, the protocol in small capitals over the country, the ping in dots.
Widget _dotsServerRow(
  BuildContext context, {
  required String? flag,
  required bool group,
  required String name,
  required String caption,
  required String ms,
  required bool testing,
  required VoidCallback onTap,
  Widget? lead,
  bool selected = false,
  bool pingShown = true,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ink = _Dots.ink(dark);
  if (lead != null) {
    // the current server: the button at the left, the flag and the country in the middle, the ping in dots at the right
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _dotPaper(
          context,
          // the bolt at the left, the flag and the country in the middle, the fewer-hops anchor at the right (where the ping was:
          // the ping is in the list this row opens); both signs the same width, so the country is the row's own middle
          _centeredServer(
            lead: SizedBox(width: 40, child: Center(child: lead)),
            reserve: 52,
            center: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // a little lower: level with the middle of the two lines beside it
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: group
                      ? SizedBox(width: 46, child: Icon(Icons.auto_awesome_rounded, size: 30, color: ink))
                      : flagMark(flag, width: 46),
                ),
                const Gap(10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        caption.toUpperCase(),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: _Dots.mono(9, _Dots.soft(dark), spacing: 0.8),
                      ),
                      const Gap(2),
                      Text(
                        name.toUpperCase(),
                        // a long name takes a second line rather than being cut (a narrow screen)
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: _Dots.mono(15, ink, weight: FontWeight.w800, spacing: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: SizedBox(
              width: 40,
              child: Center(
                child: pingShown
                    ? (testing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                            )
                          : _DotNumber(ms == '×' ? '—' : ms, cell: 4, colour: ink, faint: _Dots.grid(dark)))
                    : const _HopsAnchor(),
              ),
            ),
          ),
          // the signs are not pressed to the block's edge
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        ),
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _dotPaper(
        context,
        Row(
          children: [
            // the flag as tall as the ping's dots on the right (seven cells of 4)
            if (group)
              SizedBox(width: 42, child: Icon(Icons.auto_awesome_rounded, size: 28, color: ink))
            else
              flagMark(flag, width: 42),
            const Gap(12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Dots.mono(10, _Dots.soft(dark)),
                  ),
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Dots.mono(15, ink, weight: FontWeight.w800, spacing: 1),
                  ),
                ],
              ),
            ),
            if (testing)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
            else
              _DotNumber(ms == '×' ? '—' : ms, cell: 4, colour: ink, faint: _Dots.grid(dark)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        highlight: selected,
      ),
    ),
  );
}

/// Dots' connections: the count in dots, the VPN and the bypass on a line under it.
Widget _dotsConnections(
  BuildContext context,
  Translations t, {
  required int open,
  required int vpn,
  required int direct,
  bool slim = false,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ink = _Dots.ink(dark);
  if (slim) {
    // one line, for a page too low for the two: the count and the split, the title before them
    return _dotPaper(
      context,
      Row(
        children: [
          Expanded(child: Text(t.avpn.connBlockTitle.toUpperCase(), style: _Dots.mono(11, _Dots.soft(dark)))),
          Text('$open', style: _Dots.mono(16, ink, weight: FontWeight.w800)),
          const Gap(14),
          Text('$vpn / $direct', style: _Dots.mono(13, _Dots.soft(dark))),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
    );
  }
  return _dotPaper(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(t.avpn.connBlockTitle.toUpperCase(), style: _Dots.mono(11, _Dots.soft(dark)))),
            _DotNumber('$open', cell: 4, colour: ink, faint: _Dots.grid(dark)),
          ],
        ),
        const Gap(4),
        _dotRow(context, 'VPN / ${t.avpn.connDirect}', '$vpn / $direct'),
      ],
    ),
  );
}

/// Dots' connect control: a toggle of dots right on the paper, a track of small dots with a square thumb of nine
/// dots; off, the thumb sits at the left, faint; on, at the right, lit in the accent and glowing; connecting, it runs
/// back and forth. The network is named under it.
class _DotsButton extends HookWidget {
  const _DotsButton({required this.on, required this.busy, required this.size, this.label, this.onTap});

  final bool on;
  final bool busy;
  final double size;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final run = useAnimationController(duration: const Duration(milliseconds: 900));
    useEffect(() {
      busy ? run.repeat(reverse: true) : run.stop();
      return null;
    }, [busy]);
    final ink = _Dots.ink(dark);
    final soft = _Dots.soft(dark);
    final width = size * 1.15;
    Widget toggle(double position) => CustomPaint(
      size: Size(width, width * 2 / 10),
      painter: _ToggleDotsPainter(
        position: position,
        thumb: on || busy ? _Dots.red : soft,
        track: ink.withValues(alpha: .2),
        glow: on && !busy,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? AnimatedBuilder(
                    animation: run,
                    builder: (context, _) => toggle(Curves.easeInOut.transform(run.value)),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: on ? 1.0 : 0.0),
                    duration: lightDuration(const Duration(milliseconds: 260)),
                    curve: Curves.easeOutCubic,
                    builder: (context, position, _) => toggle(position),
                  ),
            // the line stays when there is no network to name, so the panel does not change height
            const Gap(10),
            Text((label ?? ' ').toUpperCase(), style: _Dots.mono(10, on ? ink : soft, spacing: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _ToggleDotsPainter extends CustomPainter {
  _ToggleDotsPainter({required this.position, required this.thumb, required this.track, required this.glow});

  /// 0 at the left end, 1 at the right
  final double position;
  final Color thumb;
  final Color track;
  final bool glow;

  static const _columns = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / (_columns - 1);
    final row = size.height / 2;
    final small = step * .17;
    final big = step * .4;
    final trackPaint = Paint()..color = track;
    for (var j = 0; j < 3; j++) {
      for (var i = 0; i < _columns; i++) {
        canvas.drawCircle(Offset(i * step, row * j), small, trackPaint);
      }
    }
    final left = position * (_columns - 3);
    final lit = Paint()..color = thumb;
    for (var j = 0; j < 3; j++) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset((left + i) * step, row * j), big, lit);
      }
    }
    if (glow) {
      canvas.drawCircle(
        Offset((left + 1) * step, row),
        step * 1.6,
        Paint()
          ..color = thumb.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
  }

  @override
  bool shouldRepaint(_ToggleDotsPainter old) =>
      old.position != position || old.thumb != thumb || old.track != track || old.glow != glow;
}

/// A plate behind a sign on the server's row (Dots): a rounded square with a thin frame; [on] fills it with the ink (the sign then
/// in the paper's colour).
class _SignPlate extends StatelessWidget {
  const _SignPlate({required this.child, this.on = false});

  final Widget child;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = _Dots.ink(dark);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? ink : ink.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: on ? ink : ink.withValues(alpha: .28)),
      ),
      child: child,
    );
  }
}

/// The bolt or the little man of the server's row (Dots): one drawing, in thick round shapes, whatever look the figures have.
class _DotSign extends StatelessWidget {
  const _DotSign({required this.glyph, required this.colour, this.charge, this.progress, this.repaint});

  /// '⚡' (the bolt) or '☆' (the little man)
  final String glyph;
  final Color colour;

  /// the colour of the charge while the servers are pinged (the bolt)
  final Color? charge;
  final ValueGetter<double>? progress;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: glyph == '☆' ? const Size(33 * _ManPainter.aspect, 33) : const Size(24, 28),
    painter: glyph == '☆'
        ? _ManPainter(colour)
        : _BoltPainter(colour, charge: charge ?? colour, progress: progress, repaint: repaint),
  );
}

/// The fewer-hops button on the server's row (Dots): a little man stepping out past an edge on a plate; while the mode is on the plate
/// is filled and the man dark on it. A tap says what the mode is and turns it on or off.
class _HopsAnchor extends ConsumerWidget {
  const _HopsAnchor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final on = ref.watch(ConfigOptions.minHops);
    return GestureDetector(
      key: const Key('min-hops'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(showMinHopsDialog(context, ref, t, on)),
      child: _SignPlate(
        on: on,
        child: _DotSign(glyph: '☆', colour: on ? _Dots.paper(dark) : _Dots.ink(dark)),
      ),
    );
  }
}

/// The little man of the fewer-hops button: the figure stepping out past an edge, as in the picture it was traced from (contours of the
/// picture, not a drawing of mine). The shape is one piece with the edge, filled evenly (the small hole is a hole).
class _ManPainter extends CustomPainter {
  const _ManPainter(this.colour);

  final Color colour;

  /// the shape of the figure, traced from the picture: contours in a box of 131 by 295 (the first the outline, the others holes)
  static const _w = 131.0;
  static const _h = 295.0;
  static const _contours = [
    [Offset(1.0, 0.0), Offset(0.0, 1.5), Offset(0.0, 11.2), Offset(1.0, 12.2), Offset(0.0, 13.5), Offset(0.0, 22.2), Offset(1.0, 23.2), Offset(0.0, 24.5), Offset(0.0, 26.2), Offset(1.0, 27.2), Offset(0.0, 28.5), Offset(0.0, 217.2), Offset(1.0, 218.2), Offset(1.0, 220.5), Offset(0.0, 221.5), Offset(0.0, 228.2), Offset(1.0, 229.2), Offset(1.0, 235.5), Offset(0.0, 236.5), Offset(0.0, 238.2), Offset(1.0, 239.2), Offset(1.0, 242.5), Offset(0.0, 243.5), Offset(0.0, 250.2), Offset(1.0, 251.2), Offset(1.0, 253.5), Offset(0.0, 254.5), Offset(0.0, 272.2), Offset(1.0, 273.2), Offset(1.0, 275.5), Offset(0.0, 276.5), Offset(0.0, 283.2), Offset(1.0, 284.2), Offset(1.0, 294.8), Offset(5.8, 294.8), Offset(6.0, 288.2), Offset(40.0, 254.2), Offset(50.5, 241.5), Offset(53.5, 234.5), Offset(52.8, 230.8), Offset(50.5, 226.2), Offset(34.0, 206.5), Offset(18.0, 184.5), Offset(17.8, 182.8), Offset(14.8, 178.0), Offset(14.8, 174.8), Offset(20.0, 170.2), Offset(33.0, 155.2), Offset(58.2, 129.0), Offset(59.5, 129.0), Offset(61.0, 130.8), Offset(61.0, 135.0), Offset(64.0, 144.8), Offset(64.0, 149.0), Offset(66.0, 151.8), Offset(66.0, 157.0), Offset(70.2, 166.5), Offset(95.2, 186.5), Offset(97.5, 187.0), Offset(110.8, 197.8), Offset(114.8, 198.8), Offset(121.0, 198.8), Offset(124.5, 197.5), Offset(128.5, 193.5), Offset(129.8, 188.2), Offset(130.8, 187.2), Offset(130.8, 182.8), Offset(129.0, 181.5), Offset(128.5, 179.5), Offset(123.5, 175.2), Offset(121.2, 174.8), Offset(119.0, 172.0), Offset(106.2, 163.8), Offset(91.0, 151.5), Offset(88.8, 148.0), Offset(88.8, 145.8), Offset(86.8, 141.0), Offset(84.8, 133.0), Offset(84.8, 128.8), Offset(81.8, 120.0), Offset(77.5, 102.2), Offset(69.5, 94.2), Offset(67.2, 93.8), Offset(65.0, 91.0), Offset(58.0, 85.5), Offset(58.0, 83.2), Offset(55.2, 80.2), Offset(48.8, 79.0), Offset(44.2, 74.8), Offset(45.8, 72.8), Offset(49.0, 72.8), Offset(53.2, 76.5), Offset(55.5, 77.0), Offset(60.8, 80.8), Offset(67.0, 80.8), Offset(68.8, 81.8), Offset(79.0, 81.8), Offset(80.8, 80.8), Offset(85.0, 80.8), Offset(88.0, 79.8), Offset(91.2, 77.0), Offset(93.5, 76.5), Offset(99.0, 72.8), Offset(102.5, 68.5), Offset(106.8, 61.0), Offset(109.8, 50.0), Offset(108.8, 39.8), Offset(106.8, 33.8), Offset(102.5, 25.5), Offset(95.0, 18.0), Offset(91.2, 16.8), Offset(88.5, 14.2), Offset(80.8, 13.0), Offset(76.0, 11.0), Offset(71.8, 11.0), Offset(67.0, 13.0), Offset(59.8, 14.0), Offset(56.5, 16.8), Offset(52.8, 18.0), Offset(43.2, 28.2), Offset(40.0, 35.8), Offset(39.0, 39.8), Offset(39.0, 54.0), Offset(41.0, 61.0), Offset(45.0, 67.8), Offset(45.0, 70.0), Offset(43.0, 72.0), Offset(38.8, 72.0), Offset(31.5, 65.2), Offset(29.2, 64.8), Offset(26.5, 61.2), Offset(24.2, 60.8), Offset(22.0, 58.0), Offset(15.2, 53.8), Offset(13.0, 51.0), Offset(10.2, 49.8), Offset(6.0, 45.5), Offset(5.8, 0.0)],
    [Offset(9.5, 227.0), Offset(14.8, 233.2), Offset(15.0, 237.0), Offset(12.5, 240.8), Offset(7.5, 243.8), Offset(6.8, 242.8), Offset(6.8, 237.8), Offset(5.8, 236.0), Offset(5.8, 231.8), Offset(7.0, 228.2), Offset(8.2, 227.0)],
  ];

  /// width over height of the shape
  static const aspect = _w / _h;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final contour in _contours) {
      path.addPolygon(contour, true);
    }
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);
    canvas.drawPath(path, Paint()..color = colour);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ManPainter old) => old.colour != colour;
}

/// The lightning bolt of the best-server button as a picture (Mono, Grotesk), in the same thick round shapes as the little man, in a
/// box of 21 by 25.
class _BoltPainter extends CustomPainter {
  const _BoltPainter(this.colour, {required this.charge, this.progress, Listenable? repaint}) : super(repaint: repaint);

  final Color colour;

  /// the colour of the charge while the servers are pinged
  final Color charge;

  /// null: at rest, all of the bolt in [colour]; else it charges from the bottom up in [charge], the rest dim
  final ValueGetter<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 21, size.height / 25);
    final path = Path()
      ..moveTo(13.2, 1)
      ..lineTo(4, 14)
      ..lineTo(10, 14)
      ..lineTo(8, 24)
      ..lineTo(17.4, 10.2)
      ..lineTo(11.4, 10.2)
      ..lineTo(15, 1)
      ..close();
    void draw(Color c) {
      canvas.drawPath(path, Paint()..color = c);
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.8,
      );
    }

    final p = progress?.call();
    if (p == null) {
      draw(colour);
    } else {
      draw(colour.withValues(alpha: .26));
      final filled = boltChargedRows(p, 9) / 9;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 25 * (1 - filled), 21, 25));
      draw(charge);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoltPainter old) =>
      old.colour != colour || old.charge != charge || (old.progress == null) != (progress == null);
}
