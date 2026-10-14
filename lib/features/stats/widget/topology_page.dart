import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/proxy/data/hidden_servers.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/traffic_strips.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Topology tab: where the day's traffic went. The VPN servers on top, then the strips (each route and its
/// apps), then the rules ranked by how much went through them.
class TopologyPage extends HookConsumerWidget {
  const TopologyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // a tab out of sight (another one is open) stops following the list, so it isn't worked out again every two
    // seconds for nothing; it catches up when it's back on screen
    final visible = TickerMode.of(context);
    final state = visible ? ref.watch(connectionsProvider) : ref.read(connectionsProvider);
    final byTraffic = useState(true);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = t.avpn.bytesUnits.split(',');

    final open = state.items;
    // apps that moved less than a megabyte are left out, as in Connections
    final bigApps = {
      for (final g in groupConnections(open, (c) => c.app))
        if (g.total >= smallTraffic) g.key,
    };
    final items = open.where((c) => bigApps.contains(c.app)).toList();
    double weight(SeenConnection c) => byTraffic.value ? c.total.toDouble() : c.count.toDouble();
    String value(double w) => byTraffic.value ? formatBytes(w.round(), units) : '${w.round()}';
    final total = items.fold<double>(0, (s, c) => s + weight(c));
    double sum(Iterable<SeenConnection> cs) => cs.fold<double>(0, (s, c) => s + weight(c));
    final viaVpn = sum(items.where((c) => c.route == ConnectionRoute.vpn));
    final servers = groupConnections(
      items.where((c) => c.route == ConnectionRoute.vpn && c.outbound.isNotEmpty && !isHiddenServer(c.outbound)),
      (c) => c.outbound,
    );
    // a rule and the way it sent its traffic: the same list can send some of it through the VPN and some direct
    final rules = groupConnections(items, (c) => '${c.route.index}${ruleLabel(c.rule, t) ?? t.avpn.connRuleDefault}');

    // what moved since the list started (03:00, or the last clearing) against what the list holds: connections
    // shorter than one poll and the ones while the app was closed aren't in the list
    if (visible) ref.watch(trafficHistoryProvider);
    final moved = ref.read(trafficHistoryProvider.notifier).amountFrom(state.since ?? statsDayStart(DateTime.now()));
    final sessionVpn = moved.vpn;
    final sessionAll = moved.total;
    final listed = state.items.where((c) => c.route != ConnectionRoute.block).fold<int>(0, (s, c) => s + c.total);
    final uncounted = sessionAll - listed;
    final showUncounted = uncounted > smallTraffic && uncounted > sessionAll * .05;

