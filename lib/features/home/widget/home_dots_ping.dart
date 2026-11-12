part of 'avpn_home_body.dart';

class _DotsStats extends HookConsumerWidget {
  const _DotsStats({
    required this.connected,
    this.paused = false,
    required this.timeText,
    required this.ping,
    required this.loss,
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    this.slim = false,
  });

  final bool connected;

  /// the VPN paused by the service: no ping, no bars, no average (nothing is measured)
  final bool paused;
  final String timeText;
  final int? ping;

  /// the share of packets lost, in percent
  final double loss;
  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final bool slim;

  /// the ping this slow or the loss this heavy turns the figures to the accent: by the network the phone is on (mobile
  /// data is milder)
  static AlertLimits get limits => alertLimits(mobile: _actualNetworkKind.value == NetworkKind.mobile);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = _Dots.ink(dark);
    final live = ref.watch(connectionQualityProvider);
    final kept = useRef<List<int?>>(const []);
    if (connected && !paused && live.isNotEmpty) kept.value = live;
    final samples = paused ? const <int?>[] : (connected ? live : kept.value);
    final answers = [
      for (final s in samples)
        if (s != null) s,
    ];
    final average = answers.isEmpty ? null : (answers.reduce((a, b) => a + b) / answers.length).round();
    final bars = samples.length > 24 ? samples.sublist(samples.length - 24) : samples;
    // from zero to a round number over the highest answer (at least 200 ms), marked at 100, 200, 400: a ping of 40 and
    // one of 100 stand at different heights (the bars were scaled to the highest of them, so any ping filled them)
    // capped at 400 ms: a few timeouts (1500 ms) must not squash every normal answer into a stripe; they run off the top
    final scale = math.min(_niceMax(answers.isEmpty ? 1 : answers.reduce(math.max).toDouble(), least: 200), 400.0);
    final style = ref.watch(Preferences.pingGraph);
    return _dotPaper(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('PING / MS', style: _Dots.mono(11, _Dots.soft(dark), spacing: 2.4)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? _Dots.red : _Dots.soft(dark)),
              ),
              const Gap(6),
              Text(timeText, style: _Dots.mono(12, ink, weight: FontWeight.w800)),
            ],
          ),
          Gap(slim ? 6 : 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: slim ? null : () => unawaited(_pickPingGraph(context, ref, style)),
            child: Center(
              child: _DotNumber(
                connected && !paused && ping != null ? '$ping' : '—',
                cell: slim ? 6 : 10,
                // the ordinary colour; the accent when the ping is very high or the loss is heavy
                colour: connected && !paused && ((ping ?? 0) >= _DotsStats.limits.ping || loss >= _DotsStats.limits.loss)
                    ? _Dots.red
                    : ink,
                faint: _Dots.grid(dark),
              ),
            ),
          ),
          const Gap(8),
          // the average, and in the slim form (no room for the graph under it) the answers run on both sides of it: the
          // older ones on the left, the newer on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (slim) Expanded(child: _slimBars(bars.sublist(0, bars.length ~/ 2), scale, ink, alignEnd: true)),
              if (slim) const Gap(10),
              Text(
                average == null ? ' ' : '${t.avpn.pingAverage.toUpperCase()} $average',
                style: _Dots.mono(11, _Dots.soft(dark), spacing: 3),
              ),
              if (slim) const Gap(10),
              if (slim) Expanded(child: _slimBars(bars.sublist(bars.length ~/ 2), scale, ink, alignEnd: false)),
            ],
          ),
          if (!slim) ...[
            const Gap(10),
            if (style == PingGraph.bars)
              SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PingGridPainter(
                          scale: scale,
                          line: ink.withValues(alpha: .22),
                          text: _Dots.soft(dark),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (i, s) in bars.indexed) ...[
                              if (i > 0) const Gap(3),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: s == null ? 1 : (s / scale).clamp(.04, 1.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      // a lost probe or a slow answer (250 ms and over) in red
                                      color: s == null || s >= 250 ? _Dots.red : ink,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: switch (style) {
                  PingGraph.equalizer => 58.0,
                  PingGraph.ruler => 40.0,
                  PingGraph.trace => 58.0,
                  _ => 52.0,
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PingDotsPainter(
                    style: style,
                    samples: style == PingGraph.heat ? samples : bars,
                    scale: scale,
                    ping: connected ? ping : null,
                    ink: ink,
                    accent: _Dots.red,
                    faint: _Dots.grid(dark),
                    text: _Dots.soft(dark),
                  ),
                ),
              ),
              if (style == PingGraph.ruler && answers.isNotEmpty) ...[
                const Gap(6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MIN ${answers.reduce(math.min)}', style: _Dots.mono(10, _Dots.soft(dark), spacing: 1.5)),
                    Text(
                      'MAX ${answers.reduce(math.max)}',
                      style: _Dots.mono(
                        10,
                        answers.reduce(math.max) >= _DotsStats.limits.ping ? _Dots.red : _Dots.soft(dark),
                        spacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            _dotRule(context),
            // the rows open the traffic (the big ping picks how the answers are drawn)
            for (final row in [
              ('↓ ${t.avpn.superLightDown}', '${down.$1} ${down.$2}'),
              ('↑ ${t.avpn.superLightUp}', '${up.$1} ${up.$2}'),
              ('VPN / ${t.avpn.connDirect}', '${vpn.$1} ${vpn.$2} / ${direct.$1} ${direct.$2}'),
            ])
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.goNamed('traffic'),
                child: _dotRow(context, row.$1, row.$2),
              ),
          ],
        ],
      ),
    );
  }
}

