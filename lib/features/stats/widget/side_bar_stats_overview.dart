import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The desktop sidebar's traffic panel: live speed, what this session moved, and how much of it went through
/// the VPN rather than direct.
class SideBarStatsOverview extends ConsumerWidget {
  const SideBarStatsOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = t.avpn.bytesUnits.split(',');
    String size(int bytes) => formatBytes(bytes, units);
    String speed(int bytes) => '${formatBytes(bytes, units)}${t.avpn.perSecond}';

    final total = stats.uplinkTotal.toInt() + stats.downlinkTotal.toInt();
    final vpnUp = stats.vpnUplinkTotal;
    final vpnDown = stats.vpnDownlinkTotal;
    final vpn = vpnUp == null || vpnDown == null ? null : vpnUp + vpnDown;
    final share = vpn == null || total == 0 ? null : (vpn / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Caption(t.avpn.statsSpeed),
              const Gap(8),
              _SpeedRow(
                icon: Icons.south_rounded,
                color: scheme.primary,
                label: t.avpn.statsDownload,
                value: speed(stats.downlink.toInt()),
                big: true,
              ),
              const Gap(4),
              _SpeedRow(
                icon: Icons.north_rounded,
                color: scheme.tertiary,
                label: t.avpn.statsUpload,
                value: speed(stats.uplink.toInt()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .5)),
              ),
              _Caption(t.avpn.statsSession),
              const Gap(6),
              _TotalRow(down: size(stats.downlinkTotal.toInt()), up: size(stats.uplinkTotal.toInt())),
              const Gap(14),
              Row(
                children: [
                  Expanded(child: _Caption(t.avpn.statsViaVpn)),
                  if (share != null)
                    Text(
                      '${(share * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const Gap(6),
              Text(
                vpn == null ? '—' : size(vpn),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Gap(8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share ?? 0,
                  minHeight: 6,
                  color: scheme.primary,
                  backgroundColor: scheme.outlineVariant.withValues(alpha: .5),
                ),
              ),
              if (vpn != null) ...[
                const Gap(6),
                Text(
                  '${t.avpn.statsDirect}: ${size((total - vpn).clamp(0, total))}',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({required this.icon, required this.color, required this.label, required this.value, this.big = false});

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: big ? 28 : 22,
          height: big ? 28 : 22,
          decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.down, required this.up});

  final String down;
  final String up;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.south_rounded, size: 14, color: muted),
        const Gap(2),
        Flexible(child: Text(down, style: style, overflow: TextOverflow.ellipsis)),
        const Gap(12),
        Icon(Icons.north_rounded, size: 14, color: muted),
        const Gap(2),
        Flexible(child: Text(up, style: style, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