    if (!state.available && state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.avpn.topologyTab)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              t.avpn.connNotConnected,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // the period the tab covers, under its name
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.avpn.topologyTab),
            Text(t.avpn.topoPeriod, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          // starts the picture over from now; it starts over by itself at 03:00
          if (state.items.any((c) => !c.active))
            IconButton(
              tooltip: t.avpn.connClear,
              icon: const Icon(Icons.cleaning_services_rounded),
              onPressed: () => ref.read(connectionsProvider.notifier).clearClosed(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              // the count or the traffic, in the middle
              Center(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text(t.avpn.connFlowCount),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.data_usage_rounded, size: 18),
                      label: Text(t.avpn.connFlowTraffic),
                    ),
                  ],
                  selected: {byTraffic.value},
                  onSelectionChanged: (s) => byTraffic.value = s.first,
                ),
              ),
              // the VPN servers this traffic went through, first
              if (servers.isNotEmpty) ...[
                const Gap(12),
                _Section(
                  title: t.avpn.topoServersTitle,
                  child: TrafficRanking(
                    rows: [
                      for (final g in (servers..sort((a, b) => sum(b.items).compareTo(sum(a.items)))).take(8))
                        (g.key, sum(g.items)),
                    ],
                    total: viaVpn,
                    value: value,
                    colour: theme.araLook.neonFill ?? scheme.primary,
                  ),
                ),
              ],
              const Gap(12),
              _Section(
                title: t.avpn.topoFlow,
                child: TrafficStrips(items: items, weight: weight, value: value),
              ),
              if (rules.isNotEmpty) ...[
                const Gap(12),
                _Section(
                  title: t.avpn.topoRulesTitle,
                  hint: t.avpn.topoRulesHint,
                  child: _RuleRows(
                    rows: [
                      for (final g in rules.take(8))
                        (
                          name: g.key.substring(1),
                          route: g.items.first.route,
                          servers: serverFlags(g.servers),
                          weight: sum(g.items),
                        ),
                    ]..sort((a, b) => b.weight.compareTo(a.weight)),
                    total: total,
                    value: value,
                  ),
                ),
              ],
              if (byTraffic.value && showUncounted) ...[
                const Gap(12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    t.avpn.topoUncounted(
                      amount: formatBytes(uncounted, units),
                      vpn: formatBytes(sessionVpn, units),
                      direct: formatBytes(sessionAll - sessionVpn, units),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Why this session's traffic went the way it did: the rules ranked by how much went through each, and where
/// they sent it. The home screen's pull-up sheet (Contrast).
class SessionRules extends ConsumerWidget {
  const SessionRules({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = t.avpn.bytesUnits.split(',');
    final start = ref.watch(sessionStartProvider);
    final session = [
      for (final c in ref.watch(connectionsProvider).items)
        if (start == null || !c.start.isBefore(start)) c,
    ];
    double sum(Iterable<SeenConnection> cs) => cs.fold<double>(0, (s, c) => s + c.total);
    final total = sum(session);
    final rules = groupConnections(
      session,
      (c) => '${c.route.index}${ruleLabel(c.rule, t) ?? t.avpn.connRuleDefault}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.avpn.topoRulesTitle, style: theme.textTheme.titleLarge),
        const Gap(4),
        Text(t.avpn.topoRulesHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const Gap(14),
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(child: TrafficPlaceholder(height: 70)),
          )
        else
          _RuleRows(
            rows: [
              for (final g in rules)
                (
                  name: g.key.substring(1),
                  route: g.items.first.route,
                  servers: serverFlags(g.servers),
                  weight: sum(g.items),
                ),
            ]..sort((a, b) => b.weight.compareTo(a.weight)),
            total: total,
            value: (w) => formatBytes(w.round(), units),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          if (hint != null) ...[
            const Gap(3),
            Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const Gap(10),
          child,
        ],
      ),
    );
  }
}

/// The rules' rows: the rule (its list's name), where it sent the traffic (through the VPN and which servers,
/// direct, or blocked) in that way's colour, and how much.
class _RuleRows extends ConsumerWidget {
  const _RuleRows({required this.rows, required this.total, required this.value});

  final List<({String name, ConnectionRoute route, String servers, double weight})> rows;
  final double total;
  final String Function(double) value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = scheme.surfaceContainerLow;
    final top = rows.fold<double>(0, (m, r) => r.weight > m ? r.weight : m);
    return Column(
      children: [
        for (final r in rows)
          Builder(
            builder: (context) {
              final colour = switch (r.route) {
                ConnectionRoute.vpn => AraLook.readableOn(scheme.primary, surface),
                ConnectionRoute.direct => AraLook.readableOn(const Color(0xFF9AA0A6), surface),
                ConnectionRoute.block => AraLook.readableOn(scheme.error, surface),
              };
              final way = switch (r.route) {
                ConnectionRoute.vpn => r.servers.isEmpty ? t.avpn.topoToVpn : '${t.avpn.topoToVpn} · ${r.servers}',
                ConnectionRoute.direct => t.avpn.topoToDirect,
                ConnectionRoute.block => t.avpn.topoToBlock,
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Gap(1),
                              Row(
                                children: [
                                  Icon(
                                    r.route == ConnectionRoute.block
                                        ? Icons.block_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: colour,
                                  ),
                                  const Gap(4),
                                  Flexible(
                                    child: Text(
                                      way,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colour,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        Text(
                          '${value(r.weight)} · ${total <= 0 ? 0 : (r.weight * 100 / total).round()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const Gap(6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: top <= 0 ? 0 : r.weight / top,
                        minHeight: 6,
                        color: colour,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