/// The menu of the ways the ping block draws the answers.
Future<void> _pickPingGraph(BuildContext context, WidgetRef ref, PingGraph now) {
  final ru = ref.read(translationsProvider).requireValue.$meta.locale.languageCode == 'ru';
  return showDialog<void>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(ru ? 'Вид задержки' : 'Ping view'),
      children: [
        for (final g in PingGraph.values)
          ListTile(
            dense: true,
            title: Text(ru ? g.ru : g.en),
            trailing: g == now ? const Icon(Icons.check_rounded) : null,
            onTap: () {
              unawaited(ref.read(Preferences.pingGraph.notifier).update(g));
              Navigator.of(dialog).pop();
            },
          ),
      ],
    ),
  );
}

/// The history of the answers in dots: an equalizer, a ruler with a marker, a dotted trace, a grid.
class _PingDotsPainter extends CustomPainter {
  _PingDotsPainter({
    required this.style,
    required this.samples,
    required this.scale,
    required this.ping,
    required this.ink,
    required this.accent,
    required this.faint,
    required this.text,
  });

  final PingGraph style;
  final List<int?> samples;

  /// the top of the equalizer and of the trace, as the bars have it (the ruler's is always 400)
  final double scale;
  final int? ping;
  final Color ink;
  final Color accent;
  final Color faint;
  final Color text;

  static const _top = 400.0;

  void _dot(Canvas canvas, Offset at, double r, Color c) => canvas.drawCircle(at, r, Paint()..color = c);

