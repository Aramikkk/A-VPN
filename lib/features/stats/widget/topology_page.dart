import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/home/widget/pixel_flag.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/traffic_sankey.dart';
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
    // the day's list taken at most once in five seconds: every poll (two seconds) rebuilt the page from the day's
    // thousands of connections, 35-55 ms of the UI thread each time, a jerk of whatever moved
    final shown = useState<ConnectionsState?>(null);
    final taken = useRef(DateTime.fromMillisecondsSinceEpoch(0));
    final waiting = useRef<Timer?>(null);
    void take() {
      waiting.value = null;
      taken.value = DateTime.now();
      if (context.mounted) shown.value = ref.read(connectionsProvider);
    }

    ref.listen(connectionsProvider, (_, _) {
      if (!visible || waiting.value != null) return;
      final since = DateTime.now().difference(taken.value);
      const every = Duration(seconds: 5);
      since >= every ? take() : waiting.value = Timer(every - since, take);
    });
    useEffect(
      () =>
          () => waiting.value?.cancel(),
      const [],
    );
    // shown again (the tab picked): the list as it is now
    useEffect(() {
      if (visible) WidgetsBinding.instance.addPostFrameCallback((_) => take());
      return null;
    }, [visible]);
    final ConnectionsState state = shown.value ?? ref.read(connectionsProvider);
    final byTraffic = useState(true);
    final controller = useScrollController();
    // which page: only the title follows it (a state here rebuilt the whole page, the flows' picture laid out and
    // drawn again, as the scroll crossed the middle: a jerk between the two pages)
    final onSecondPage = useValueNotifier(false);
    useEffect(() {
      void follow() {
        final second = controller.hasClients && controller.offset > 200;
        if (second != onSecondPage.value) onSecondPage.value = second;
      }

      controller.addListener(follow);
      return () => controller.removeListener(follow);
    }, [controller]);
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
    // the ones that moved something, the closed ones too (dimmed on the picture): a connection under 20 KB is
    // background chatter, not a flow
    final rates = state.rates;
    // (a closed one stays ten minutes, as on the picture)
    final now = DateTime.now();
    final openNow = open
        .where(
          (c) =>
              c.route != ConnectionRoute.block &&
              c.total >= flowMinBytes &&
              (c.active || (c.ended != null && now.difference(c.ended!) <= const Duration(minutes: 10))),
        )
        .toList();
    String speedValue(double w) => '${formatBytes(w.round(), units)}/${t.avpn.perSecond}';
    double weight(SeenConnection c) => byTraffic.value ? c.total.toDouble() : c.count.toDouble();
    String value(double w) => byTraffic.value ? formatBytes(w.round(), units) : '${w.round()}';
    final total = items.fold<double>(0, (s, c) => s + weight(c));
    double sum(Iterable<SeenConnection> cs) => cs.fold<double>(0, (s, c) => s + weight(c));
    // a rule and the way it sent its traffic: the same list can send some of it through the VPN and some direct
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final rules = groupConnections(
      items,
      (c) => '${c.route.index}${ruleLabel(c.rule, t, apps: apps) ?? t.avpn.connRuleDefault}',
    );

    // what moved since the list started (03:00, or the last clearing) against what the list holds: connections
    // shorter than one poll and the ones while the app was closed aren't in the list
    // (the total follows the counters every second in a widget of its own, below: the whole page rebuilt every
    // second for it)
    final listed = state.items.where((c) => c.route != ConnectionRoute.block).fold<int>(0, (s, c) => s + c.total);

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
        title: ValueListenableBuilder<bool>(
          valueListenable: onSecondPage,
          builder: (context, second, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.avpn.topologyTab),
              // the first page is what is open now; the day is the second page's
              if (second)
                Text(t.avpn.topoPeriod, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        actions: [
          // starts the picture over from now; it starts over by itself at 03:00
          if (state.items.any((c) => !c.active))
            IconButton(
              tooltip: t.avpn.connClear,
              icon: clearIcon(),
              onPressed: () => ref.read(connectionsProvider.notifier).clearClosed(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          // two pages in one scroll: the flows over the whole screen down to the panel, then the rest under them
          child: LayoutBuilder(
            builder: (context, box) {
              final pageHeight = box.maxHeight;
              // the toggle and the gaps over the card; the card's own title and padding inside it
              // the chart takes what the page leaves (see the section below)
              return ListView(
                controller: controller,
                physics: _PageSnap(pageHeight),
                // both pages kept built: a fast flick threw the far one away and built it again on the way back (the
                // flows' picture, its icons, the dotted strips, the rules with their flags), a jerk at every flick
                cacheExtent: pageHeight * 4,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  SizedBox(
                    height: pageHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        const Gap(8),
                        // the connections open now, as a flow: apps, the rules that took them, where they went
                        Expanded(
                          child: _Section(
                            expand: true,
                            solid: true,
                            title: t.avpn.topoSankey,
                            trailing: _FlowLegend(live: t.avpn.flowLive, closed: t.avpn.flowClosed),
                            child: openNow.isEmpty
                                ? Center(
                                    child: Text(
                                      t.avpn.topoSankeyEmpty,
                                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  )
                                : LayoutBuilder(
                                    // its running dots in a layer of their own: they repainted the whole page
                                    builder: (context, box) => RepaintBoundary(
                                      child: TrafficSankey(
                                        items: openNow,
                                        height: box.maxHeight,
                                        // who goes where, as thick as every other route and in a fixed order; the traffic and
                                        // the speed are written
                                        weight: (c) => byTraffic.value ? c.total.toDouble() : c.count.toDouble(),
                                        value: value,
                                        speed: byTraffic.value ? (c) => rates[c.id] ?? 0 : null,
                                        speedValue: byTraffic.value ? speedValue : null,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        // the next page is below, as in the statistics
                        const Gap(4),
                        Center(child: Icon(Icons.keyboard_arrow_down_rounded, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const Gap(12),
                  // what moved by the core's counters (all of it); the lists below hold only the connections the app saw
                  if (byTraffic.value)
                    Consumer(
                      builder: (context, ref, _) {
                        if (visible) ref.watch(trafficHistoryProvider);
                        final moved = ref
                            .read(trafficHistoryProvider.notifier)
                            .amountFrom(state.since ?? statsDayStart(DateTime.now()));
                        final sessionAll = moved.total;
                        if (sessionAll <= 0) return const SizedBox.shrink();
                        final uncounted = sessionAll - listed;
                        final showUncounted = uncounted > smallTraffic && uncounted > sessionAll * .05;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TopologyDayTotal(
                            total: formatBytes(sessionAll, units),
                            vpn: formatBytes(moved.vpn, units),
                            direct: formatBytes(math.max(0, sessionAll - moved.vpn), units),
                            listed: showUncounted ? formatBytes(listed, units) : null,
                          ),
                        );
                      },
                    ),
                  _Section(
                    title: t.avpn.topoFlow,
                    // a layer of its own: the page scrolls without drawing the strips again
                    child: RepaintBoundary(
                      child: TrafficStrips(items: items, weight: weight, value: value),
                    ),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The first page rests whole on the screen, the second under it: a scroll that lets go between them goes to the
/// nearer one (a quick flick goes the way it was thrown).
class _PageSnap extends ScrollPhysics {
  const _PageSnap(this.page, {super.parent});

  final double page;

  @override
  _PageSnap applyTo(ScrollPhysics? ancestor) => _PageSnap(page, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final far = math.min(page, position.maxScrollExtent);
    if (position.pixels >= far || position.pixels <= 0 && velocity <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = velocity.abs() > 250 ? (velocity > 0 ? far : 0.0) : (position.pixels > far / 2 ? far : 0.0);
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: toleranceFor(position));
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
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final rules = groupConnections(
      session,
      (c) => '${c.route.index}${ruleLabel(c.rule, t, apps: apps) ?? t.avpn.connRuleDefault}',
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

/// All the traffic since the day's start by the core's counters: the figure, how it split between the VPN and
/// direct, and (when the lists hold much less) what the breakdown under it covers.
class TopologyDayTotal extends ConsumerWidget {
  const TopologyDayTotal({super.key, required this.total, required this.vpn, required this.direct, this.listed});

  final String total;
  final String vpn;
  final String direct;
  final String? listed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Section(
      title: t.avpn.topoDayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(total, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Gap(2),
          Text(
            t.avpn.topoDayDetail(vpn: vpn, direct: direct),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (listed != null) ...[
            const Gap(8),
            Text(
              t.avpn.topoDayGap(listed: listed!),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.hint,
    this.expand = false,
    this.trailing,
    this.solid = false,
  });

  /// a pane with only a little see-through left in it, instead of the frosted glass

  /// the child takes the height the section is given (the section must be given one)
  final bool expand;
  final bool solid;

  /// at the right end of the title's line
  final Widget? trailing;
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleText = Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        trailing == null
            ? titleText
            : Row(
                children: [
                  Expanded(child: titleText),
                  trailing!,
                ],
              ),
        if (hint != null) ...[
          const Gap(3),
          Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        const Gap(10),
        if (expand) Expanded(child: child) else child,
      ],
    );
    // the same frosted glass as the home screen's blocks
    if (solid) {
      final dark = theme.brightness == Brightness.dark;
      // Bento and Dots: their own card
      final own = lookCard(
        homeLookNow,
        dark,
        child: content,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        radius: 18,
      );
      if (own != null) return own;
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: ContrastColours.of(context).pane(dark).withValues(alpha: dark ? .94 : .93),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .7)),
        ),
        child: content,
      );
    }
    return ContrastFrost(radius: 18, padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), solo: true, child: content);
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
                                    child: homeLookNow == HomeLayout.dots
                                        ? flagsText(
                                            way,
                                            width: 17,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: colour,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : Text(
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

/// The key of the flows picture: lit ones are open now, faint ones have closed.
class _FlowLegend extends StatelessWidget {
  const _FlowLegend({required this.live, required this.closed});

  final String live;
  final String closed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 10);
    Widget dot(Color colour, {bool hollow = false}) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hollow ? null : colour,
        border: hollow ? Border.all(color: colour.withValues(alpha: .6), width: 1.4) : null,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(theme.araAccent),
        const Gap(4),
        Text(live, style: style),
        const Gap(10),
        dot(muted, hollow: true),
        const Gap(4),
        Text(closed, style: style),
      ],
    );
  }
}
