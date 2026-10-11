import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The traffic panel: live speed on the accent gradient, then matching tiles for this session, the share that
/// went through the VPN and the share that went direct. In the desktop sidebar, and [large] (with the last
/// minute's speed graph) on the phone's Speed tab.
class SideBarStatsOverview extends ConsumerWidget {
  const SideBarStatsOverview({super.key, this.large = false});

  final bool large;

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

    final total = stats.uplinkTotal.toInt() + stats.downlinkTotal.toInt();
    final vpnUp = stats.vpnUplinkTotal;
    final vpnDown = stats.vpnDownlinkTotal;
    final vpn = vpnUp == null || vpnDown == null ? null : vpnUp + vpnDown;
    final direct = vpn == null ? null : (total - vpn).clamp(0, total);
    final share = vpn == null || total == 0 ? null : (vpn / total).clamp(0.0, 1.0);
    final onSpeed = gradient != null ? theme.araLook.onGradient : scheme.onPrimaryContainer;
    final history = large ? ref.watch(speedHistoryProvider) : const <({int down, int up})>[];
    final quality = large ? ref.watch(connectionQualityProvider) : const <int?>[];

    final vpnTile = _Tile(
      icon: Icons.shield_rounded,
      title: t.avpn.statsViaVpn,
      value: vpn == null ? '—' : size(vpn),
      share: share,
      accent: true,
    );
    final directTile = _Tile(
      icon: Icons.alt_route_rounded,
      title: t.avpn.statsDirect,
      value: direct == null ? '—' : size(direct),
      share: share == null ? null : 1 - share,
    );

    return Padding(
      padding: EdgeInsets.all(large ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, large ? 16 : 14),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? scheme.primaryContainer : null,
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
                if (large) ...[
                  const Gap(16),
                  SizedBox(
                    height: 110,
                    child: CustomPaint(painter: _SpeedGraph(history, color: onSpeed)),
                  ),
                  const Gap(6),
                  _Caption(t.avpn.speedHistory, color: onSpeed.withValues(alpha: .7)),
                ],
              ],
            ),
          ),
          if (large) ...[const Gap(10), _QualityCard(samples: quality)],
          const Gap(10),
          _Tile(
            icon: Icons.data_usage_rounded,
            title: t.avpn.statsSession,
            value: size(total),
            detail: '↓ ${size(stats.downlinkTotal.toInt())}   ↑ ${size(stats.uplinkTotal.toInt())}',
          ),
          const Gap(8),
          if (large)
            // side by side, the same size
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: vpnTile),
                  const Gap(8),
                  Expanded(child: directTile),
                ],
              ),
            )
          else ...[
            vpnTile,
            const Gap(8),
            directTile,
          ],
          if (large) ...[
            const Gap(8),
            _Tile(
              icon: Icons.lan_rounded,
              title: t.avpn.statsConnections,
              value: '${stats.connectionsIn}',
              detail: '',
            ),
          ],
        ],
      ),
    );
  }
}

/// One stat as a card: icon, caption, value, and either a detail line or a share bar with its percentage.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
    this.share,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;
  final double? share;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = accent ? theme.araLook.gradient : null;
    final color = accent ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
              Expanded(child: _Caption(title, color: scheme.onSurfaceVariant)),
              if (share != null)
                Text(
                  '${(share! * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: color),
                ),
            ],
          ),
          const Gap(6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(6),
          if (detail != null)
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
  const _Caption(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w600, color: color),
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

/// Download (filled) and upload (line) speed over the last minute, scaled to the highest sample.
class _SpeedGraph extends CustomPainter {
  _SpeedGraph(this.samples, {required this.color});

  final List<({int down, int up})> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: .15)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (samples.length < 2) return;
    final peak = samples.fold<int>(1, (m, s) => s.down > m ? s.down : (s.up > m ? s.up : m));
    final step = size.width / (SpeedHistory.length - 1);
    final start = size.width - step * (samples.length - 1);
    Offset point(int i, int value) => Offset(start + step * i, size.height - size.height * value / peak * .92);

    final down = Path()..moveTo(start, size.height);
    for (var i = 0; i < samples.length; i++) {
      down.lineTo(point(i, samples[i].down).dx, point(i, samples[i].down).dy);
    }
    final downLine = Path.from(down);
    down
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      down,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .45), color.withValues(alpha: .02)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      downLine,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final up = Path();
    for (var i = 0; i < samples.length; i++) {
      final p = point(i, samples[i].up);
      i == 0 ? up.moveTo(p.dx, p.dy) : up.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      up,
      Paint()
        ..color = color.withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SpeedGraph old) => old.samples != samples || old.color != color;
}

/// Ping through the VPN and packet loss over the last minute: the values, and a bar per probe (lost ones red).
class _QualityCard extends ConsumerWidget {
  const _QualityCard({required this.samples});

  final List<int?> samples;

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
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
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
            height: 56,
            child: CustomPaint(
              painter: _PingBars(
                samples,
                ok: scheme.primary,
                lost: scheme.error,
                track: scheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
          ),
          const Gap(6),
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