  bool _slow(int? s) => s == null || s >= 250;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case PingGraph.equalizer:
        const n = 24;
        const rows = 7;
        final shown = samples.length > n ? samples.sublist(samples.length - n) : samples;
        final gw = size.width / n;
        final rh = (size.height - 6) / (rows - 1);
        for (var i = 0; i < n; i++) {
          final has = i < shown.length;
          final s = has ? shown[i] : null;
          final lit = !has ? 0 : (s == null ? rows : (s / (scale / rows)).round().clamp(1, rows));
          for (var r = 0; r < rows; r++) {
            final at = Offset(gw * i + gw / 2, size.height - 3 - r * rh);
            if (r < lit) {
              _dot(canvas, at, 2.4, _slow(s) ? accent : ink);
            } else {
              _dot(canvas, at, 1.0, faint);
            }
          }
        }
      case PingGraph.ruler:
        const n = 48;
        final gw = size.width / n;
        const y = 16.0;
        for (var k = 0; k < n; k++) {
          final v = k / (n - 1) * _top;
          final on = ping != null && v <= ping!;
          final hot = v >= 300;
          _dot(
            canvas,
            Offset(gw * k + gw / 2, y),
            on ? 3 : 1.4,
            on ? (hot ? accent : ink) : (hot ? accent.withValues(alpha: .35) : faint),
          );
        }
        if (ping != null) {
          final mx = gw / 2 + (size.width - gw) * (ping!.clamp(0, 400) / _top);
          canvas.drawPath(
            Path()
              ..moveTo(mx, y - 6)
              ..lineTo(mx - 4.5, y - 14)
              ..lineTo(mx + 4.5, y - 14)
              ..close(),
            Paint()..color = ping! >= 300 ? accent : ink,
          );
        }
        for (final v in const [0, 100, 200, 300, 400]) {
          final tp = TextPainter(
            text: TextSpan(
              text: v == 400 ? '400+' : '$v',
              style: _Dots.mono(8.5, text, weight: FontWeight.w700, spacing: 0),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final x = gw / 2 + (size.width - gw) * (v / _top);
          tp.paint(canvas, Offset((x - tp.width / 2).clamp(0, size.width - tp.width), y + 11));
        }
      case PingGraph.trace:
        const n = 24;
        final shown = samples.length > n ? samples.sublist(samples.length - n) : samples;
        if (shown.isEmpty) return;
        const top = 6.0;
        final base = size.height - 4;
        Offset at(int i) {
          final v = (shown[i] ?? scale).clamp(0, scale) / scale;
          return Offset(size.width * i / (n - 1), base - (base - top) * v);
        }

        canvas.drawLine(
          Offset(0, base - (base - top) * .25),
          Offset(size.width, base - (base - top) * .25),
          Paint()
            ..color = faint
            ..strokeWidth = 1,
        );
        for (var i = 0; i < shown.length - 1; i++) {
          final a = at(i);
          final b = at(i + 1);
          final steps = math.max(2, ((b - a).distance / 5).floor());
          for (var k = 0; k < steps; k++) {
            _dot(canvas, Offset.lerp(a, b, k / steps)!, 1.4, _slow(shown[i]) ? accent : ink);
          }
        }
        for (var i = 0; i < shown.length; i++) {
          _dot(canvas, at(i), _slow(shown[i]) ? 3 : 2.2, _slow(shown[i]) ? accent : ink);
        }
        canvas.drawCircle(
          at(shown.length - 1),
          7,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case PingGraph.heat:
        const cols = 30;
        const rows = 4;
        final shown = samples.length > cols * rows ? samples.sublist(samples.length - cols * rows) : samples;
        final gw = size.width / cols;
        final rh = (size.height - 6) / (rows - 1);
        // the newest at the bottom right: the grid is filled from the end
        final start = cols * rows - shown.length;
        for (var k = 0; k < cols * rows; k++) {
          final at = Offset(gw * (k % cols) + gw / 2, 3 + rh * (k ~/ cols));
          final i = k - start;
          if (i < 0) {
            _dot(canvas, at, 1.0, faint);
            continue;
          }
          final s = shown[i];
          if (_slow(s)) {
            _dot(canvas, at, 3, accent);
          } else {
            // the slower, the brighter and bigger
            final t = (s! / 150).clamp(0.0, 1.0);
            _dot(canvas, at, 1.6 + t, Color.lerp(faint, ink, .35 + .65 * t)!);
          }
        }
      case PingGraph.bars:
        break;
    }
  }

  @override
  bool shouldRepaint(_PingDotsPainter old) =>
      old.style != style ||
      old.ping != ping ||
      old.scale != scale ||
      old.ink != ink ||
      old.accent != accent ||
      !listEquals(old.samples, samples);
}

/// Dots' super light status: the connection time and the two speeds (what comes in, what goes out) on its paper.
class _DotsLightStats extends ConsumerWidget {
  const _DotsLightStats({required this.connected, required this.timeText, required this.down, required this.up});

  final bool connected;
  final String timeText;
  final String down;
  final String up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = _Dots.ink(dark);
    return _dotPaper(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(t.avpn.contrastTime.toUpperCase(), style: _Dots.mono(11, _Dots.soft(dark), spacing: 2.4)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? _Dots.red : _Dots.soft(dark)),
              ),
              const Gap(6),
              Text(timeText, style: _Dots.mono(12, ink, weight: FontWeight.w800)),
            ],
          ),
          _dotRule(context),
          _dotRow(context, '↓ ${t.avpn.superLightDown}', down),
          _dotRow(context, '↑ ${t.avpn.superLightUp}', up),
        ],
      ),
    );
  }
}

/// The marks behind the ping bars: a faint line at 100, 200, 400 ms (as far as the scale goes), its figure at the right.
class _PingGridPainter extends CustomPainter {
  _PingGridPainter({required this.scale, required this.line, required this.text});

  final double scale;
  final Color line;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = size.width - 28;
    for (final mark in const [100, 200, 400, 800]) {
      if (mark > scale) break;
      final y = size.height * (1 - mark / scale);
      canvas.drawLine(
        Offset(0, y),
        Offset(plot, y),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$mark',
          style: _Dots.mono(8.5, text, weight: FontWeight.w700, spacing: 0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(plot + 5, (y - label.height / 2).clamp(0, size.height - label.height)));
    }
  }

  @override
  bool shouldRepaint(_PingGridPainter old) => old.scale != scale || old.line != line || old.text != text;
}

/// A short run of ping answers as bars (the slim form of the Dots ping block puts them on both sides of the figures).
Widget _slimBars(List<int?> samples, double scale, Color ink, {required bool alignEnd}) {
  return SizedBox(
    height: 14,
    child: Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, s) in samples.indexed) ...[
          if (i > 0) const Gap(3),
          SizedBox(
            width: 3,
            height: 14 * (s == null ? 1.0 : (s / scale).clamp(.08, 1.0)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: s == null || s >= 250 ? _Dots.red : ink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
