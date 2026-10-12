import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The traffic panel: live speed on the accent gradient, then matching tiles for this session, the share that
/// went through the VPN and the share that went direct. In the desktop sidebar, and [large] (with the last
/// minute's speed graph) on the phone's Speed tab.
class SideBarStatsOverview extends ConsumerWidget {
  const SideBarStatsOverview({
    super.key,
    this.large = false,
    this.dense = false,
    this.fill = false,
    this.split = false,
  });

  final bool large;

  /// [large] made to fit one screen height (the unfolded phone's home, beside the servers): a lower graph,
  /// legend and figures on one line, compact cards
  final bool dense;

  /// [dense] stretched to the height it's given (the unfolded home, level with the servers' column): the graph
  /// takes the room left over; no padding of its own
  final bool fill;

  /// [large] in two columns filling the height it's given (the unfolded phone's Statistics tab): the speed block
  /// on the left with the graph taking the room left over, ping and the tiles on the right
  final bool split;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = theme.araLook.gradient;
    final units = t.avpn.bytesUnits.split(',');
    String size(int bytes) => formatBytes(bytes, units);
    String speed(int bytes) => '${formatBytes(bytes, units)}${t.avpn.perSecond}';

    // the whole session's totals: the core's own counters restart at every reload (network or server change)
    final session = ref.watch(sessionTotalsProvider);
    final total = session.up + session.down;
    final vpnUp = session.vpnUp;
    final vpnDown = session.vpnDown;
    final vpn = vpnUp == null || vpnDown == null ? null : vpnUp + vpnDown;
    final direct = vpn == null ? null : (total - vpn).clamp(0, total);
    final share = vpn == null || total == 0 ? null : (vpn / total).clamp(0.0, 1.0);
    final onSpeed = gradient != null ? theme.araLook.onGradient : scheme.onPrimaryContainer;
    final minute = ref.watch(speedHistoryProvider);
    // the Statistics tab picks the period; the sidebar always shows the last minute
    // the Statistics tab and the computer's sidebar pick the period; elsewhere it's the last minute
    final pickRange = large || PlatformUtils.isDesktop;
    final range = pickRange ? ref.watch(statsRangeProvider) : StatsRange.minute;
    ref.watch(trafficHistoryProvider);
    final series = range == StatsRange.minute ? null : ref.read(trafficHistoryProvider.notifier).series(range);
    final history = series?.points ?? minute;
    final slots = series?.slots ?? SpeedHistory.length;
    String two(int n) => n.toString().padLeft(2, '0');
    final since = ref.read(trafficHistoryProvider.notifier).since;
    final sinceLabel = since == null ? '' : '${two(since.day)}.${two(since.month)}';
    final ticks = switch (range) {
      // the same shape on every period: the start with its unit, three marks, now
      StatsRange.minute => ['−60 с', '−45', '−30', '−15', t.avpn.graphNow],
      StatsRange.tenMinutes => ['−10 мин', '−7,5', '−5', '−2,5', t.avpn.graphNow],
      StatsRange.hour => ['−60 мин', '−45', '−30', '−15', t.avpn.graphNow],
      StatsRange.day => ['−24 ч', '−18', '−12', '−6', t.avpn.graphNow],
      StatsRange.all => [sinceLabel, '', '', '', t.avpn.graphToday],
    };
    final quality = ref.watch(connectionQualityProvider);
    final downColor = theme.araLook.graphDown ?? onSpeed;
    final upColor = theme.araLook.graphUp ?? onSpeed.withValues(alpha: .7);

    final compact = !large || dense;
    final vpnTile = _Tile(
      icon: Icons.shield_rounded,
      title: large && !dense ? t.avpn.statsViaVpn : 'VPN',
      value: vpn == null ? '—' : size(vpn),
      share: share,
      accent: true,
      compact: compact,
    );
    final directTile = _Tile(
      icon: Icons.alt_route_rounded,
      title: t.avpn.statsDirect,
      value: direct == null ? '—' : size(direct),
      share: share == null ? null : 1 - share,
      compact: compact,
    );

