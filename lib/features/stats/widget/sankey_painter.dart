part of 'traffic_sankey.dart';

typedef _Colours = ({Color vpn, Color direct, Color block, Color app, Color ink, Color soft, Color halo});

class _SankeyPainter extends CustomPainter {
  _SankeyPainter(
    this.model,
    this.c,
    this.value,
    this.family,
    this.brightness,
    this.lit,
    this.headers,
    this.speedValue,
    this.pulse,
    this.look, {
    this.stepped = false,
    this.icons = const {},
  }) : super(repaint: Listenable.merge([pulse, PixelIcons.revision]));

  /// the apps' icons by name (the stepped picture draws them as pixels)
  final Map<String, Uint8List> icons;

  final SankeyLook look;

  /// the thin lines in steps
  final bool stepped;

  /// the pulse's turn, 0..1
  final Animation<double> pulse;

  final List<String> headers;
  final String Function(double)? speedValue;

  final SankeyModel model;
  final _Colours c;
  final String Function(double w) value;
  final String? family;
  final Brightness brightness;
  final Set<SankeyFlow> lit;

  Color _route(ConnectionRoute? r) => _soft(switch (r) {
    ConnectionRoute.vpn => c.vpn,
    ConnectionRoute.direct => c.direct,
    ConnectionRoute.block => c.block,
    null => c.app,
  });

  /// a colour near black on a light page (or near white on a dark one) is drawn lighter: a pure black node and
  /// ribbon looks heavy on a picture of many thin lines
  Color _soft(Color colour) {
    final lum = colour.computeLuminance();
    if (brightness == Brightness.light && lum < .12) return Color.lerp(colour, Colors.white, .5)!;
    if (brightness == Brightness.dark && lum > .85) return Color.lerp(colour, Colors.black, .4)!;
    return colour;
  }

  /// Laid-out labels kept between paints: the names hardly ever change, and laying text out is most of a paint's
  /// cost (the diagram is painted again at every poll). The key holds everything that makes a label look as it does.
  static final _labels = <String, TextPainter>{};

  TextPainter _text(
    String text,
    double width, {
    required bool strong,
    required double size,
    Color? color,
    int lines = 1,
    Paint? foreground,
    bool right = false,
  }) {
    final key =
        '$text|${width.round()}|$size|$strong|$lines|$right|${family ?? ''}|${foreground == null ? (color ?? c.ink).toARGB32() : 'h${foreground.color.toARGB32()}'}';
    final kept = _labels[key];
    if (kept != null) return kept;
    // a long session shows many names: start the keeping over rather than let it grow
    if (_labels.length > 600) _labels.clear();
    return _labels[key] = _build(
      text,
      width,
      strong: strong,
      size: size,
      color: color,
      lines: lines,
      foreground: foreground,
      right: right,
    );
  }

  TextPainter _build(
    String text,
    double width, {
    required bool strong,
    required double size,
    Color? color,
    int lines = 1,
    Paint? foreground,
    bool right = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const ['Emoji'],
          fontSize: size,
          height: 1.15,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          color: foreground == null ? (color ?? c.ink) : null,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: right ? TextAlign.right : TextAlign.left,
      maxLines: lines,
      ellipsis: '…',
    )..layout(minWidth: right ? width : 0, maxWidth: width);
  }

