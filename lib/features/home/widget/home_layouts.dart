part of 'avpn_home_body.dart';

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

/// The speeds and the traffic of the session as two small tiles: in and out, and the share through the VPN.
class _SpeedTrafficRow extends StatelessWidget {
  const _SpeedTrafficRow({required this.down, required this.up, required this.vpn, required this.direct, required this.vpnShare});

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
    return Row(
      children: [
        Expanded(
          child: _homeTile(
            context,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.south_rounded, size: 18, color: accent),
                const Gap(3),
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text.rich(_figureSpan(context, down), style: figure)),
                ),
                const Gap(8),
                Icon(Icons.north_rounded, size: 18, color: scheme.onSurfaceVariant),
                const Gap(3),
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text.rich(_figureSpan(context, up), style: figure)),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
        ),
        const Gap(6),
        Expanded(
          child: _homeTile(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, size: 16, color: accent),
                    const Gap(3),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(_figureSpan(context, vpn), style: figure),
                      ),
                    ),
                    const Gap(8),
                    Icon(Icons.alt_route_rounded, size: 16, color: scheme.onSurfaceVariant),
                    const Gap(3),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(_figureSpan(context, direct), style: figure),
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: vpnShare.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: accent,
                    backgroundColor: scheme.onSurface.withValues(alpha: .1),
                  ),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
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
  });

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
        _SpeedTrafficRow(down: down, up: up, vpn: vpn, direct: direct, vpnShare: vpnShare),
      ],
    );
  }
}

/// The ping's last minute as a line: gaps where a probe was lost.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.samples, required this.line, required this.lost, required this.track});

  final List<int?> samples;
  final Color line;
  final Color lost;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final answered = [for (final s in samples) if (s != null) s];
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), Paint()..color = track);
    if (samples.length < 2 || answered.isEmpty) return;
    final low = answered.reduce(math.min).toDouble();
    final high = math.max(answered.reduce(math.max).toDouble(), low + 40);
    double y(int ms) => size.height - 4 - (ms - low) / (high - low) * (size.height - 10);
    final step = size.width / (samples.length - 1);
    final path = Path();
    var open = false;
    for (final (i, s) in samples.indexed) {
      final x = i * step;
      if (s == null) {
        open = false;
        canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height - 1), Paint()..color = lost..strokeWidth = 2);
        continue;
      }
      if (open) {
        path.lineTo(x, y(s));
      } else {
        path.moveTo(x, y(s));
        open = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => !listEquals(old.samples, samples) || old.line != line;
}

/// The pulse: the ping as a figure and its last minute as a line, the time and the loss under them; the speeds and the
/// traffic in two tiles beneath.
class _PulseStats extends ConsumerWidget {
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
  });

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
    final samples = connected ? ref.watch(connectionQualityProvider) : const <int?>[];
    final line = AraLook.readableOn(accent, scheme.surface);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _homeTile(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: connected && ping != null ? '$ping' : '—'),
                        if (connected && ping != null)
                          TextSpan(
                            text: ' ms',
                            style: TextStyle(fontSize: 12, letterSpacing: 0, color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1.5,
                      color: scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    child: SizedBox(
                      height: 96,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            samples: samples,
                            line: line,
                            lost: scheme.error,
                            track: scheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(6),
              Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const Gap(4),
                  Text(
                    timeText,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    connected ? t.avpn.dockLoss(loss: _lossText(loss)) : '',
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        ),
        const Gap(6),
        _SpeedTrafficRow(down: down, up: up, vpn: vpn, direct: direct, vpnShare: vpnShare),
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
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
    );
  }
}

/// The sites as chips: a dot of the delay's colour, the delay and the name.
class _SiteChips extends ConsumerWidget {
  const _SiteChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in entries)
          _homeTile(
            context,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: e.colour, shape: BoxShape.circle),
                ),
                const Gap(6),
                Text(
                  !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: e.colour,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Gap(5),
                Text(e.name, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            radius: 14,
          ),
      ],
    );
  }
}

/// The connections as a small flow diagram, the same as on the Topology tab: who goes where, as thick as their count.
class _RouteMini extends ConsumerWidget {
  const _RouteMini();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = [
      for (final c in ref.watch(connectionsProvider).items)
        if (c.active) c,
    ];
    if (open.isEmpty) return const Center(child: TrafficPlaceholder(height: 60));
    return LayoutBuilder(
      builder: (context, box) => TrafficSankey(
        items: open,
        height: box.maxHeight.isFinite ? box.maxHeight : 220,
        unit: 1,
        weight: (c) => c.count.toDouble(),
        value: (w) => '${w.round()}',
      ),
    );
  }
}
