part of 'traffic_sankey.dart';

class _TopDownPainter extends CustomPainter {
  _TopDownPainter({
    required this.model,
    required this.accent,
    required this.ink,
    required this.error,
    required this.family,
    required this.pulse,
    required this.icons,
    required this.lit,
    required this.halo,
    required this.names,
    this.dots = false,
  }) : super(repaint: dots ? pulse : null);

  /// only the running dots (the layer drawn at every frame); else only the still picture under them
  final bool dots;

  final SankeyModel model;
  final Color accent;
  final Color ink;
  final Color error;
  final String? family;
  final ValueListenable<double> pulse;
  final Map<String, ui.Image> icons;
  final Set<SankeyFlow> lit;

  /// the card's colour, drawn round the site names so the lines don't cut through them
  final Color halo;

  /// the lines as paths, built once for a size: a repaint only draws them (the dots run along the kept metrics)
  List<({SankeyLink link, bool live, Path path, ui.PathMetric metric, Path head, Color colour})>? _geo;
  Size? _geoSize;

  /// the apps written by name (a wide screen) rather than as icons
  final bool names;

  static const left = 22.0;
  static const right = 12.0;
  static const direct = Color(0xFF9AA0A6);
  static final _labels = <String, TextPainter>{};

  /// the rows' tops: the apps' bars, the sites', the servers'
  static List<double> rows(double height) {
    final bottom = height - 62;
    return [54, 54 + (bottom - 54) * .5, bottom];
  }

  static double laneWidth(double width) => width - left - right;

  static double barX(SankeyNode n) => left + n.y;

  static double centreX(SankeyNode n) => left + n.y + math.max(n.h, 4) / 2;

  Color colourOf(ConnectionRoute? route) => switch (route) {
    ConnectionRoute.direct => direct,
    ConnectionRoute.block => error,
    _ => accent,
  };

  TextPainter _text(String text, double size, Color colour, {bool bold = false, double width = 100}) {
    final key = '$text|$size|${colour.toARGB32()}|$bold|${width.round()}|${family ?? ''}';
    final kept = _labels[key];
    if (kept != null) return kept;
    if (_labels.length > 500) _labels.clear();
    return _labels[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const ['Emoji'],
          fontSize: size,
          color: colour,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
  }

  /// The layout and the lines' paths for [size]: done once, not at every repaint.
  void _prepare(Size size, List<double> rowY) {
    model.layout(laneWidth(size.width), spread: true);
    final links = [...model.links]
      ..sort((a, b) => (a.flows.any((f) => f.live) ? 1 : 0).compareTo(b.flows.any((f) => f.live) ? 1 : 0));
    _geo = [
      for (final l in links)
        () {
          final pts = curve(model, l, rowY);
          final path = Path()
            ..moveTo(pts[0].dx, pts[0].dy)
            ..cubicTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy, pts[3].dx, pts[3].dy);
          final metric = path.computeMetrics().first;
          final p1 = metric.getTangentForOffset(metric.length * .62)!.position;
          final p2 = metric.getTangentForOffset(metric.length * .62 + 3)!.position;
          final ang = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
          final head = Path()
            ..moveTo(p2.dx + 6 * math.cos(ang), p2.dy + 6 * math.sin(ang))
            ..lineTo(p2.dx + 6 * math.cos(ang + 2.5), p2.dy + 6 * math.sin(ang + 2.5))
            ..lineTo(p2.dx + 6 * math.cos(ang - 2.5), p2.dy + 6 * math.sin(ang - 2.5))
            ..close();
          return (
            link: l,
            live: l.flows.any((f) => f.live),
            path: path,
            metric: metric,
            head: head,
            colour: colourOf(l.route),
          );
        }(),
    ];
    _geoSize = size;
  }

  /// a site's name short: no "www."
  static String shortSite(String name) => name.startsWith('www.') ? name.substring(4) : name;

  bool _moving(SankeyLink l) => l.flows.fold<double>(0, (s, f) => s + f.speed) > 512;