  /// a label with a halo of the card's colour, so it reads over the ribbons
  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double width, {
    bool right = false,
    bool strong = true,
    double size = 11.5,
    Color? color,
    int lines = 1,
    double alpha = 1,
  }) {
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..color = c.halo.withValues(alpha: .9 * alpha);
    final back = _text(text, width, strong: strong, size: size, lines: lines, foreground: halo, right: right);
    final front = _text(
      text,
      width,
      strong: strong,
      size: size,
      color: (color ?? c.ink).withValues(alpha: alpha),
      lines: lines,
      right: right,
    );
    final dx = (right ? at.dx - front.width : at.dx).roundToDouble();
    final dy = at.dy.roundToDouble();
    back.paint(canvas, Offset(dx, dy));
    front.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = SankeyGeometry(size.width, stepped: stepped);
    final xs = g.xs;
    // the columns' names over them, then the picture under
    for (final (i, title) in headers.indexed) {
      if (title.isEmpty) continue;
      final width = stepped
          ? (i == 1 ? (xs[2] - xs[1]) : 120.0)
          : (i == 1 ? (xs[2] - xs[1]) : (i == 0 ? g.labelL : g.labelR + 10));
      final p = _text(title.toUpperCase(), width, strong: true, size: 9.5, color: c.soft);
      if (stepped) {
        // symmetric: the first at the left edge, the last at the right edge, the middle over its bar
        p.paint(
          canvas,
          Offset(
            i == 0
                ? SankeyGeometry.edge
                // the middle one over the middle of the picture, between the two outer bars
                : (i == 1
                      ? (xs[0] + SankeyGeometry.nodeW + xs[2]) / 2 - p.width / 2
                      : size.width - SankeyGeometry.edge - p.width),
            0,
          ),
        );
        continue;
      }
      p.paint(canvas, Offset(i == 0 ? xs[0] - 7 - p.width : (i == 1 ? xs[1] : xs[2]), 0));
    }
    // a long arrow along the top from the first column to the last: the flow goes from the left to the right
    if (look == SankeyLook.thin || look == SankeyLook.dots || stepped) {
      final rail = Paint()
        ..color = c.ink.withValues(alpha: .28)
        ..strokeWidth = 1.5;
      final railY = SankeyGeometry.headerH - 4;
      if (stepped) {
        // Dots, across: a plain line of small dots, no head
        final dot = Paint()..color = c.ink.withValues(alpha: .35);
        for (var x = xs[0]; x < size.width - 6; x += 9) {
          canvas.drawCircle(Offset(x, railY), 1.3, dot);
        }
      } else {
        canvas.drawLine(Offset(xs[0], railY), Offset(size.width - 6, railY), rail);
        canvas.drawPath(
          Path()
            ..moveTo(size.width - 1, railY)
            ..lineTo(size.width - 12, railY - 5)
            ..lineTo(size.width - 12, railY + 5)
            ..close(),
          Paint()..color = c.ink.withValues(alpha: .28),
        );
      }
    }
    canvas.save();
    canvas.translate(0, SankeyGeometry.headerH);
    model.layout(size.height - SankeyGeometry.headerH);
    final picking = lit.isNotEmpty;
    bool on(Set<SankeyFlow> flows) => !picking || flows.any(lit.contains);

    final day = brightness == Brightness.light;
    // the ribbons, thick ones under thin ones
    final links = [...model.links]..sort((a, b) => model.thickness(b).compareTo(model.thickness(a)));
    for (final l in links) {
      final path = g.ribbon(model, l);
      final colour = _route(l.route);
      final bright = on(l.flows);
      // where traffic moves the ribbon is full colour and its brightness swells and ebbs; a still one is pale
      final live = l.flows.any((f) => f.live);
      final moving = live && _movingLink(l);
      final breath = !live ? .2 : (moving ? .85 + .15 * math.sin(pulse.value * 2 * math.pi) : .85);
      final k = (bright ? 1.0 : .22) * breath;
      final xa = xs[l.from.column] + SankeyGeometry.nodeW;
      final xb = xs[l.to.column];
      final from = l.from.route == null ? c.app : colour;
      final th = model.thickness(l);
      final fromY = l.fromY + th / 2;
      final toY = l.toY + th / 2;
      // steps: along to a turn, across, along; the turns of the lines in separate places, so the crossings read
      final turn = (xa + xb) / 2 + (((toY / 9).floor() % 5) - 2) * 7.0;
      final centre = stepped
          ? (Path()
              ..moveTo(xa, fromY)
              ..lineTo(turn, fromY)
              ..lineTo(turn, toY)
              ..lineTo(xb, toY))
          : (Path()
              ..moveTo(xa, fromY)
              ..cubicTo((xa + xb) / 2, fromY, (xa + xb) / 2, toY, xb, toY));
      final shaderBox = Rect.fromLTRB(xa, 0, xb, size.height);
      // Bento and Dots: their own line and head, whatever the picture's look
      if (_lookLine(canvas, centre.computeMetrics().first, colour, live: live, alpha: bright ? 1 : .3, head: moving))
        continue;
      final fill = Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          colors: [
            from.withValues(alpha: (day ? .2 : .26) * k),
            colour.withValues(alpha: (day ? .5 : .58) * k),
          ],
        ).createShader(shaderBox);
      final edge = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = colour.withValues(alpha: (bright ? (live ? .55 : .14) : .1));
      switch (look) {
        case SankeyLook.ribbons:
          canvas.drawPath(path, fill);
          canvas.drawPath(path, edge);
        case SankeyLook.glow:
          if (live && bright) {
            canvas.drawPath(
              path,
              Paint()
                ..isAntiAlias = true
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
                ..color = colour.withValues(alpha: .55 * breath),
            );
          }
          canvas.drawPath(path, fill);
          canvas.drawPath(
            path,
            edge
              ..strokeWidth = live ? 1.3 : .8
              ..color = colour.withValues(alpha: live ? .9 : .12),
          );
        case SankeyLook.steps:
          final mid = ((xa + xb) / 2).roundToDouble();
          final stepped = Path()
            ..moveTo(xa, l.fromY)
            ..lineTo(mid, l.fromY)
            ..lineTo(mid, l.toY)
            ..lineTo(xb, l.toY)
            ..lineTo(xb, l.toY + th)
            ..lineTo(mid, l.toY + th)
            ..lineTo(mid, l.fromY + th)
            ..lineTo(xa, l.fromY + th)
            ..close();
          canvas.drawPath(stepped, fill);
          canvas.drawPath(stepped, edge);
        case SankeyLook.thin || SankeyLook.dots:
          canvas.drawPath(
            centre,
            Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = live ? 2.6 : 1.6
              ..shader = LinearGradient(
                colors: [
                  from.withValues(alpha: (live ? .95 : .35) * (bright ? 1 : .3)),
                  colour.withValues(alpha: (live ? 1 : .35) * (bright ? 1 : .3)),
                ],
              ).createShader(shaderBox),
          );
          final metric = centre.computeMetrics().first;
          if (look == SankeyLook.dots && live && bright) {
            for (var d = 0; d < 3; d++) {
              final at = ((pulse.value + d / 3) % 1.0) * metric.length;
              canvas.drawCircle(metric.getTangentForOffset(at)!.position, 3.2, Paint()..color = colour);
            }
          }
          // an arrowhead pointing the way (to the right), as on the picture from the top to the bottom
          final a1 = metric.getTangentForOffset(metric.length * .62)!.position;
          final a2 = metric.getTangentForOffset(metric.length * .62 + 3)!.position;
          final turn = math.atan2(a2.dy - a1.dy, a2.dx - a1.dx);
          canvas.drawPath(
            Path()
              ..moveTo(a2.dx + 6 * math.cos(turn), a2.dy + 6 * math.sin(turn))
              ..lineTo(a2.dx + 6 * math.cos(turn + 2.5), a2.dy + 6 * math.sin(turn + 2.5))
              ..lineTo(a2.dx + 6 * math.cos(turn - 2.5), a2.dy + 6 * math.sin(turn - 2.5))
              ..close(),
            Paint()..color = colour.withValues(alpha: (live ? 1 : .45) * (bright ? 1 : .3)),
          );
        case SankeyLook.dashed:
          if (live) {
            canvas.drawPath(path, fill);
            canvas.drawPath(path, edge);
          } else {
            // closed: no fill, only the outline, in dashes
            final dash = Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = colour.withValues(alpha: bright ? .6 : .2);
            for (final metric in path.computeMetrics()) {
              for (var at = 0.0; at < metric.length; at += 9) {
                canvas.drawPath(metric.extractPath(at, math.min(at + 5, metric.length)), dash);
              }
            }
          }
      }
    }

    final lastBottom = [-99.0, -99.0, -99.0];
    // some server on the right carries its subscription's badge: all the marks there keep the room for it
    final anyBadge = model.columns[2].any((n) {
      final profile = splitMark(n.label).profile;
      return profile != null && profile >= 0 && profile < profileBadgesNow.length;
    });
    for (final (ci, column) in model.columns.indexed) {
      for (final n in column) {
        final bright = on(n.flows);
        final live = n.flows.any((f) => f.live);
        final alpha = (bright ? 1.0 : .3) * (live ? 1.0 : .32);
        final fill = _route(n.route);
        final top = n.y.roundToDouble();
        final bottom = math.max((n.y + n.h).roundToDouble(), top + 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(xs[ci], top, xs[ci] + SankeyGeometry.nodeW, bottom),
            const Radius.circular(3),
          ),
          Paint()
            ..isAntiAlias = true
            ..color = (ci == 0 ? fill.withValues(alpha: .8) : fill).withValues(alpha: (ci == 0 ? .8 : 1) * alpha),
        );
        // the name over two lines at most, the amount under it where the node is tall; a label only where the one
        // above it is done: thin neighbours would print over each other
        final tall = n.h >= 18;
        final amount = value(n.real);
        // (the stepped picture writes a speed only where something moves: no row of zeros)
        final speedText = stepped && n.speed < 1 ? null : speedValue?.call(n.speed);
        final lines = 1 + (tall && speedText != null && n.h >= 44 ? 1 : 0);
        final width = switch (ci) {
          0 => g.labelL - 9,
          1 => (xs[2] - xs[1]) - SankeyGeometry.nodeW - 6,
          _ => g.labelR - 9,
        };
        final nameStrong = ci != 1;
        final nameSize = ci == 1 ? 10.0 : 11.5;
        // a site is one line (a domain broken in the middle reads badly), an app or a server up to two
        final nameLines = ci == 1 ? 1 : 2;
        // a server of one of several subscriptions: its mark (a coloured circle with the letter) before the name
        final mark = ci == 2 ? splitMark(n.label) : (profile: null, text: n.label);
        final badge = mark.profile != null && mark.profile! >= 0 && mark.profile! < profileBadgesNow.length
            ? profileBadgesNow[mark.profile!]
            : null;
        final nameW = width - (badge == null ? 0 : 15);
        // a server: its flag alone; the direct way and a block: an icon
        final flag = ci == 2 ? flagOnly(mark.text) : null;
        final icon = ci == 2
            ? switch (n.route) {
                ConnectionRoute.direct => Icons.trending_flat_rounded,
                ConnectionRoute.block => Icons.block_rounded,
                _ => null,
              }
            : null;
        final shownName = flag ?? mark.text;
        final shownSize = flag != null ? 17.0 : nameSize;
        final shownLines = flag != null || icon != null ? 1 : nameLines;
        // the stepped (Dots) picture: an app is its icon in pixels, as a server is its flag; the name stays where there
        // is no icon (or it is not ready yet)
        final appIcon = ci == 0 && stepped ? icons[mark.text] : null;
        final appGrid = appIcon == null ? null : PixelIcons.of(mark.text, appIcon);
        final pixelFlag = stepped && flag != null && hasPixelFlag(flag);
        final shield = stepped && ci == 2 && n.route == ConnectionRoute.direct;
        // an icon, a flag or the shield stands alone (the amounts are written in the middle column only)
        // an app with no icon (or not ready yet): a tile with its first letter, in the icon's place and size
        final tile = ci == 0 && stepped && appGrid == null;
        final glyphAlone = appGrid != null || pixelFlag || shield || tile;
        final nameH = appGrid != null || tile
            ? 36.0
            : pixelFlag
            ? 27.0
            : shield
            ? 28.0
            : icon != null
            ? 20.0
            : _text(shownName, nameW, strong: nameStrong, size: shownSize, lines: shownLines, right: ci == 0).height;
        final blockH = nameH + (tall && !glyphAlone ? 13 * lines : 0);
        final labelTop = n.y + n.h / 2 - blockH / 2;
        if (labelTop < lastBottom[ci] + 1) continue;
        lastBottom[ci] = labelTop + blockH;
        final x = switch (ci) {
          0 => xs[0] - 7,
          1 => xs[1] + SankeyGeometry.nodeW + 5,
          // the stepped picture: the same place for every mark on the right (a flag, the shield), badge or none
          _ => xs[2] + SankeyGeometry.nodeW + 7 + (badge == null && !(stepped && anyBadge) ? 0 : 15),
        };
        if (badge != null) {
          final cy = labelTop + nameH / 2;
          final cx = xs[2] + SankeyGeometry.nodeW + 7 + 6;
          canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = badge.colour.withValues(alpha: alpha));
          final letter = _text(badge.letter, 12, strong: true, size: 8.5, color: Colors.white);
          letter.paint(canvas, Offset(cx - letter.width / 2, cy - letter.height / 2));
        }
        if (appGrid != null) {
          // as near its bar as the server's mark is to its own (7 points)
          PixelIcons.paint(canvas, Rect.fromLTWH(x - 36, labelTop, 36, 36), appGrid, alpha: alpha, edge: c.ink);
        } else if (tile) {
          final box = RRect.fromRectAndRadius(Rect.fromLTWH(x - 36, labelTop, 36, 36), const Radius.circular(8));
          canvas.drawRRect(box, Paint()..color = c.ink.withValues(alpha: .1 * alpha));
          canvas.drawRRect(
            box,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = c.ink.withValues(alpha: .3 * alpha),
          );
          final letter = _text(
            mark.text.isEmpty ? '?' : mark.text.substring(0, 1).toUpperCase(),
            36,
            strong: true,
            size: 17,
            color: c.ink.withValues(alpha: alpha),
          );
          letter.paint(canvas, Offset(x - 18 - letter.width / 2, labelTop + 18 - letter.height / 2));
        } else if (shield) {
          // the direct way is the Russian flag in a frame (the frame tells it from a server in Russia); the shield
          // struck out only until the flag is ready
          final centre = Offset(x + 1 + 20, labelTop + nameH / 2);
          if (paintPixelFlag(canvas, directFlag, centre, 40, alpha: alpha)) {
            paintDirectFrame(canvas, centre, 40, _route(n.route).withValues(alpha: alpha));
          } else {
            paintDotShield(
              canvas,
              Rect.fromCenter(center: centre, width: 23, height: 26),
              _route(n.route).withValues(alpha: alpha),
              hollow: true,
              struck: true,
            );
          }
        } else if (icon != null) {
          final glyph = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: 19,
                color: _route(n.route).withValues(alpha: alpha),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          glyph.paint(canvas, Offset(x, labelTop));
        } else if (!(homeLookNow == HomeLayout.dots &&
            flag != null &&
            paintPixelFlag(canvas, flag, Offset(x + 1 + 20, labelTop + nameH / 2), 40, alpha: alpha, dots: stepped))) {
          _label(
            canvas,
            shownName,
            Offset(x, labelTop),
            nameW,
            right: ci == 0,
            strong: nameStrong,
            size: shownSize,
            lines: shownLines,
            alpha: alpha,
          );
        }
        if (tall && !glyphAlone) {
          _label(
            canvas,
            amount,
            Offset(x, labelTop + nameH),
            width,
            right: ci == 0,
            strong: false,
            size: 10.5,
            color: c.soft,
            alpha: alpha,
          );
          if (lines == 2) {
            _label(
              canvas,
              speedText!,
              Offset(x, labelTop + nameH + 13),
              width,
              right: ci == 0,
              strong: false,
              size: 10.5,
              color: c.soft,
              alpha: alpha,
            );
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SankeyPainter old) => true;
}
