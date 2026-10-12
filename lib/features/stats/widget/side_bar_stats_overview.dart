import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The traffic panel: live speed on the accent gradient, then matching tiles for this session, the share that
/// went through the VPN and the share that went direct. In the desktop sidebar, and [large] (with the last
/// minute's speed graph) on the phone's Speed tab.
class SideBarStatsOverview extends ConsumerWidget {
  const SideBarStatsOverview({super.key, this.large = false, this.dense = false});

  final bool large;

  /// [large] made to fit one screen height (the unfolded phone's home, beside the servers): a lower graph,
  /// legend and figures on one line, compact cards
  final bool dense;

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
    final history = ref.watch(speedHistoryProvider);
    final quality = ref.watch(connectionQualityProvider);

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

    return Padding(
      padding: dense ? const EdgeInsets.fromLTRB(12, 4, 12, 8) : EdgeInsets.all(large ? 16 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                  Gap(large && !dense ? 16 : 10),
                  SizedBox(
                    height: dense ? 92 : (large ? 130 : 64),
                    child: CustomPaint(
                      painter: _SpeedGraph(
                        history,
                        color: onSpeed,
                        label: speed,
                        detailed: large,
                        textStyle: theme.textTheme.labelSmall!.copyWith(
                          color: onSpeed.withValues(alpha: .75),
                          fontSize: 10,
                        ),
                        startLabel: t.avpn.graphStart,
                        nowLabel: t.avpn.graphNow,
                      ),
                    ),
                  ),
                  const Gap(8),
                  _GraphSummary(history: history, color: onSpeed, speed: speed, oneLine: dense),
                ],
              ],
            ),
          ),
          Gap(large ? 10 : 8),
          _QualityCard(samples: quality, compact: compact),
          const Gap(8),
          _pair(
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
          ),
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
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
                backgroundColor: scheme.outlineVariant.withValues(alpha: .6),
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

/// The legend and the minute's peak and average download speed, under the graph.
class _GraphSummary extends ConsumerWidget {
  const _GraphSummary({required this.history, required this.color, required this.speed, this.oneLine = false});

  final List<({int down, int up})> history;
  final Color color;
  final String Function(int) speed;

