part of 'side_bar_stats_overview.dart';

/// Ping through the VPN and packet loss over the last minute: the values, and a bar per probe (lost ones red).
class _QualityCard extends ConsumerWidget {
  const _QualityCard({required this.samples, this.compact = false, this.range = StatsRange.minute, this.fill = false});

  /// the bars take the height the card is given (beside the speed block on the unfolded phone)
  final bool fill;

  final List<int?> samples;

  /// the period the ping and loss are for (the Statistics tab's choice)
  final StatsRange range;

  /// the sidebar's smaller version, without the caption under the bars
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // the last minute probe by probe; a longer period from the saved history
    final period = range == StatsRange.minute ? null : ref.read(connectionQualityProvider.notifier).period(range);
    final bars = period?.bars ?? samples;
    final losses = period?.losses ?? [for (final s in samples) s == null ? 1.0 : 0.0];
    final lostColor = _isRed(theme.araLook.pingColors.first) ? scheme.onSurface : scheme.error;
    final tiny = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: compact ? 10 : 12.5,
      fontWeight: FontWeight.w800,
    );
    // a half's name: which way its bars go, the word, in the half's colour
    Widget halfLabel(IconData arrow, String text, Color colour) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(arrow, size: compact ? 11 : 14, color: colour),
        const SizedBox(width: 2),
        Text(text, style: tiny?.copyWith(color: colour)),
      ],
    );
    final summary = period == null
        ? summarize(samples)
        : (
            ping: period.total.average,
            loss: period.total.sent == 0 ? null : period.total.lost * 100 / period.total.sent,
          );
    final spread = period == null
        ? pingSpread(samples)
        : period.total.average == null
        ? null
        : (avg: period.total.average!, min: period.total.min, max: period.total.max, jitter: -1);
    final loss = summary.loss;
    final lossColor = loss == null || loss == 0
        ? theme.araLook.fastPing
        : (loss < 5 ? Colors.orange.shade600 : scheme.error);
    Widget value(String label, String text, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Caption(label, color: scheme.onSurfaceVariant),
          const Gap(4),
          Text(
            text,
            style: (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              value(
                t.avpn.statsPing,
                summary.ping == null ? '—' : '${summary.ping} ms',
                summary.ping == null
                    ? scheme.onSurfaceVariant
                    : theme.araLook.pingColor(summary.ping!, scheme.onSurfaceVariant),
              ),
              value(
                t.avpn.statsLoss,
                loss == null ? '—' : '${loss.toStringAsFixed(loss < 10 && loss > 0 ? 1 : 0)}%',
                lossColor,
              ),
            ],
          ),
          const Gap(10),
          // two-sided: the loss hangs from the top down to the middle, the ping rises from the bottom up to it; each
          // half named at its side
          _grow(
            fill,
            // the sidebar's: taller, the bars the full width (no names at the side, the values are over it)
            height: compact ? 64 : 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      halfLabel(Icons.south_rounded, t.avpn.statsLoss.toLowerCase(), lostColor),
                      halfLabel(Icons.north_rounded, t.avpn.statsPing.toLowerCase(), theme.araLook.pingColors.first),
                    ],
                  ),
                  const Gap(8),
                ],
                Expanded(
                  child: CustomPaint(
                    painter: _PingBars(
                      bars,
                      losses: losses,
                      slots: period?.slots ?? ConnectionQuality.length,
                      ok: theme.araLook.pingColors.first,
                      colorOf: (ms) => theme.araLook.pingColor(ms, scheme.onSurfaceVariant),
                      // the loss in red, unless red already means a fast ping (the red theme): then in the text colour
                      lost: lostColor,
                      track: scheme.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!compact) const Gap(6),
          if (!compact)
            Text(
              bars.isEmpty
                  ? t.avpn.statsNoData
                  : (period == null ? t.avpn.statsPingHistory : t.avpn.statsPingPeriod),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (spread != null) ...[
            Gap(compact ? 6 : 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final (i, (label, ms)) in [
                      (t.avpn.pingAvg, spread.avg),
                      (t.avpn.pingMin, spread.min),
                      (t.avpn.pingMax, spread.max),
                      if (spread.jitter >= 0) (t.avpn.pingJitter, spread.jitter),
                    ].indexed) ...[
                      TextSpan(text: '${i == 0 ? '' : ' · '}$label '),
                      TextSpan(
                        text: i == 3 ? '±$ms' : '$ms',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i == 3 ? scheme.onSurface : theme.araLook.pingColor(ms, scheme.onSurface),
                        ),
                      ),
                    ],
                    if (!compact) const TextSpan(text: ' ms'),
                  ],
                ),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-sided bars, one per probe (or slot): the lower half the ping, rising from the bottom (scaled to the usual
/// ping), the upper half the loss, hanging from the top (a lost probe, or a slot that lost all of them, reaches the
/// middle). Both halves over a faint track.
class _PingBars extends CustomPainter {
  _PingBars(
    this.samples, {
    required this.losses,
    required this.ok,
    required this.lost,
    required this.track,
    this.colorOf,
    this.slots = ConnectionQuality.length,
  });

  /// a probe's (or a slot's average) ping; null: lost; 0: no probes in that slot
  final List<int?> samples;

  /// each probe's (slot's) share lost, 0 to 1, in step with [samples]
  final List<double> losses;

  /// how many bars the width holds
  final int slots;
  final Color ok;

  /// each answered probe in the colour of its ping (the theme's scale)
  final Color Function(int ms)? colorOf;
  final Color lost;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / slots;
    final barWidth = slot * (slots > 40 ? .7 : .62);
    const gap = 2.0;
    final half = (size.height - gap) / 2;
    final lowerTop = half + gap;
    // the scale follows the usual ping, not one stray spike: a spike over three times the median fills the half
    final answered = samples.whereType<int>().where((v) => v > 0).toList()..sort();
    final median = answered.isEmpty ? 50 : answered[answered.length ~/ 2];
    final top = answered.isEmpty ? 50 : answered.last;
    final peak = top.clamp(50, median * 3 < 50 ? 50 : median * 3);
    final offset = (slots - samples.length).clamp(0, slots);
    final cut = samples.length > slots ? samples.length - slots : 0;
    const radius = Radius.circular(2);
    for (var i = 0; i < slots; i++) {
      final x = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, half), radius), Paint()..color = track);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, lowerTop, barWidth, half), radius),
        Paint()..color = track,
      );
      if (i < offset) continue;
      final k = cut + i - offset;
      final sample = samples[k];
      final loss = k < losses.length ? losses[k].clamp(0.0, 1.0) : (sample == null ? 1.0 : 0.0);
      if (loss > 0) {
        final h = math.max(half * loss, math.min(3.0, half));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, h), radius), Paint()..color = lost);
      }
      if (sample != null && sample > 0) {
        final h = (half * (sample / peak)).clamp(math.min(3.0, half), half).toDouble();
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, barWidth, h), radius),
          Paint()..color = colorOf?.call(sample) ?? ok,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PingBars old) => old.samples != samples || old.losses != losses || old.ok != ok;
}

