import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/widget/connections_flow.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Topology tab: where the session's traffic went. On top the totals (through the VPN, direct, how many
/// servers), then the flows app → route → server, each app in its own colour, and the servers and the rules ranked
/// by how much went through them.
class TopologyPage extends HookConsumerWidget {
  const TopologyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // a tab out of sight (another one is open) stops following the list, so it isn't worked out again every two
    // seconds for nothing; it catches up when it's back on screen
    final visible = TickerMode.of(context);
    final state = visible ? ref.watch(connectionsProvider) : ref.read(connectionsProvider);
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final byTraffic = useState(true);
    final openOnly = useState(false);
    final hideSmall = useState(true);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = scheme.surfaceContainerLow;
    final units = t.avpn.bytesUnits.split(',');

    final open = openOnly.value ? state.items.where((c) => c.active).toList() : state.items;
    // apps that moved less than a megabyte are left out, as in Connections
    final bigApps = {
      for (final g in groupConnections(open, (c) => c.app))
        if (g.total >= smallTraffic) g.key,
    };
    final items = hideSmall.value ? open.where((c) => bigApps.contains(c.app)).toList() : open;
    double weight(SeenConnection c) => byTraffic.value ? c.total.toDouble() : c.count.toDouble();
    String value(double w) => byTraffic.value ? formatBytes(w.round(), units) : '${w.round()}';
    final total = items.fold<double>(0, (s, c) => s + weight(c));
    double sum(Iterable<SeenConnection> cs) => cs.fold<double>(0, (s, c) => s + weight(c));
    final viaVpn = sum(items.where((c) => c.route == ConnectionRoute.vpn));
    final direct = sum(items.where((c) => c.route == ConnectionRoute.direct));
    final servers = groupConnections(
      items.where((c) => c.route == ConnectionRoute.vpn && c.outbound.isNotEmpty),
      (c) => c.outbound,
    );
    // a rule and the way it sent its traffic: the same list can send some of it through the VPN and some direct
    final rules = groupConnections(items, (c) => '${c.route.index}${ruleLabel(c.rule, t) ?? t.avpn.connRuleDefault}');

    // what the core counted for the whole session against what the list holds: connections shorter than one poll
    // and the ones while the app was closed aren't in the list
    final info = (visible ? ref.watch(statsNotifierProvider) : ref.read(statsNotifierProvider)).valueOrNull;
    final sessionVpn = (info?.vpnUplinkTotal ?? 0) + (info?.vpnDownlinkTotal ?? 0);
    final sessionAll = (info?.uplinkTotal.toInt() ?? 0) + (info?.downlinkTotal.toInt() ?? 0);
    final listed = state.items.where((c) => c.route != ConnectionRoute.block).fold<int>(0, (s, c) => s + c.total);
    final uncounted = info?.vpnDownlinkTotal == null ? 0 : sessionAll - listed;
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

    final palette = flowPalette(scheme.primary, surface);
    final flow = ConnectionFlow.build(
      items,
      byTraffic: byTraffic.value,
      appName: (app) => connectionAppName(t, apps, app),
      routeName: (route) => switch (route) {
        ConnectionRoute.vpn => 'VPN',
        ConnectionRoute.direct => t.avpn.statsDirect,
        ConnectionRoute.block => t.avpn.connBlocked,
      },
      other: t.avpn.connOther,
      palette: palette,
      appColours: flowAppColours(surface),
      routeColor: (route) => switch (route) {
        ConnectionRoute.vpn => AraLook.readableOn(scheme.primary, surface),
        ConnectionRoute.direct => AraLook.readableOn(const Color(0xFF9AA0A6), surface),
        ConnectionRoute.block => AraLook.readableOn(scheme.error, surface),
      },
      maxPerColumn: 7,
    );
    final most = flow.columns.fold<int>(0, (m, c) => c.length > m ? c.length : m);
    final chartHeight = (most * 58.0 + 20).clamp(90.0, 430.0);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: .8,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.topologyTab)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<bool>(
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
                  FilterChip(
                    label: Text(t.avpn.connHideSmallChip),
                    selected: hideSmall.value,
                    onSelected: (v) => hideSmall.value = v,
                  ),
                  FilterChip(
                    label: Text(t.avpn.connOpenOnly),
                    selected: openOnly.value,
                    onSelected: (v) => openOnly.value = v,
                  ),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  _Total(
                    label: t.avpn.statsViaVpn,
                    value: value(viaVpn),
                    share: total <= 0 ? null : viaVpn / total,
                    colour: scheme.primary,
                  ),
                  const Gap(8),
                  _Total(
                    label: t.avpn.statsDirect,
                    value: value(direct),
                    share: total <= 0 ? null : direct / total,
                    colour: scheme.onSurfaceVariant,
                  ),
                  const Gap(8),
                  _Total(label: t.avpn.topoServerCount, value: '${servers.length}', colour: scheme.onSurface),
                ],
              ),

              const Gap(12),
              _Section(
                title: t.avpn.topoFlow,
                child: flow.isEmpty
                    ? SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(t.avpn.connEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // the column headings, over their columns
                          LayoutBuilder(
                            builder: (context, box) {
                              final step = (box.maxWidth * .66 - ConnectionFlowPainter.bar) / 2;
                              return SizedBox(
                                height: 16,
                                child: Stack(
                                  children: [
                                    for (final (i, text) in [
                                      t.avpn.topoApps,
                                      t.avpn.topoRoute,
                                      t.avpn.topoServers,
                                    ].indexed)
                                      Positioned(
                                        left: i * step,
                                        width: i == 2 ? box.maxWidth - i * step : step - 4,
                                        child: Text(
                                          text.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: label,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Gap(8),
                          SizedBox(
                            height: chartHeight,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: ConnectionFlowPainter(
                                flow,
                                background: surface,
                                valueLabel: value,
                                textStyle: theme.textTheme.bodySmall!.copyWith(
                                  color: scheme.onSurface,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (servers.isNotEmpty) ...[
                const Gap(12),
                _Section(
                  title: t.avpn.topoServersTitle,
                  child: _Ranking(
                    rows: [for (final g in servers.take(8)) (g.key, sum(g.items))],
                    total: viaVpn,
                    value: value,
                    colour: scheme.primary,
                  ),
                ),
              ],
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
                          servers: g.servers.join(', '),
                          weight: sum(g.items),
                        ),
                    ]..sort((a, b) => b.weight.compareTo(a.weight)),
                    total: total,
                    value: value,
                  ),
                ),
              ],
              if (byTraffic.value && !openOnly.value && showUncounted) ...[
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

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.colour, this.share});

  final String label;
  final String value;
  final double? share;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
            const Gap(2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, color: colour)),
            ),
            // a card without a share keeps the line empty, so the three cards are the same height
            Text(
              share == null ? '' : '${(share! * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
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

/// Rows of a name, a share bar and the amount with its share.
class _Ranking extends StatelessWidget {
  const _Ranking({required this.rows, required this.total, required this.value, required this.colour});

  final List<(String, double)> rows;
  final double total;
  final String Function(double) value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = rows.fold<double>(0, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      children: [
        for (final (name, w) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const Gap(8),
                    Text(
                      '${value(w)} · ${total <= 0 ? 0 : (w * 100 / total).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Gap(5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top <= 0 ? 0 : w / top,
                    minHeight: 6,
                    color: colour,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
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