    final graph = CustomPaint(
      painter: _SpeedGraph(
        history,
        color: onSpeed,
        downColor: downColor,
        upColor: upColor,
        label: (value, top) {
          // every mark of the scale in the top mark's unit: «1,5 МБ/с … 0,5 МБ/с», not «512 КБ/с» under «1 МБ/с»
          var unit = 0;
          var div = 1.0;
          while (top / div >= 1024 && unit < units.length - 1) {
            div *= 1024;
            unit++;
          }
          final v = value / div;
          // «0,25», «0,5», «1», «37,5», «150»: as many decimals as the mark has, at most two
          var text = v >= 100 ? '${v.round()}' : v.toStringAsFixed(2);
          if (text.contains('.')) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
          text = text.replaceAll('.', ',');
          return '$text ${units[unit]}${t.avpn.perSecond}';
        },
        detailed: large,
        textStyle: theme.textTheme.labelSmall!.copyWith(color: onSpeed.withValues(alpha: .75), fontSize: 10),
        ticks: ticks,
        slots: slots,
      ),
    );
    final speedBlock = Container(
      padding: EdgeInsets.fromLTRB(16, dense ? 12 : 14, 16, large && !dense ? 16 : 12),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? scheme.primaryContainer : null,
        border: theme.araLook.border == null ? null : Border.all(color: theme.araLook.border!),
        borderRadius: BorderRadius.circular(large ? 24 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Caption(t.avpn.statsSpeed, color: onSpeed.withValues(alpha: .8)),
          const Gap(8),
          _SpeedRow(
            icon: Icons.south_rounded,
            label: t.avpn.statsDownload,
            value: speed(stats.downlink.toInt()),
            color: onSpeed,
            big: true,
          ),
          const Gap(4),
          _SpeedRow(
            icon: Icons.north_rounded,
            label: t.avpn.statsUpload,
            value: speed(stats.uplink.toInt()),
            color: onSpeed,
          ),
          ...[
            if (pickRange) ...[
              Gap(dense || !large ? 8 : 12),
              _RangePicker(range: range, color: onSpeed, short: !large),
            ],
            Gap(large && !dense ? 12 : 10),
            if (fill || split)
              Expanded(
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 160), child: graph),
              )
            else
              SizedBox(height: dense ? 92 : (large ? 130 : 64), child: graph),
            const Gap(8),
            _GraphSummary(
              history: history,
              color: onSpeed,
              downColor: downColor,
              upColor: upColor,
              speed: speed,
              oneLine: dense,
            ),
            if (series != null) ...[
              const Gap(4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${t.avpn.graphPeriodTotal} '),
                    TextSpan(
                      text: size(series.total.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (series.total.total > 0)
                      TextSpan(text: '  ·  VPN ${(series.total.vpn * 100 / series.total.total).round()}%'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: onSpeed.withValues(alpha: .85)),
              ),
            ],
          ],
        ],
      ),
    );

    final sessionPair = _pair(
      _Tile(
        icon: Icons.data_usage_rounded,
        title: t.avpn.statsSessionShort,
        value: size(total),
        detail: large
            ? '↓ ${size(session.down)}   ↑ ${size(session.up)}'
            : '↓ ${size(session.down)}\n↑ ${size(session.up)}',
        compact: compact,
      ),
      _Tile(
        icon: Icons.lan_rounded,
        title: t.avpn.statsConnectionsShort,
        value: '${stats.connectionsIn}',
        showBar: false,
        compact: compact,
      ),
    );

    if (split) {
      // both columns end on the same line: the speed block is as tall as the cards beside it, its graph taking
      // what the header leaves (the page scrolls when the screen is shorter)
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ConstrainedBox(
            // at least the screen's height: the graph and the ping bars grow into it
            constraints: BoxConstraints(minHeight: box.maxHeight.isFinite ? box.maxHeight - 24 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: speedBlock),
                  const Gap(12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _QualityCard(samples: quality, range: range, fill: true),
                        ),
                        const Gap(10),
                        sessionPair,
                        const Gap(10),
                        _pair(vpnTile, directTile),
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
    return Padding(
      padding: fill
          ? EdgeInsets.zero
          : dense
          ? const EdgeInsets.fromLTRB(12, 4, 12, 8)
          : EdgeInsets.all(large ? 16 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (fill) Expanded(child: speedBlock) else speedBlock,
          Gap(large ? 10 : 8),
          _QualityCard(samples: quality, compact: compact, range: range),
          const Gap(8),
          sessionPair,
          const Gap(8),
          _pair(vpnTile, directTile),
        ],
      ),
    );
  }
}

