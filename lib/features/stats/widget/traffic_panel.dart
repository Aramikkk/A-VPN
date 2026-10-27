import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/connection/notifier/shown_connection.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/traffic_strips.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The right half of the unfolded phone's home screen: where today's traffic went. The two totals (through the
/// VPN, direct) on top, the strips with the apps' icons under them, and every app with its way out filling the
/// rest. The apps under a megabyte are left out, as everywhere.
class TrafficPanel extends ConsumerWidget {
  const TrafficPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = t.avpn.bytesUnits.split(',');
    String size(num bytes) => formatBytes(bytes.round(), units);
    // followed only while the home screen is in sight
    final visible = TickerMode.of(context);
    final state = visible ? ref.watch(connectionsProvider) : ref.read(connectionsProvider);
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    // this session's connections only, as the heading says
    // held across the statistics stream's blinks, so the card doesn't flip when the app comes back
    final sessionStart = ref.watch(sessionStartProvider);
    // the VPN off: no session, the picture (the last session's list isn't shown)
    final connected = ref.watch(shownConnectionProvider).isConnected;
    final current = sessionConnections(state, connected: connected, sessionStart: sessionStart);
    final groups = groupConnections(current, (c) => c.app).where((g) => g.total >= sessionTrafficMin).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final items = [for (final g in groups) ...g.items];
    // the tiles: the current session's traffic, as the heading says
    final session = ref.watch(sessionTotalsProvider);
    final total = session.up + session.down;
    final vpn = ((session.vpnUp ?? 0) + (session.vpnDown ?? 0)).clamp(0, total);
    final direct = total - vpn;
    final listed = items.fold<int>(0, (s, c) => s + c.total);
    final accent = theme.araAccent;

    Widget tile(String title, int bytes, Color colour, {required bool strong}) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  total == 0 ? '' : '${(bytes * 100 / total).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AraLook.readableOn(colour, scheme.surfaceContainerLow),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Gap(4),
            Text(
              size(bytes),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: strong ? AraLook.readableOn(colour, scheme.surfaceContainerLow) : null,
              ),
            ),
            const Gap(6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : bytes / total,
                minHeight: 5,
                color: colour,
                backgroundColor: scheme.outlineVariant.withValues(alpha: .4),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            tile(t.avpn.statsViaVpn, vpn, accent, strong: true),
            const Gap(10),
            tile(t.avpn.homeBypass, direct, const Color(0xFF9AA0A6), strong: false),
          ],
        ),
        const Gap(14),
        // nothing over a megabyte yet: the totals stay on top and a picture sits in the list's card, the panel
        // keeping its shape
        if (groups.isEmpty)
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              // a picture of strips, half the card high, until the traffic comes
              child: LayoutBuilder(
                builder: (context, box) =>
                    TrafficPlaceholder(height: math.min(box.maxHeight / 2, box.maxWidth * .6 * 122 / 200)),
              ),
            ),
          )
        else ...[
          _glassCard(
            context,
            TrafficStrips(
              items: items,
              weight: (c) => c.total.toDouble(),
              value: (w) => size(w),
              compact: true,
              barHeight: 54,
              headers: false,
              directLabel: t.avpn.homeBypass,
            ),
          ),
          const Gap(14),
          // every app with where it went, filling the rest of the half
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: groups.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 52, color: scheme.outlineVariant),
                itemBuilder: (context, i) {
                  final g = groups[i];
                  final name = connectionAppName(t, apps, g.key);
                  final colour = g.mainRoute == ConnectionRoute.vpn
                      ? accent
                      : (g.mainRoute == ConnectionRoute.block ? scheme.error : const Color(0xFF9AA0A6));
                  final route = switch (g.mainRoute) {
                    ConnectionRoute.vpn => g.servers.isEmpty ? 'VPN' : 'VPN · ${serverFlags(g.servers)}',
                    ConnectionRoute.direct => t.avpn.homeBypass,
                    ConnectionRoute.block => t.avpn.connBlocked,
                  };
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                    child: Row(
                      children: [
                        ConnectionAppIcon(icon: apps[g.key]?.icon, name: name, size: 28),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Text(
                                    size(g.total),
                                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const Gap(2),
                              Row(
                                children: [
                                  Text(
                                    route,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AraLook.readableOn(colour, scheme.surfaceContainerLow),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: listed == 0 ? 0 : (g.total / listed).clamp(.02, 1.0),
                                        minHeight: 3,
                                        color: colour,
                                        backgroundColor: scheme.outlineVariant.withValues(alpha: .3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Glass: [child] on a see-through pane with a bright edge, as the cards round it; otherwise as it is.
Widget _glassCard(BuildContext context, Widget child) {
  final glass = Theme.of(context).glassLook;
  if (glass == null) return child;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: glass.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: glass.edge, width: 1.2),
    ),
    child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: child),
  );
}