  /// a link's line from one row to the next: its ends and its two control points
  static List<Offset> curve(SankeyModel model, SankeyLink l, List<double> rowY) {
    final th = model.thickness(l);
    final y0 = rowY[l.from.column] + 6;
    final y1 = rowY[l.to.column];
    final x0 = left + l.fromY + th / 2;
    final x1 = left + l.toY + th / 2;
    return [Offset(x0, y0), Offset(x0, (y0 + y1) / 2), Offset(x1, (y0 + y1) / 2), Offset(x1, y1)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rowY = rows(size.height);
    if (_geoSize != size || _geo == null) _prepare(size, rowY);
    if (!dots) {
      _paintStill(canvas, size, rowY);
      return;
    }
    // the dots running down the ones in use
    final picking = lit.isNotEmpty;
    for (final g in _geo!) {
      final l = g.link;
      if (!g.live || (picking && !l.flows.any(lit.contains)) || !_moving(l)) continue;
      final dot = Paint()..color = g.colour;
      for (var d = 0; d < 3; d++) {
        final at = ((pulse.value + d / 3) % 1.0) * g.metric.length;
        final p = g.metric.getTangentForOffset(at)!.position;
        switch (homeLookNow) {
          case HomeLayout.dots:
            canvas.drawRect(Rect.fromCenter(center: p, width: 6, height: 6), dot);
          case HomeLayout.bento:
            canvas.drawCircle(p, 3.5, dot);
          default:
            canvas.drawCircle(p, 3, dot);
        }
      }
    }
  }

  void _paintStill(Canvas canvas, Size size, List<double> rowY) {
    final picking = lit.isNotEmpty;
    bool on(Set<SankeyFlow> flows) => !picking || flows.any(lit.contains);

    // the rows' names on the right, small
    for (final (i, title) in const ['', '', ''].indexed) {
      if (title.isEmpty) continue;
      final p = _text(title, 9.5, ink.withValues(alpha: .5), bold: true);
      p.paint(canvas, Offset(size.width - right - p.width, rowY[i] + 8));
    }

    for (final g in _geo!) {
      final l = g.link;
      final live = g.live;
      final bright = on(l.flows);
      final colour = g.colour;
      final k = bright ? 1.0 : .25;
      // Bento and Dots: their own line and head
      if (_lookLine(canvas, g.metric, colour, live: live, alpha: k, head: live && _moving(l))) continue;
      canvas.drawPath(
        g.path,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = live ? 2.6 : 1.5
          ..color = colour.withValues(alpha: (live ? 1 : .32) * k),
      );
      // an arrowhead pointing down the way
      canvas.drawPath(g.head, Paint()..color = colour.withValues(alpha: (live ? 1 : .45) * k));
    }

    for (final (ci, column) in model.columns.indexed) {
      for (final n in column) {
        final live = n.flows.any((f) => f.live);
        final alpha = (on(n.flows) ? 1.0 : .3) * (live ? 1.0 : .38);
        final x = barX(n);
        final w = math.max(n.h, 4.0);
        final cx = x + w / 2;
        final colour = ci == 0 ? direct : colourOf(n.route);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, rowY[ci], w, 6), const Radius.circular(3)),
          Paint()..color = colour.withValues(alpha: alpha),
        );
        final label = n.label.replaceAll('\u200b', '');
        if (ci == 0) {
          if (names) {
            _appName(canvas, label, cx, rowY[0] - 8, alpha, laneWidth(size.width) / column.length - 4, size.width);
          } else {
            _icon(canvas, n, Offset(cx, rowY[0] - 22), alpha);
          }
        } else if (ci == 1) {
          // the site's name written upright above its bar
          final name = shortSite(n.label);
          final back = TextPainter(
            text: TextSpan(
              text: name,
              style: TextStyle(
                fontFamily: family,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4
                  ..strokeJoin = StrokeJoin.round
                  ..color = halo.withValues(alpha: .92),
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: 108);
          final p = TextPainter(
            text: TextSpan(
              text: name,
              style: TextStyle(
                fontFamily: family,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: math.max(alpha, .5)),
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: 108);
          canvas
            ..save()
            ..translate(cx - p.height / 2, rowY[1] - 8)
            ..rotate(-math.pi / 2);
          back.paint(canvas, Offset.zero);
          p.paint(canvas, Offset.zero);
          canvas.restore();
        } else {
          final flag = flagOnly(label);
          // the direct way: a crossed shield (the VPN's shield, struck out); a block: its own sign
          final direct = n.route == ConnectionRoute.direct;
          final icon = n.route == ConnectionRoute.block ? Icons.block_rounded : null;
          final top = rowY[2] + 12;
          if (direct) {
            _shieldOff(canvas, Offset(cx, top + 11), colourOf(n.route).withValues(alpha: alpha));
          } else if (icon != null) {
            final glyph = TextPainter(
              text: TextSpan(
                text: String.fromCharCode(icon.codePoint),
                style: TextStyle(
                  fontFamily: icon.fontFamily,
                  package: icon.fontPackage,
                  fontSize: 20,
                  color: colourOf(n.route).withValues(alpha: alpha),
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            glyph.paint(canvas, Offset(cx - glyph.width / 2, top));
          } else {
            final p = _text(
              flag ?? label,
              flag != null ? 20 : 11,
              ink.withValues(alpha: alpha),
              bold: flag == null,
              width: 70,
            );
            // Dots: the flag in pixels, its middle where the shield's is
            final pixel =
                homeLookNow == HomeLayout.dots &&
                flag != null &&
                paintPixelFlag(canvas, flag, Offset(cx, top + 11), 30, alpha: alpha);
            if (!pixel) p.paint(canvas, Offset(cx - p.width / 2, top));
            final frameW = pixel ? 30.0 : p.width;
            final frameH = pixel ? 20.0 : p.height;
            final frameTop = pixel ? top + 1 : top;
            // a whitelist ("БС", LTE only) server: a faint square frame round its flag, to tell it from the others
            if (flag != null && ServerRegionFilter.isMobileOnly(label)) {
              canvas.drawRect(
                Rect.fromLTWH(cx - frameW / 2 - 4, frameTop - 2, frameW + 8, frameH + 4),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1
                  ..color = ink.withValues(alpha: .38 * alpha),
              );
            }
            // the subscription's mark under the flag
            final mark = splitMark(n.label);
            final badge = mark.profile != null && mark.profile! >= 0 && mark.profile! < profileBadgesNow.length
                ? profileBadgesNow[mark.profile!]
                : null;
            if (badge != null) {
              final by = top + (pixel ? 22.0 : p.height) + 8;
              canvas.drawCircle(Offset(cx, by), 6, Paint()..color = badge.colour.withValues(alpha: alpha));
              final letter = _text(badge.letter, 8.5, Colors.white.withValues(alpha: alpha), bold: true, width: 12);
              letter.paint(canvas, Offset(cx - letter.width / 2, by - letter.height / 2));
            }
          }
        }
      }
    }
  }

  /// an app's name over its bar (up to two lines, centred), with the halo
  void _appName(Canvas canvas, String name, double cx, double bottom, double alpha, double width, double canvasWidth) {
    final w = math.max(width, 56.0);
    TextPainter make(TextStyle style) => TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(minWidth: w, maxWidth: w);
    final back = make(
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.1,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..color = halo.withValues(alpha: .92),
      ),
    );
    final front = make(
      TextStyle(
        fontFamily: family,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: ink.withValues(alpha: math.max(alpha, .5)),
      ),
    );
    // kept inside the picture: a name at either end doesn't run out of it
    final at = Offset((cx - w / 2).clamp(0.0, math.max(0.0, canvasWidth - w)), bottom - front.height);
    back.paint(canvas, at);
    front.paint(canvas, at);
  }

  /// an app's icon in a disc, or its first letter where the icon isn't known
  void _icon(Canvas canvas, SankeyNode n, Offset centre, double alpha) {
    const r = 12.0;
    // the "other" node: a grey disc with three dots, not a letter
    if (n.key.endsWith('|')) {
      canvas.drawCircle(centre, r, Paint()..color = const Color(0xFF8A9099).withValues(alpha: alpha));
      final dots = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.more_horiz_rounded.codePoint),
          style: TextStyle(
            fontFamily: Icons.more_horiz_rounded.fontFamily,
            package: Icons.more_horiz_rounded.fontPackage,
            fontSize: 17,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dots.paint(canvas, Offset(centre.dx - dots.width / 2, centre.dy - dots.height / 2));
      return;
    }
    final image = icons[n.label];
    if (image != null) {
      canvas
        ..save()
        ..clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCircle(center: centre, radius: r),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.restore();
      return;
    }
    // no icon known (a system service, mostly): a neutral disc with the robot, not a letter
    canvas.drawCircle(centre, r, Paint()..color = const Color(0xFF59606B).withValues(alpha: alpha));
    final robot = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.android_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.android_rounded.fontFamily,
          package: Icons.android_rounded.fontPackage,
          fontSize: 16,
          color: Colors.white.withValues(alpha: .85 * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    robot.paint(canvas, Offset(centre.dx - robot.width / 2, centre.dy - robot.height / 2));
  }

  @override
  bool shouldRepaint(_TopDownPainter old) => true;
}

/// An animation's value, passed on at most once in [gap]: what repaints with it repaints that seldom.
class _SlowPulse extends ChangeNotifier implements ValueListenable<double> {
  _SlowPulse(this._source, this.gap) {
    _source.addListener(_tick);
  }

  final Animation<double> _source;
  final Duration gap;
  final _clock = Stopwatch()..start();
  int _last = -1000;

  void _tick() {
    final now = _clock.elapsedMilliseconds;
    if (now - _last < gap.inMilliseconds) return;
    _last = now;
    notifyListeners();
  }

  @override
  double get value => _source.value;

  @override
  void dispose() {
    _source.removeListener(_tick);
    super.dispose();
  }
}

/// A shield with a stroke across it (26 by 22 round [centre]): traffic that goes without the VPN.
void _shieldOff(Canvas canvas, Offset centre, Color colour) {
  // Dots: the shield of dots with nothing in it (only its edge), struck out by a line of dots
  if (homeLookNow == HomeLayout.dots) {
    paintDotShield(canvas, Rect.fromCenter(center: centre, width: 20, height: 23), colour, hollow: true, struck: true);
    return;
  }
  const w = 26.0;
  const h = 22.0;
  final left = centre.dx - w / 2;
  final top = centre.dy - h / 2;
  final pen = Paint()
    ..color = colour
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final shield = Path()
    ..moveTo(left + w / 2, top + 1)
    ..lineTo(left + w - 3, top + 5)
    ..lineTo(left + w - 3, top + h * .5)
    ..quadraticBezierTo(left + w - 4, top + h - 4, left + w / 2, top + h - 1)
    ..quadraticBezierTo(left + 4, top + h - 4, left + 3, top + h * .5)
    ..lineTo(left + 3, top + 5)
    ..close();
  canvas.drawPath(shield, pen);
  canvas.drawLine(Offset(left + 2, top + h - 2), Offset(left + w - 2, top + 2), pen..strokeWidth = 2.2);
}
