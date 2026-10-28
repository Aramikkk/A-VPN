part of 'avpn_home_body.dart';

/// The top of a chart's scale: the first round number over [value] (and at least [least]), so the scale stays put
/// while the line moves and the figures at the grid are ones a person reads.
double _niceMax(double value, {double least = 50}) {
  const steps = [50.0, 100.0, 150.0, 200.0, 300.0, 400.0, 500.0, 750.0, 1000.0, 1500.0, 2000.0, 3000.0, 5000.0];
  final need = math.max(value * 1.1, least);
  for (final step in steps) {
    if (step >= need) return step;
  }
  return (need / 1000).ceil() * 1000.0;
}

/// A tile of the home screen's blocks: the same frosted pane as the sites' tiles.
Widget _homeTile(BuildContext context, Widget child, {EdgeInsets padding = const EdgeInsets.all(10), double radius = 18}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
    ),
    child: child,
  );
}

/// A figure with its unit written small after it.
TextSpan _figureSpan(BuildContext context, (String, String) value, {double? size, Color? colour}) {
  final theme = Theme.of(context);
  return TextSpan(
    children: [
      TextSpan(text: value.$1),
      if (value.$2.isNotEmpty)
        TextSpan(
          text: ' ${value.$2}',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ],
    style: size == null ? null : TextStyle(fontSize: size, color: colour),
  );
}

/// The speeds and the traffic of the session as two tiles, in the language of the sites' tiles: a sign on a disc, two
/// figures, and along the bottom edge a bar (the share of the traffic through the VPN).
class _SpeedTrafficRow extends StatelessWidget {
  const _SpeedTrafficRow({
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    required this.vpnShare,
    required this.speedLevel,
  });

  /// how good the speed is, 0 to 1: the water of the speed's tile
  final double speedLevel;

  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final double vpnShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final figure = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget line(IconData icon, Color colour, (String, String) value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colour),
        const Gap(4),
        Text.rich(_figureSpan(context, value), style: figure),
      ],
    );
    final dark = theme.brightness == Brightness.dark;
    Widget tile(IconData sign, Widget a, Widget b, double level) => Expanded(
      child: _homeTile(
        context,
        Stack(
          children: [
            Positioned.fill(child: RepaintBoundary(child: _Water(level: level, colour: accent, dark: dark))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                    child: Icon(sign, size: 17, color: ContrastPalette.ink),
                  ),
                  const Gap(10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [a, const Gap(3), b],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        padding: EdgeInsets.zero,
      ),
    );
    return Row(
      children: [
        tile(
          Icons.swap_vert_rounded,
          line(Icons.south_rounded, accent, down),
          line(Icons.north_rounded, scheme.onSurfaceVariant, up),
          speedLevel,
        ),
        const Gap(6),
        tile(
          Icons.shield_rounded,
          line(Icons.shield_rounded, accent, vpn),
          line(Icons.alt_route_rounded, scheme.onSurfaceVariant, direct),
          vpnShare,
        ),
      ],
    );
  }
}

/// The vessel: a big circle of water for the connection's quality (the ping, the faster the fuller), the time and the
/// loss written in it; the speeds and the traffic under it.
class _VesselStats extends HookConsumerWidget {
  const _VesselStats({
    required this.connected,
    required this.timeText,
    required this.ping,
    required this.loss,
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    required this.vpnShare,
    required this.speedLevel,
  });

  final double speedLevel;
  final bool connected;
  final String timeText;
  final int? ping;
  final double loss;
  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final double vpnShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final dark = theme.brightness == Brightness.dark;
    // the water heads for a new level only when it is 8% or more away (a ping's hair of a change doesn't set it
    // gliding again)
    final heading = useRef<double?>(null);
    final target = connected && ping != null ? _Orb.pingFill(ping!) : 0.0;
    final prior = heading.value;
    if (prior == null || (target - prior).abs() >= .08 || (target == 0) != (prior == 0)) heading.value = target;
    const size = 190.0;
    final ink = ContrastPalette.ink;
    final vessel = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
          border: Border.all(color: accent, width: 2),
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: heading.value),
                    duration: lightDuration(const Duration(milliseconds: 900)),
                    curve: Curves.easeOutCubic,
                    builder: (context, level, _) => level < .005
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: level,
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: dark ? .62 : .78),
                                  border: Border(top: BorderSide(color: accent, width: 1.5)),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: connected && (ping != null && heading.value! > .5) ? ink : scheme.onSurface,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: connected && ping != null ? '$ping' : '—'),
                        if (connected && ping != null)
                          const TextSpan(text: ' ms', style: TextStyle(fontSize: 12, letterSpacing: 0)),
                      ],
                    ),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                      color: connected && (ping != null && heading.value! > .38) ? ink : scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    connected ? t.avpn.dockLoss(loss: _lossText(loss)) : '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: connected && (ping != null && heading.value! > .22) ? ink : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: vessel),
        const Gap(10),
        _SpeedTrafficRow(down: down, up: up, vpn: vpn, direct: direct, vpnShare: vpnShare, speedLevel: speedLevel),
      ],
    );
  }
}

