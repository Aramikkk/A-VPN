part of 'traffic_sankey.dart';

/// Where the plates stand in the chips view.
class _ChipsLayout {
  static const headerH = 22.0;
  static const pitch = 56.0;
  static const chipH = 46.0;
}

/// The diagram as plates and thin lines: three columns of plates (an app, a site, a server) in rows of one size from
/// the top, each plate with its name, its traffic and its speed; a thin line for each route, a dot on it where the
/// traffic is moving. A tap on a plate or a line picks that route out (the rest dims) and shows its details.
class _ChipsView extends StatelessWidget {
  const _ChipsView({
    required this.model,
    required this.height,
    required this.lit,
    required this.value,
    required this.speedValue,
    required this.headers,
    required this.onNode,
    required this.onLink,
  });

  final SankeyModel model;
  final double height;
  final Set<SankeyFlow> lit;
  final String Function(double w) value;
  final String Function(double bytesPerSecond)? speedValue;
  final List<String> headers;
  final void Function(SankeyNode node)? onNode;
  final void Function(SankeyLink link)? onLink;

  static final _flag = RegExp(r'^([\u{1F1E6}-\u{1F1FF}]{2})\s*', unicode: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final picking = lit.isNotEmpty;
    Color routeColour(ConnectionRoute? r) => switch (r) {
      ConnectionRoute.vpn => accent,
      ConnectionRoute.direct => const Color(0xFF9AA0A6),
      ConnectionRoute.block => scheme.error,
      null => scheme.onSurfaceVariant,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final colW = [w * .285, w * .295, w * .30];
        final xs = [0.0, w * .35, w * .70];
        double top(int i) => _ChipsLayout.headerH + i * _ChipsLayout.pitch;
        final lines = [
          for (final l in model.links)
            (
              link: l,
              from: Offset(
                xs[l.from.column] + colW[l.from.column],
                top(model.columns[l.from.column].indexOf(l.from)) + _ChipsLayout.chipH / 2,
              ),
              to: Offset(xs[l.to.column], top(model.columns[l.to.column].indexOf(l.to)) + _ChipsLayout.chipH / 2),
              moving: l.flows.fold<double>(0, (s, f) => s + f.speed) > 512,
              on: !picking || l.flows.any(lit.contains),
            ),
        ];
        Widget plate(SankeyNode n, int col, int i) {
          final on = !picking || n.flows.any(lit.contains);
          final flag = _flag.firstMatch(n.label);
          final name = flag == null ? n.label : n.label.substring(flag.end);
          final speed = speedValue?.call(n.speed);
          // the speed only where something moves
          final second = speed == null || n.speed < 1 ? value(n.real) : '${value(n.real)} · $speed';
          return Positioned(
            left: xs[col],
            top: top(i),
            width: colW[col],
            height: _ChipsLayout.chipH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNode == null ? null : () => onNode!(n),
              child: AnimatedOpacity(
                opacity: on ? 1 : .35,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: picking && on
                          ? routeColour(n.route ?? ConnectionRoute.vpn).withValues(alpha: .9)
                          : scheme.onSurface.withValues(alpha: .08),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (flag != null) ...[
                        homeLookNow == HomeLayout.dots
                            ? flagMark(flag.group(1), width: 21)
                            : Text(flag.group(1)!, style: const TextStyle(fontSize: 15, fontFamilyFallback: ['Emoji'])),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                fontFamilyFallback: const ['Emoji'],
                              ),
                            ),
                            Text(
                              second,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // a tap on the space between the plates: the line nearest to it, if one is close
            onTapUp: onLink == null
                ? null
                : (d) {
                    SankeyLink? best;
                    var nearest = 14.0;
                    for (final line in lines) {
                      final d2 = _distanceToCurve(d.localPosition, line.from, line.to);
                      if (d2 < nearest) {
                        nearest = d2;
                        best = line.link;
                      }
                    }
                    if (best != null) onLink!(best);
                  },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChipLines(
                      [
                        for (final line in lines)
                          (
                            from: line.from,
                            to: line.to,
                            colour: routeColour(line.link.route),
                            moving: line.moving,
                            on: line.on,
                          ),
                      ],
                      scheme.onSurface,
                      accent,
                    ),
                  ),
                ),
                for (final (i, title) in headers.indexed)
                  if (title.isNotEmpty)
                    Positioned(
                      left: xs[i],
                      top: 0,
                      width: colW[i],
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                for (final (col, column) in model.columns.indexed)
                  for (final (i, n) in column.indexed) plate(n, col, i),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The line between two plates as a curve (the same one the painter draws): the nearest it comes to [at].
double _distanceToCurve(Offset at, Offset from, Offset to) {
  final mid = (from.dx + to.dx) / 2;
  var best = double.infinity;
  for (var i = 0; i <= 24; i++) {
    final t = i / 24;
    final u = 1 - t;
    final x = u * u * u * from.dx + 3 * u * u * t * mid + 3 * u * t * t * mid + t * t * t * to.dx;
    final y = u * u * u * from.dy + 3 * u * u * t * from.dy + 3 * u * t * t * to.dy + t * t * t * to.dy;
    best = math.min(best, (Offset(x, y) - at).distance);
  }
  return best;
}

typedef _ChipLine = ({Offset from, Offset to, Color colour, bool moving, bool on});

class _ChipLines extends CustomPainter {
  _ChipLines(this.lines, this.ink, this.accent);

  final List<_ChipLine> lines;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // the dimmed ones first, so a picked route lies over them
    final ordered = [...lines]..sort((a, b) => (a.on ? 1 : 0).compareTo(b.on ? 1 : 0));
    for (final l in ordered) {
      final mid = (l.from.dx + l.to.dx) / 2;
      final path = Path()
        ..moveTo(l.from.dx, l.from.dy)
        ..cubicTo(mid, l.from.dy, mid, l.to.dy, l.to.dx, l.to.dy);
      final base = l.moving ? l.colour : ink;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round
          ..color = base.withValues(alpha: l.on ? (l.moving ? .85 : .3) : .1),
      );
      if (l.moving && l.on) {
        final metric = path.computeMetrics().first;
        canvas.drawCircle(metric.getTangentForOffset(metric.length * .5)!.position, 3, Paint()..color = l.colour);
      }
    }
  }

  @override
  bool shouldRepaint(_ChipLines old) => true;
}

/// The picture from the top to the bottom, for a narrow screen (the folded phone): the apps in a row at the top (their
/// icons), the sites in a row in the middle (their names written upright), the servers in a row at the bottom (their
/// flags); a thin line for each route with an arrowhead pointing down, and dots running down the ones in use.
/// A flow's line in a look that has its own, with its head [at] the share of the way: Dots a row of dots (bigger ones
/// for a flow in use) and a small square head; Bento a thick round line and a round head. False for the other looks
/// (the caller draws its own line).
bool _lookLine(
  Canvas canvas,
  ui.PathMetric metric,
  Color colour, {
  required bool live,
  required double alpha,
  double at = .62,

  /// the head (a square or a disc) is drawn only where traffic is moving; a connection standing idle shows its line
  /// alone
  bool head = true,
}) {
  switch (homeLookNow) {
    case HomeLayout.dots when solidDotsLines:
      // Mono and Grotesk: a solid round line (the heavier for a flow in use), as thick as the figures' style is
      canvas.drawPath(
        metric.extractPath(0, metric.length),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = live ? solidLineWidth(mono: 2.4, wide: 4.6) : solidLineWidth(mono: 1.6, wide: 3)
          ..color = colour.withValues(alpha: (live ? 1 : .45) * alpha),
      );
      return true;
    case HomeLayout.dots:
      // the dots in one call, their places kept for the line (it is drawn at every frame while the dots run)
      canvas.drawPoints(
        ui.PointMode.points,
        _dotsAlong(metric),
        Paint()
          ..color = colour.withValues(alpha: (live ? 1 : .45) * alpha)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = live ? 3.2 : 2.2,
      );
      // no fixed head on a Dots line: only the squares that run along the ones in use show where the traffic goes
      return true;
    case HomeLayout.bento:
      final path = metric.extractPath(0, metric.length);
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = live ? 5 : 2.6
          ..color = colour.withValues(alpha: (live ? 1 : .35) * alpha),
      );
      if (head) {
        final headAt = metric.getTangentForOffset(metric.length * at)!.position;
        canvas.drawCircle(headAt, live ? 5.5 : 4, Paint()..color = colour.withValues(alpha: (live ? 1 : .55) * alpha));
        if (live) canvas.drawCircle(headAt, 2, Paint()..color = Colors.white.withValues(alpha: .9 * alpha));
      }
      return true;
    default:
      return false;
  }
}

/// The places of the dots along a line, every 6 points; kept by the line's ends and length (the same line at every
/// frame gives the same list instead of sampling it again).
final _dotPlaces = <String, List<Offset>>{};

List<Offset> _dotsAlong(ui.PathMetric metric) {
  final a = metric.getTangentForOffset(0)!.position;
  final b = metric.getTangentForOffset(metric.length)!.position;
  final key = '${a.dx.round()},${a.dy.round()},${b.dx.round()},${b.dy.round()},${metric.length.round()}';
  final kept = _dotPlaces[key];
  if (kept != null) return kept;
  if (_dotPlaces.length > 600) _dotPlaces.clear();
  return _dotPlaces[key] = [for (var d = 0.0; d < metric.length; d += 6) metric.getTangentForOffset(d)!.position];
}