/// Two tiles side by side, the same height.
Widget _pair(Widget a, Widget b) => IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: a),
      const Gap(8),
      Expanded(child: b),
    ],
  ),
);

/// One stat as a card: icon, caption, value, and either a detail line or a share bar with its percentage.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
    this.showBar = true,
    this.share,
    this.accent = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  /// the share bar under the value (when there's no detail line)
  final bool showBar;
  final double? share;
  final bool accent;

  /// the sidebar's narrow version: no icon, tighter, smaller value
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = accent ? theme.araLook.gradient : null;
    final color = accent ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: compact ? const EdgeInsets.fromLTRB(10, 8, 10, 9) : const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!compact) ...[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    color: gradient == null ? color.withValues(alpha: .15) : null,
                  ),
                  child: Icon(icon, size: 13, color: gradient != null ? theme.araLook.onGradient : color),
                ),
                const Gap(8),
              ],
              Expanded(
                // tiles are narrow on a phone too: tight captions everywhere
                child: _Caption(title, color: scheme.onSurfaceVariant, tight: true),
              ),
              if (share != null) ...[
                Gap(compact ? 2 : 6),
                Text(
                  '${(share! * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ],
          ),
          Gap(compact ? 4 : 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap(compact ? 4 : 6),
          if (detail == null && !showBar)
            const SizedBox.shrink()
          else if (detail != null)
            Text(detail!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share ?? 0,
                minHeight: 5,
                color: accent ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: .55),
                backgroundColor: scheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.color, this.tight = false});

  final String text;
  final Color color;

  /// narrow tiles: less letter spacing, so the caption fits
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(letterSpacing: tight ? .3 : 1.1, fontWeight: FontWeight.w600, color: color),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: big ? 28 : 22,
          height: big ? 28 : 22,
          decoration: BoxDecoration(color: color.withValues(alpha: .18), shape: BoxShape.circle),
          child: Icon(icon, size: big ? 16 : 13, color: color),
        ),
        const Gap(10),
        Expanded(
          child: Tooltip(
            message: label,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (big ? theme.textTheme.titleLarge : theme.textTheme.bodyMedium)?.copyWith(
                color: color,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The legend in the graph's colours and the minute's peak and average download speed, under the graph.
class _GraphSummary extends ConsumerWidget {
  const _GraphSummary({
    required this.history,
    required this.color,
    required this.downColor,
    required this.upColor,
    required this.speed,
    this.oneLine = false,
  });

  final List<({int down, int up})> history;

  /// the text colour on the block
  final Color color;
  final Color downColor;
  final Color upColor;
  final String Function(int) speed;

  /// the legend and the figures side by side
  final bool oneLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: .85));
    final strong = style?.copyWith(color: color, fontWeight: FontWeight.w700);
    final downs = history.map((s) => s.down).toList();
    final peak = downs.isEmpty ? 0 : downs.reduce((a, b) => a > b ? a : b);
    final average = downs.isEmpty ? 0 : downs.reduce((a, b) => a + b) ~/ downs.length;
    Widget swatch(Color c) => Container(
      width: 12,
      height: 8,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
    );
    Widget legend(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch(c),
        const Gap(4),
        Text(text, style: style),
      ],
    );
    final figures = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${t.avpn.graphPeak} ', style: style),
          TextSpan(text: speed(peak), style: strong),
          TextSpan(text: '  ${t.avpn.graphAverage} ', style: style),
          TextSpan(text: speed(average), style: strong),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: oneLine ? TextAlign.end : TextAlign.start,
    );
    if (oneLine) {
      return Row(
        children: [
          legend(downColor, '↓'),
          const Gap(10),
          legend(upColor, '↑'),
          const Gap(12),
          Expanded(child: figures),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [legend(downColor, t.avpn.statsDownload), legend(upColor, t.avpn.statsUpload)],
        ),
        const Gap(4),
        figures,
      ],
    );
  }
}

