import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The desktop sidebar's traffic panel: live speed on the accent gradient, then matching tiles for this
/// session, the share that went through the VPN and the share that went direct.
class SideBarStatsOverview extends ConsumerWidget {
  const SideBarStatsOverview({super.key});

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
    final onSpeed = gradient != null ? Colors.white : scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(16),
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
              ],
            ),
          ),
          const Gap(10),
          _Tile(
            icon: Icons.data_usage_rounded,
            title: t.avpn.statsSession,
            value: size(total),
            detail: '↓ ${size(stats.downlinkTotal.toInt())}   ↑ ${size(stats.uplinkTotal.toInt())}',
          ),
          const Gap(8),
          _Tile(
            icon: Icons.shield_rounded,
            title: t.avpn.statsViaVpn,
            value: vpn == null ? '—' : size(vpn),
            share: share,
            accent: true,
          ),
          const Gap(8),
          _Tile(
            icon: Icons.alt_route_rounded,
            title: t.avpn.statsDirect,
            value: direct == null ? '—' : size(direct),
            share: share == null ? null : 1 - share,
          ),
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
                child: Icon(icon, size: 13, color: gradient != null ? Colors.white : color),
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