bool _isRed(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue < 20 || hue > 340;
}

/// The period chips on the speed block: a minute, ten minutes, an hour, a day, all the time.
class _RangePicker extends ConsumerWidget {
  const _RangePicker({required this.range, required this.color, this.short = false});

  /// the narrow sidebar's labels: «1м», «10м», «1ч», «24ч», «Всё»
  final bool short;

  final StatsRange range;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final labels = {
      StatsRange.minute: t.avpn.rangeMinute,
      StatsRange.tenMinutes: t.avpn.rangeTenMinutes,
      StatsRange.hour: t.avpn.rangeHour,
      StatsRange.day: t.avpn.rangeDay,
      StatsRange.all: t.avpn.rangeAll,
    };
    return Row(
      children: [
        for (final r in StatsRange.values)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(statsRangeProvider.notifier).range = r,
              // Bento and Dots: their own pills (a solid chip, an inked box)
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration:
                    lookPill(homeLookNow, context, on: r == range)?.box ??
                    BoxDecoration(
                      color: r == range ? color.withValues(alpha: .16) : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: color.withValues(alpha: r == range ? .5 : (theme.araLook.neonFill != null ? .4 : .18)),
                      ),
                    ),
                child: Text(
                  short
                      ? labels[r]!
                            .replaceAll(' мин', 'м')
                            .replaceAll(' ч', 'ч')
                            .replaceAll(' min', 'm')
                            .replaceAll(' h', 'h')
                      : labels[r]!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        lookPill(homeLookNow, context, on: r == range)?.ink ??
                        (theme.araLook.neonFill != null ? color : color.withValues(alpha: r == range ? 1 : .7)),
                    fontWeight: r == range ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// [child] at [height], or, when [grow], taking the height left (never less than [height])
Widget _grow(bool grow, {required double height, required Widget child}) => grow
    ? Expanded(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: child,
        ),
      )
    : SizedBox(height: height, child: child);

/// The speed graph, sliding: when a new second's sample comes in, the lines glide one step to the left over that
/// second instead of jumping (only while [live]; the hidden tabs' tickers stop it).
class _SlidingGraph extends HookWidget {
  const _SlidingGraph({required this.samples, required this.live, required this.painter});

  final List<({int down, int up})> samples;
  final bool live;
  final CustomPainter Function(Animation<double>? slide) painter;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(duration: const Duration(seconds: 1), initialValue: 1);
    // a new sample is a new list (the same one on any other rebuild)
    useEffect(() {
      if (live && samples.length > 1) controller.forward(from: 0);
      return null;
    }, [samples, live]);
    // the sliding lines in a layer of their own: each slide repainted the whole page
    return RepaintBoundary(child: CustomPaint(painter: painter(live ? controller : null)));
  }
}

/// This session's packet loss: its share of the probes, a strip of the session with each loss where it fell, and
/// each stretch of loss with when it began, how long it went on and how much was lost.
class _LossDay extends ConsumerWidget {
  const _LossDay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final muted = scheme.onSurfaceVariant;
    ref.watch(connectionQualityProvider);
    final start = ref.watch(sessionStartProvider);
    final day = ref.read(connectionQualityProvider.notifier).lossDay(since: start ?? DateTime.now());
    final loss = theme.araAccent;
    final lossText = dark ? const Color(0xFFA3A9B0) : const Color(0xFF5F656D);
    String two(int n) => n.toString().padLeft(2, '0');
    String clock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
    String percent(double v) => v == 0
        ? '0%'
        : v < .001
        ? '<0,1%'
        : '${(v * 100).toStringAsFixed(v < .1 ? 1 : 0).replaceAll('.', ',')}%';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.avpn.contrastLossTitle,
            style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Expanded(
            child: day.episodes.isEmpty
                ? Center(
                    child: Text(t.avpn.contrastLossNone, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    // not a scroll of its own: a swipe started on it turns the page to the speed, as anywhere else
                    // (the newest stretches on top; the rest are under the card's edge)
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: day.episodes.length,
                    itemBuilder: (context, i) {
                      final e = day.episodes[i];
                      final minutes = e.minutes;
                      final lasted = minutes >= 60
                          ? '${minutes ~/ 60} ${t.avpn.unitHourShort} ${minutes % 60} ${t.avpn.unitMinuteShort}'
                          : '$minutes ${t.avpn.unitMinuteShort}';
                      final part = e.sent == 0 ? 0.0 : e.lost / e.sent;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: .07))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: loss, shape: BoxShape.circle),
                            ),
                            const Gap(10),
                            SizedBox(
                              width: 112,
                              child: Text(
                                minutes <= 1
                                    ? clock(e.start)
                                    : '${clock(e.start)}–${clock(e.start.add(Duration(minutes: minutes)))}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(lasted, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                            ),
                            Text(
                              percent(part),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: lossText),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The ping over the period chosen under it: now, the average, the fastest and slowest, and a bar per slot (a
/// probe every 3 seconds, longer periods averaged), the slow ones grey.
class _PingBlock extends ConsumerWidget {
  const _PingBlock({required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final samples = ref.watch(connectionQualityProvider);
    final full = ref.read(connectionQualityProvider.notifier).period(range);
    // the minute: its last 20 probes (one every 3 seconds; the notifier keeps three minutes of them)
    final period = range == StatsRange.minute
        ? (() {
            final bars = full.bars.length > 20 ? full.bars.sublist(full.bars.length - 20) : full.bars;
            final total = PingBucket();
            for (final b in bars) {
              total.add(b);
            }
            return (bars: bars, losses: const <double>[], slots: 20, total: total);
          })()
        : full;
    final now = samples.reversed.firstWhere((v) => v != null, orElse: () => null);
    final total = period.total;
    final periodName = switch (range) {
      StatsRange.minute => t.avpn.rangeMinute,
      StatsRange.tenMinutes => t.avpn.rangeTenMinutes,
      StatsRange.hour => t.avpn.rangeHour,
      StatsRange.day => t.avpn.rangeDay,
      StatsRange.all => t.avpn.periodAllTime,
    };
    final ticks = switch (range) {
      StatsRange.minute => ['−60 с', '−30', t.avpn.graphNow],
      StatsRange.tenMinutes => ['−10 мин', '−5', t.avpn.graphNow],
      StatsRange.hour => ['−60 мин', '−30', t.avpn.graphNow],
      StatsRange.day => ['−24 ч', '−12', t.avpn.graphNow],
      StatsRange.all => ['', '', t.avpn.graphToday],
    };
    Widget figure(String label, String value) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.avpn.pingNow,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: now == null ? '—' : '$now'),
                        if (now != null)
                          TextSpan(
                            text: ' ms',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -1, height: 1.1),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  figure(t.avpn.pingAverage, total.average == null ? '—' : '${total.average} ms'),
                  figure(t.avpn.pingRange, total.answered == 0 ? '—' : '${total.min} · ${total.max}'),
                ],
              ),
            ],
          ),
          const Gap(8),
          Text(
            t.avpn.pingFor(period: periodName),
            style: theme.textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w600),
          ),
          const Gap(6),
          Expanded(
            child: CustomPaint(
              painter: _PingGraph(
                period.bars,
                slots: period.slots,
                // Dots: the ordinary bars in the text's colour (white by night, black by day), the style's colour only
                // for a very slow answer (300 ms and over)
                colour: homeLookNow == HomeLayout.dots ? scheme.onSurface : theme.araAccent,
                slow: homeLookNow == HomeLayout.dots ? theme.araAccent : const Color(0xFF8C939C),
                slowAt: homeLookNow == HomeLayout.dots ? 300 : 150,
                grid: scheme.onSurface.withValues(alpha: .06),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const Gap(4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in ticks)
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 10)),
            ],
          ),
          const Gap(8),
          _RangePicker(range: range, color: theme.araIcon),
        ],
      ),
    );
  }
}