/// The last minute of download and upload speed as smooth filled curves in their own colours, on a scale
/// rounded to a readable number with its values on the side, and a time axis marked every 15 seconds.
class _SpeedGraph extends CustomPainter {
  _SpeedGraph(
    this.samples, {
    required this.color,
    required this.downColor,
    required this.upColor,
    required this.label,
    required this.detailed,
    required this.textStyle,
    required this.ticks,
    this.slots = SpeedHistory.length,
  });

  /// how many samples the graph's width holds (fewer samples sit at the right)
  final int slots;

  final List<({int down, int up})> samples;

  /// the grid and the labels
  final Color color;
  final Color downColor;
  final Color upColor;

  /// a mark of the scale, given the top mark (the marks share its unit)
  final String Function(int bytesPerSecond, int top) label;
  final bool detailed;
  final TextStyle textStyle;

  /// the time axis labels, from 60 seconds ago to now (5 of them)
  final List<String> ticks;

  /// The top of the scale: 1, 2 or 5 times a power of ten in the unit the value reads in (KB/s, MB/s…), at or
  /// above [value], so the scale says "10 MB/s" rather than "9.5 MB/s". At least 1 KB/s.
  static int niceCeiling(int value) {
    if (value <= 1024) return 1024;
    var unit = 1;
    while (value / unit >= 1024) {
      unit *= 1024;
    }
    final inUnit = value / unit;
    var decade = 1;
    while (decade * 10 <= inUnit) {
      decade *= 10;
    }
    for (final m in [1, 2, 5, 10]) {
      if (decade * m >= inUnit) return decade * m * unit;
    }
    return decade * 10 * unit;
  }

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  /// A curve through [points] that never overshoots them: each segment bends towards the midpoint.
  static Path _smooth(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      if (i == points.length - 1) path.lineTo(b.dx, b.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final timeAxis = detailed ? 14.0 : 0.0;
    // the scale covers both lines: an upload burst above the download used to run off the top
    final peak = samples.fold<int>(0, (m, s) => [m, s.down, s.up].reduce((a, b) => a > b ? a : b));
    final top = niceCeiling(peak);
    final rows = detailed ? 4 : 2;
    // the scale's values sit in their own strip on the right, clear of the lines
    final labels = [for (var i = 0; i < rows; i++) _text(label((top * (rows - i) / rows).round(), top))];
    final gutter = labels.fold<double>(0, (w, l) => l.width > w ? l.width : w) + 6;
    final chart = Size(size.width - gutter, size.height - timeAxis);

    final grid = Paint()
      ..color = color.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var i = 0; i <= rows; i++) {
      final y = chart.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(chart.width, y), grid);
      // each mark centred on its line (the top one just under the edge)
      if (i < rows) {
        final h = labels[i].height;
        labels[i].paint(canvas, Offset(size.width - labels[i].width, (y - h / 2).clamp(0, chart.height - h)));
      }
    }
    // every 15 seconds: a faint line, and on the detailed graph its label
    final step = chart.width / (slots - 1).clamp(1, 1 << 20);
    var firstEnd = 0.0;
    final lastStart = detailed && ticks.length > 4 ? chart.width - _text(ticks[4]).width : chart.width;
    for (var k = 0; k <= 4; k++) {
      final x = chart.width * k / 4;
      if (k > 0 && k < 4) {
        canvas.drawLine(Offset(x, 0), Offset(x, chart.height), grid);
      }
      if (detailed && k < ticks.length) {
        final tick = _text(ticks[k]);
        final dx = k == 0 ? 0.0 : (k == 4 ? x - tick.width : x - tick.width / 2);
        // a mark that would run into the first or the last label is left out
        final clear = k == 0 || k == 4 || (dx > firstEnd + 6 && dx + tick.width < lastStart - 6);
        if (clear) tick.paint(canvas, Offset(dx, chart.height + 2));
        if (k == 0) firstEnd = dx + tick.width;
      }
    }
    if (samples.length < 2) return;
    // nothing draws outside the chart (the end dots may reach a little over its edges)
    canvas.clipRect(Rect.fromLTRB(-6, -6, chart.width + 6, chart.height + 6));

