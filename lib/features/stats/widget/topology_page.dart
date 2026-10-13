import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Topology tab: where the session's traffic went. On top the totals (through the VPN, direct, how many
/// servers), then app → route → server, one line per app with arrows, and the servers and the rules ranked
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

    // app -> route -> server, one line per app, the biggest first; the rest added up in one line
    final byApp = groupConnections(items, (c) => c.app)..sort((a, b) => sum(b.items).compareTo(sum(a.items)));
    const shown = 7;
    final flowRows = <_Flow>[
      for (final g in byApp.take(shown)) _Flow(g.key, sum(g.items), g),
      if (byApp.length > shown)
        _Flow(
          null,
          sum(byApp.skip(shown).expand((g) => g.items)),
          groupConnections(byApp.skip(shown).expand((g) => g.items), (_) => '').first,
          others: byApp.length - shown,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.avpn.topologyTab),
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
                child: flowRows.isEmpty
                    ? SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(t.avpn.connEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final row in flowRows)
                            _FlowRow(
                              row: row,
                              name: row.app == null ? t.avpn.connOther : connectionAppName(t, apps, row.app!),
                              icon: row.app == null ? null : apps[row.app!]?.icon,
                              value: value(row.weight),
                              share: total == 0 ? 0 : row.weight / total,
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
                          servers: serverFlags(g.servers),
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

class _Flow {
  _Flow(this.app, this.weight, this.group, {this.others = 0});

  /// null: the other apps added up
  final String? app;
  final double weight;
  final ConnectionGroup group;
  final int others;
}

/// One app's way out: the app with its amount and a bar for its share, an arrow to the route (VPN, direct,
/// blocked, or both), and for the VPN an arrow on to its server or servers.
class _FlowRow extends ConsumerWidget {
  const _FlowRow({required this.row, required this.name, required this.icon, required this.value, required this.share});

  final _Flow row;
  final String name;
  final Uint8List? icon;
  final String value;
  final double share;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = row.group;
    final route = g.mainRoute;
    final colour = routeColor(scheme, route);
    final routeText = g.mixed
        ? [
            if (g.vpn > 0) 'VPN',
            if (g.direct > 0) t.avpn.statsDirect.toLowerCase(),
            if (g.blocked > 0) t.avpn.connBlocked.toLowerCase(),
          ].join(' + ')
        : switch (route) {
            ConnectionRoute.vpn => 'VPN',
            ConnectionRoute.direct => t.avpn.statsDirect,
            ConnectionRoute.block => t.avpn.connBlocked,
          };
    final servers = g.vpn > 0 ? serverFlags(g.servers) : '';
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget pill(String text, {required bool accent}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? colour.withValues(alpha: .14) : null,
        border: Border.all(color: accent ? colour.withValues(alpha: .5) : scheme.outlineVariant),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent ? AraLook.readableOn(colour, scheme.surfaceContainerLow) : scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    Widget arrow() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_rounded, size: 15, color: scheme.onSurfaceVariant),
    );
    // the app and its amount on top, its share as a bar, and under it where it went: → VPN → 🇸🇪 Швеция 2
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.app == null)
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.more_horiz_rounded, size: 18, color: scheme.onSurfaceVariant),
            )
          else
            ConnectionAppIcon(icon: icon, name: name, size: 30),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.app == null ? '$name · ${row.others}' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Gap(8),
                    Text('$value · ${(share * 100).round()}%', maxLines: 1, style: small),
                  ],
                ),
                const Gap(4),
                // the share of all the traffic, in the route's colour
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: share.clamp(.02, 1.0),
                    minHeight: 4,
                    color: colour,
                    backgroundColor: scheme.outlineVariant.withValues(alpha: .4),
                  ),
                ),
                const Gap(6),
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: scheme.onSurfaceVariant),
                    const Gap(4),
                    pill(routeText, accent: true),
                    if (servers.isNotEmpty) ...[arrow(), Flexible(child: pill(servers, accent: false))],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