/// The ping's last minute as a soft curve over a faint grid, a glow under it and a bright dot on the latest answer; a
/// lost probe is a dashed red line down to the bottom.
class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.samples,
    required this.line,
    required this.lost,
    required this.grid,
    required this.label,
    this.labelStyle,
    this.shift = 0,
    this.slots = 60,
  });

  /// how far right (in steps, 1 to 0) the points still are from where they settle: a new answer slides the curve one
  /// step to the left instead of jumping
  final double shift;

  /// the room for the answers across the chart (a step is the width over one less)
  final int slots;

  final List<int?> samples;
  final Color line;
  final Color lost;
  final Color grid;
  final Color label;
  final TextStyle? labelStyle;

  static const _labelWidth = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final answered = [for (final s in samples) if (s != null) s];
    final chart = Rect.fromLTRB(0, 8, size.width - _labelWidth, size.height - 6);
    // the scale runs from 0 to a round number over the highest answer (and holds while the line moves), as the router's
    // panel draws its charts
    const low = 0.0;
    final high = _niceMax(answered.isEmpty ? 0 : answered.reduce(math.max).toDouble(), least: 100);
    double y(num ms) => chart.bottom - (ms - low) / (high - low) * chart.height;

    // the grid: three dashed lines with their values at the right
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [high, high / 2]) {
      final yy = y(v);
      for (var x = chart.left; x < chart.right; x += 7) {
        canvas.drawLine(Offset(x, yy), Offset(math.min(x + 3, chart.right), yy), gridPaint);
      }
      final text = TextPainter(
        text: TextSpan(text: v.round().toString(), style: (labelStyle ?? const TextStyle()).copyWith(fontSize: 10, color: label)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(size.width - text.width, yy - text.height / 2));
    }
    if (samples.length < 2) return;
    final step = chart.width / (slots - 1);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(chart.left, 0, chart.right + 6, size.height));

    // the runs of answers between the lost probes, each a smooth curve
    final runs = <List<Offset>>[];
    var current = <Offset>[];
    for (final (i, s) in samples.indexed) {
      final x = chart.right - (samples.length - 1 - i) * step + shift * step;
      if (s == null) {
        if (current.isNotEmpty) runs.add(current);
        current = [];
        final dash = Paint()
          ..color = lost.withValues(alpha: .55)
          ..strokeWidth = 1.5;
        for (var yy = chart.top; yy < chart.bottom; yy += 6) {
          canvas.drawLine(Offset(x, yy), Offset(x, math.min(yy + 3, chart.bottom)), dash);
        }
        continue;
      }
      current.add(Offset(x, y(s)));
    }
    if (current.isNotEmpty) runs.add(current);

    final area = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [line.withValues(alpha: .34), line.withValues(alpha: 0)],
      ).createShader(chart);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final run in runs) {
      if (run.length < 2) {
        canvas.drawCircle(run.first, 2.2, Paint()..color = line);
        continue;
      }
      final path = Path()..moveTo(run.first.dx, run.first.dy);
      for (var k = 1; k < run.length; k++) {
        final a = run[k - 1];
        final b = run[k];
        final mid = (a.dx + b.dx) / 2;
        path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      }
      final filled = Path.from(path)
        ..lineTo(run.last.dx, chart.bottom)
        ..lineTo(run.first.dx, chart.bottom)
        ..close();
      canvas.drawPath(filled, area);
      canvas.drawPath(path, stroke);
    }
    // the latest answer: a dot with a halo
    if (samples.last != null && runs.isNotEmpty) {
      final last = runs.last.last;
      canvas.drawCircle(last, 8, Paint()..color = line.withValues(alpha: .22));
      canvas.drawCircle(last, 4, Paint()..color = line);
      canvas.drawCircle(
        last,
        4,
        Paint()
          ..color = Colors.white.withValues(alpha: .9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      !listEquals(old.samples, samples) || old.line != line || old.grid != grid || old.shift != shift;
}

/// The pulse: the ping as a big figure over its last minute drawn as a curve, the time and the loss as small pills; the
/// speeds and the traffic in two tiles beneath.
class _PulseStats extends HookConsumerWidget {
  const _PulseStats({
    required this.connected,
    required this.timeText,
    required this.ping,
    required this.loss,
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    required this.vpnShare,
    required this.speedLevel,
  });

  final double speedLevel;
  final bool connected;
  final String timeText;
  final int? ping;
  final double loss;
  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final double vpnShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    // the last minute stays (dimmed) while the VPN is down or coming up again, so the block doesn't empty and fill
    // again at a switch of the network
    final live = ref.watch(connectionQualityProvider);
    final lastSamples = useRef<List<int?>>(const []);
    if (connected && live.isNotEmpty) lastSamples.value = live;
    final samples = connected ? live : lastSamples.value;
    final line = AraLook.readableOn(accent, scheme.surface);
    // every new answer slides the curve one step left over 0.8 s (and rests the rest of the three seconds)
    final slide = useAnimationController(duration: const Duration(milliseconds: 800));
    useEffect(() {
      slide.forward(from: 0);
      return null;
    }, [samples.length, samples.isEmpty ? null : samples.last, identityHashCode(samples)]);
    // the time, with no frame round it
    Widget pill(IconData icon, String text, Color colour) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colour),
          const Gap(6),
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _homeTile(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: connected && ping != null ? '$ping' : '—'),
                              if (connected && ping != null)
                                TextSpan(
                                  text: ' ms',
                                  style: TextStyle(
                                    fontSize: 14,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 40,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -2,
                            color: scheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // the time alone (the loss is in the connect panel)
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: pill(Icons.access_time_filled_rounded, timeText, scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const Gap(4),
              SizedBox(
                height: 52,
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: connected ? 1 : .35,
                    child: AnimatedBuilder(
                    animation: slide,
                    builder: (context, _) => CustomPaint(
                      painter: _PulsePainter(
                        samples: samples,
                        line: line,
                        lost: scheme.error,
                        grid: scheme.onSurface.withValues(alpha: .14),
                        label: scheme.onSurfaceVariant,
                        labelStyle: theme.textTheme.labelSmall,
                        shift: 1 - Curves.easeOutCubic.transform(slide.value),
                        slots: ConnectionQuality.length,
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          radius: 22,
        ),
        const Gap(6),
        _SpeedTrafficRow(down: down, up: up, vpn: vpn, direct: direct, vpnShare: vpnShare, speedLevel: speedLevel),
      ],
    );
  }
}

/// The sites the home screen times, with the delay's colour, as the tiles have them: the name, the delay, the level.
class _SiteEntry {
  const _SiteEntry(this.name, this.ms, this.measured, this.colour, this.level);

  final String name;
  final int? ms;
  final bool measured;
  final Color colour;
  final double level;
}

List<_SiteEntry> _siteEntries(WidgetRef ref, ColorScheme scheme) {
  final sites = ref.watch(siteLatencyProvider);
  final shown = ref.watch(homeSitesProvider);
  final installed = ref.watch(installedAppsProvider).valueOrNull ?? const {};
  final grade = siteGrade(ref.watch(ConfigOptions.pingHttps));
  return [
    for (final site in shown)
      () {
        final app = site.key.startsWith('app:') ? installed[site.key.substring(4)] : null;
        final measured = sites.ms.containsKey(site.key);
        final ms = sites.ms[site.key];
        return _SiteEntry(
          app?.name ?? site.name,
          ms,
          measured,
          !measured ? scheme.outlineVariant : _SiteTiles._colour(ms, grade),
          !measured ? 0.0 : (ms == null ? .08 : (1 - ms / grade.scale).clamp(.08, 1.0)),
        );
      }(),
  ];
}

/// The sites as a row of bars: the faster, the taller; the delay over each, the name under it.
class _SiteBars extends ConsumerWidget {
  const _SiteBars();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) return const SizedBox.shrink();
    return _homeTile(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SitesHeader(),
          Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in entries)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: e.colour,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Gap(4),
                  SizedBox(
                    height: 84,
                    width: 18,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: math.max(e.level, .08),
                        child: Container(
                          decoration: BoxDecoration(color: e.colour, borderRadius: BorderRadius.circular(5)),
                        ),
                      ),
                    ),
                  ),
                  const Gap(4),
                  Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
    );
  }
}