  /// the legend and the figures side by side (they wrap when there's no room)
  final bool oneLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: .85));
    final strong = style?.copyWith(color: color, fontWeight: FontWeight.w700);
    final downs = history.map((s) => s.down).toList();
    final peak = downs.isEmpty ? 0 : downs.reduce((a, b) => a > b ? a : b);
    final average = downs.isEmpty ? 0 : downs.reduce((a, b) => a + b) ~/ downs.length;
    Widget legend(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const Gap(4),
        Text(text, style: style),
      ],
    );
    final downMark = Container(
      width: 12,
      height: 8,
      decoration: BoxDecoration(color: color.withValues(alpha: .55), borderRadius: BorderRadius.circular(2)),
    );
    final upMark = SizedBox(width: 14, height: 8, child: CustomPaint(painter: _DashSample(color)));
    if (oneLine) {
      // the marks with arrows instead of words, and the figures beside them
      return Row(
        children: [
          legend(downMark, '↓'),
          const Gap(10),
          legend(upMark, '↑'),
          const Gap(12),
          Expanded(
            child: Text.rich(
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
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            legend(
              Container(
                width: 12,
                height: 8,
                decoration: BoxDecoration(color: color.withValues(alpha: .55), borderRadius: BorderRadius.circular(2)),
              ),
              t.avpn.statsDownload,
            ),
            legend(
              SizedBox(width: 14, height: 8, child: CustomPaint(painter: _DashSample(color))),
              t.avpn.statsUpload,
            ),
          ],
        ),
        const Gap(4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${t.avpn.graphPeak} ', style: style),
              TextSpan(text: speed(peak), style: strong),
              TextSpan(text: '   ${t.avpn.graphAverage} ', style: style),
              TextSpan(text: speed(average), style: strong),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The upload line's look, for the legend.
class _DashSample extends CustomPainter {
  _DashSample(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 3, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DashSample old) => old.color != color;
}

/// The last minute of download (filled) and upload (dashed) speed, on a scale rounded to a readable number with
/// its values on the side, and the time along the bottom.
class _SpeedGraph extends CustomPainter {
  _SpeedGraph(
    this.samples, {
    required this.color,
    required this.label,
    required this.detailed,
    required this.textStyle,
    required this.startLabel,
    required this.nowLabel,
  });

  final List<({int down, int up})> samples;
  final Color color;
  final String Function(int bytesPerSecond) label;
  final bool detailed;
  final TextStyle textStyle;
  final String startLabel;
  final String nowLabel;

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

  @override
  void paint(Canvas canvas, Size size) {
    final timeAxis = detailed ? 14.0 : 0.0;
    final peak = samples.fold<int>(0, (m, s) => s.down > m ? s.down : (s.up > m ? s.up : m));
    final top = niceCeiling(peak);
    final rows = detailed ? 4 : 2;
    // the scale's values sit in their own strip on the right, clear of the lines
    final labels = [for (var i = 0; i < rows; i++) _text(label((top * (rows - i) / rows).round()))];
    final gutter = labels.fold<double>(0, (w, l) => l.width > w ? l.width : w) + 6;
    final chart = Size(size.width - gutter, size.height - timeAxis);

    final grid = Paint()
      ..color = color.withValues(alpha: .16)
      ..strokeWidth = 1;
    for (var i = 0; i <= rows; i++) {
      final y = chart.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(chart.width, y), grid);
      if (i < rows) {
        // each value hangs just below its line, so they're evenly spaced
        labels[i].paint(canvas, Offset(size.width - labels[i].width, y + 1));
      }
    }
    if (detailed) {
      _text(startLabel).paint(canvas, Offset(0, chart.height + 2));
      final now = _text(nowLabel);
      now.paint(canvas, Offset(chart.width - now.width, chart.height + 2));
    }
    if (samples.length < 2) return;

    final step = chart.width / (SpeedHistory.length - 1);
    final start = chart.width - step * (samples.length - 1);
    Offset point(int i, int value) => Offset(start + step * i, chart.height - chart.height * value / top);

    final down = Path()..moveTo(start, chart.height);
    for (var i = 0; i < samples.length; i++) {
      final p = point(i, samples[i].down);
      down.lineTo(p.dx, p.dy);
    }
    final downLine = Path.from(down);
    down
      ..lineTo(chart.width, chart.height)
      ..close();
    canvas.drawPath(
      down,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .5), color.withValues(alpha: .04)],
        ).createShader(Offset.zero & chart),
    );
    canvas.drawPath(
      downLine,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // upload: dashed
    final dash = Paint()
      ..color = color.withValues(alpha: .85)
      ..strokeWidth = 1.6;
    for (var i = 0; i + 1 < samples.length; i++) {
      if (i.isEven) canvas.drawLine(point(i, samples[i].up), point(i + 1, samples[i + 1].up), dash);
    }

    // the latest download speed, marked
    canvas.drawCircle(point(samples.length - 1, samples.last.down), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SpeedGraph old) => old.samples != samples || old.color != color;
}

/// Ping through the VPN and packet loss over the last minute: the values, and a bar per probe (lost ones red).
class _QualityCard extends ConsumerWidget {
  const _QualityCard({required this.samples, this.compact = false});

  final List<int?> samples;

  /// the sidebar's smaller version, without the caption under the bars
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = summarize(samples);
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              value(
                t.avpn.statsPing,
                summary.ping == null ? '—' : '${summary.ping} ms',
                summary.ping == null ? scheme.onSurfaceVariant : scheme.primary,
              ),
              value(
                t.avpn.statsLoss,
                loss == null ? '—' : '${loss.toStringAsFixed(loss < 10 && loss > 0 ? 1 : 0)}%',
                lossColor,
              ),
            ],
          ),
          const Gap(10),
          SizedBox(
            height: compact ? 28 : 56,
            child: CustomPaint(
              painter: _PingBars(
                samples,
                ok: scheme.primary,
                lost: scheme.error,
                track: scheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
          ),
          if (!compact) const Gap(6),
          if (!compact)
            Text(
              samples.isEmpty ? t.avpn.statsNoData : t.avpn.statsPingHistory,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// One bar per probe, height by ping (scaled to the slowest answer); a lost probe is a full-height red bar.
class _PingBars extends CustomPainter {
  _PingBars(this.samples, {required this.ok, required this.lost, required this.track});

  final List<int?> samples;
  final Color ok;
  final Color lost;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const slots = ConnectionQuality.length;
    final slot = size.width / slots;
    final barWidth = slot * .62;
    final peak = samples.whereType<int>().fold<int>(50, (m, v) => v > m ? v : m);
    final offset = slots - samples.length;
    for (var i = 0; i < slots; i++) {
      final x = i * slot + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, size.height), const Radius.circular(2));
      canvas.drawRRect(rect, Paint()..color = track);
      if (i < offset) continue;
      final sample = samples[i - offset];
      final height = sample == null ? size.height : (size.height * (sample / peak)).clamp(3.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - height, barWidth, height), const Radius.circular(2)),
        Paint()..color = sample == null ? lost : ok,
      );
    }
  }

  @override
  bool shouldRepaint(_PingBars old) => old.samples != samples || old.ok != ok;
}