/// A bar per slot, as tall as its ping on a scale rounded up from the slowest; slots over 150 ms grey, a slot
/// with nothing answered left out.
class _PingGraph extends CustomPainter {
  _PingGraph(
    this.bars, {
    required this.slots,
    required this.colour,
    required this.slow,
    required this.grid,
    this.slowAt = 150,
  });

  final List<int?> bars;
  final int slots;
  final Color colour;
  final Color slow;
  final Color grid;

  /// from this many ms a bar is drawn in [slow]
  final int slowAt;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = grid;
    for (final f in const [.25, .5, .75]) {
      canvas.drawLine(Offset(0, size.height * f), Offset(size.width, size.height * f), line);
    }
    final answered = bars.whereType<int>().where((v) => v > 0);
    if (answered.isEmpty) return;
    // the scale from the slowest, 150 to 500 ms: a spike runs off the top instead of flattening the usual ping
    final top = ((answered.reduce(math.max) / 50).ceil() * 50.0).clamp(150.0, 500.0);
    final n = math.max(slots, bars.length);
    final w = size.width / n;
    final start = n - bars.length;
    final paint = Paint();
    for (var i = 0; i < bars.length; i++) {
      final v = bars[i];
      if (v == null || v <= 0) continue;
      final h = math.max(2.0, size.height * math.min(1.0, v / top));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((start + i) * w + w * .15, size.height - h, w * .7, h),
          Radius.circular(math.min(2, w * .3)),
        ),
        paint..color = v > slowAt ? slow : colour,
      );
    }
  }

  @override
  bool shouldRepaint(_PingGraph old) => true;
}