/// A site tile's pulse: the delay's last rounds as a soft curve with a glow under it, across the tile's lower half. The
/// rounds sit in fixed places from the right edge (a new one slides the curve left, nothing is stretched), a round with
/// no answer is bridged, and a lone answer is a flat line until there are more.
class _TilePulsePainter extends CustomPainter {
  _TilePulsePainter({required this.history, required this.colour, this.shift = 0});

  final List<int?> history;
  final Color colour;

  /// how far right (in steps, 1 to 0) the points still are from where they settle
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final answered = [for (final h in history) if (h != null) h];
    if (answered.isEmpty) return;
    // from zero to a round number over the highest answer: a steady site is a low even line, a slow one climbs
    const low = 0.0;
    final high = _niceMax(answered.reduce(math.max).toDouble(), least: 150);
    final top = size.height * .6;
    final bottom = size.height * .92;
    double y(num ms) => bottom - (ms - low) / (high - low) * (bottom - top);
    final step = size.width / (SiteHistory.length - 1);
    final points = <Offset>[];
    for (final (i, h) in history.indexed) {
      if (h == null) continue;
      points.add(Offset(size.width - (history.length - 1 - i) * step + shift * step, y(h)));
    }
    if (points.length == 1) {
      points
        ..clear()
        ..addAll([Offset(0, y(answered.first)), Offset(size.width, y(answered.first))]);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colour.withValues(alpha: .17), colour.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top));
    final stroke = Paint()
      ..color = colour.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var k = 1; k < points.length; k++) {
      final a = points[k - 1];
      final b = points[k];
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close(),
      fill,
    );
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TilePulsePainter old) =>
      !listEquals(old.history, history) || old.colour != colour || old.shift != shift;
}