    final start = chart.width - step * (samples.length - 1);
    Offset point(int i, int value) => Offset(start + step * i, chart.height - chart.height * value / top);

    void series(List<int> values, Color c, double width, double fill) {
      final points = [for (var i = 0; i < values.length; i++) point(i, values[i])];
      final line = _smooth(points);
      final area = Path.from(line)
        ..lineTo(points.last.dx, chart.height)
        ..lineTo(points.first.dx, chart.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: fill),
              c.withValues(alpha: .02),
            ],
          ).createShader(Offset.zero & chart),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // upload under download, so the download (usually the bigger one) stays on top
    series([for (final s in samples) s.up], upColor, 1.6, .35);
    series([for (final s in samples) s.down], downColor, 2.2, .6);

    // now: both values marked
    canvas.drawCircle(point(samples.length - 1, samples.last.up), 3, Paint()..color = upColor);
    canvas.drawCircle(point(samples.length - 1, samples.last.down), 3.8, Paint()..color = downColor);
  }

  @override
  bool shouldRepaint(_SpeedGraph old) =>
      old.samples != samples || old.color != color || old.downColor != downColor || old.upColor != upColor;
}

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
          _grow(
            fill,
            height: compact ? 28 : 56,
            child: CustomPaint(
              painter: _PingBars(
                bars,
                slots: period?.slots ?? ConnectionQuality.length,
                ok: theme.araLook.pingColors.first,
                colorOf: (ms) => theme.araLook.pingColor(ms, scheme.onSurfaceVariant),
                // a lost probe in red, unless red already means a fast ping (the red theme): then in the text colour
                lost: _isRed(theme.araLook.pingColors.first) ? scheme.onSurface : scheme.error,
                track: scheme.outlineVariant.withValues(alpha: .5),
              ),
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

/// One bar per probe, height by ping (scaled to the slowest answer); a lost probe is a full-height red bar.
class _PingBars extends CustomPainter {
  _PingBars(
    this.samples, {
    required this.ok,
    required this.lost,
    required this.track,
    this.colorOf,
    this.slots = ConnectionQuality.length,
  });

  /// a probe's (or a slot's average) ping; null: lost; 0: no probes in that slot
  final List<int?> samples;

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
    // the scale follows the usual ping, not one stray spike: a spike over three times the median fills the bar
    final answered = samples.whereType<int>().where((v) => v > 0).toList()..sort();
    final median = answered.isEmpty ? 50 : answered[answered.length ~/ 2];
    final top = answered.isEmpty ? 50 : answered.last;
    final peak = top.clamp(50, median * 3 < 50 ? 50 : median * 3);
    final offset = (slots - samples.length).clamp(0, slots);
    final shown = samples.length > slots ? samples.sublist(samples.length - slots) : samples;
    for (var i = 0; i < slots; i++) {
      final x = i * slot + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, size.height), const Radius.circular(2));
      canvas.drawRRect(rect, Paint()..color = track);
      if (i < offset) continue;
      final sample = shown[i - offset];
      if (sample == 0) continue;
      final height = sample == null ? size.height : (size.height * (sample / peak)).clamp(3.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - height, barWidth, height), const Radius.circular(2)),
        Paint()..color = sample == null ? lost : (colorOf?.call(sample) ?? ok),
      );
    }
  }

  @override
  bool shouldRepaint(_PingBars old) => old.samples != samples || old.ok != ok;
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: r == range ? color.withValues(alpha: .16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: color.withValues(alpha: r == range ? .5 : .18)),
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
                    color: color.withValues(alpha: r == range ? 1 : .7),
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
