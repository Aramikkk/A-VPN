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
      border: highlight ? Border.all(color: _Dots.red, width: 2) : Border.all(color: _Dots.ink(dark).withValues(alpha: .28)),
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

/// A number drawn as a 5×7 matrix of dots for each figure: the lit dots in the ink, the rest faint.
class _DotNumber extends StatelessWidget {
  const _DotNumber(this.text, {required this.cell, required this.colour, required this.faint});

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
    // the best-server button's sign: a lightning bolt, in the same dots as the figures
    // (nine rows, seven columns: chunky, reads as a bolt even small)
    '⚡': ['0000111', '0001110', '0011100', '0111000', '1111111', '0001110', '0011100', '0111000', '0110000'],
  };

  /// the columns a glyph takes with the gap after it
  static int advance(String c) => _glyphs[c]![0].length + 1;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('').where(_glyphs.containsKey).toList();
    final width = chars.isEmpty ? 0.0 : (chars.fold<int>(0, (n, c) => n + advance(c)) - 1) * cell;
    // the figures are seven rows high, the bolt nine
    final rows = chars.fold<int>(7, (n, c) => math.max(n, _glyphs[c]!.length));
    return CustomPaint(
      size: Size(width, rows * cell),
      painter: _DotNumberPainter(chars: chars, cell: cell, colour: colour, faint: faint),
    );
  }
}

/// How many rows of the bolt are charged at [progress] (0 to 1) of a charge: from the bottom up, the last part of the
/// cycle all of them (the flash), then it starts over.
int boltChargedRows(double progress, int rows) => (progress.clamp(0.0, 1.0) * (rows + 2)).floor().clamp(0, rows);

/// The bolt of the best-server button in dots. [progress] null: at rest, all lit in [colour]. Otherwise it charges: the
/// rows charged so far in [charge], the rest of the bolt dim.
class _DotBoltPainter extends CustomPainter {
  _DotBoltPainter({
    required this.cell,
    required this.colour,
    required this.charge,
    required this.faint,
    this.progress,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final double cell;
  final Color colour;
  final Color charge;
  final Color faint;
  final ValueGetter<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = _DotNumber._glyphs['⚡']!;
    final lit = Paint()..color = colour;
    final charged = Paint()..color = charge;
    final dim = Paint()..color = colour.withValues(alpha: .26);
    final off = Paint()..color = faint;
    final r = cell * .42;
    final p = progress?.call();
    final filled = p == null ? rows.length : boltChargedRows(p, rows.length);
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final centre = Offset((x + .5) * cell, (y + .5) * cell);
        if (rows[y][x] != '1') {
          canvas.drawCircle(centre, r * .45, off);
          continue;
        }
        final fromBottom = rows.length - 1 - y;
        canvas.drawCircle(centre, r, p == null ? lit : (fromBottom < filled ? charged : dim));
      }
    }
  }

  @override
  bool shouldRepaint(_DotBoltPainter old) =>
      old.cell != cell ||
      old.colour != colour ||
      old.charge != charge ||
      old.faint != faint ||
      (old.progress == null) != (progress == null);
}

class _DotNumberPainter extends CustomPainter {
  _DotNumberPainter({required this.chars, required this.cell, required this.colour, required this.faint});

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
          canvas.drawCircle(centre, rows[y][x] == '1' ? r : r * .45, rows[y][x] == '1' ? on : off);
        }
      }
      column += _DotNumber.advance(c);
    }
  }

  @override
  bool shouldRepaint(_DotNumberPainter old) =>
      old.chars.join() != chars.join() || old.cell != cell || old.colour != colour || old.faint != faint;
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
          _centeredServer(
            // both sides the same width, so the middle is the row's own middle (the bolt and the ping's dots are not as wide)
            // (the bolt's own dots start a little inside its box: it is moved out, for the same margin on both sides)
            lead: SizedBox(
              width: 64,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(offset: const Offset(-8, 0), child: lead),
              ),
            ),
            reserve: 70,
            // the country's name is in the middle, between the bolt and the ping, the flag beside it on the left: the
            // two sides take the same room (the name has five parts of nine), so the name is the row's own middle
            center: LayoutBuilder(
              builder: (context, box) {
                // the name is as wide as its text, at most what is left beside the flag's room on each side: it is in the middle of
                // the row (the two sides are as wide), the flag right against it on its left
                final nameRoom = math.max(60.0, box.maxWidth - 2 * (46 + 10));
                return Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        // a little lower: level with the middle of the two lines beside it
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10, top: 5),
                          child: group
                              ? SizedBox(width: 46, child: Icon(Icons.auto_awesome_rounded, size: 30, color: ink))
                              : flagMark(flag, width: 46),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: nameRoom),
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
                    const Expanded(child: SizedBox()),
                  ],
                );
              },
            ),
            trailing: SizedBox(
              width: 64,
              child: Align(
                alignment: Alignment.centerRight,
                child: testing
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                    : _DotNumber(ms == '×' ? '—' : ms, cell: 4, colour: ink, faint: _Dots.grid(dark)),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
