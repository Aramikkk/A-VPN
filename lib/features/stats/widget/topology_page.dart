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
    // the servers' period: session, day, month, all the time (the last, to begin with)
    final period = useState(3);
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
    String value(double w) => byTraffic.value ? formatBytes(w.round(), units) : '${w.round()}';
    // the servers the VPN traffic went through and the direct share, over the period: how much each moved and how long
    // it had a connection open (the servers under 10 MB aren't shown)
    final totals = state.totals;
    final bucket = switch (period.value) {
      0 => totals.session,
      1 => totals.day,
      2 => totals.month,
      _ => totals.all,
    };
    double serverWeight(({int bytes, int ms, int count}) e) =>
        byTraffic.value ? e.bytes.toDouble() : e.count.toDouble();
    final directWeight = byTraffic.value ? bucket.directBytes.toDouble() : bucket.directCount.toDouble();
    final rows = <({String name, double weight, Duration? time, bool direct})>[
      for (final e in bucket.servers.entries)
        if (e.value.bytes >= TopologyServers.smallest)
          (name: e.key, weight: serverWeight(e.value), time: Duration(milliseconds: e.value.ms), direct: false),
      if (bucket.directBytes > 0)
        (name: '$directFlag ${t.avpn.statsDirect}', weight: directWeight, time: null, direct: true),
    ]..sort((a, b) => b.weight.compareTo(a.weight));
    final everything = bucket.servers.values.fold<double>(directWeight, (sum, e) => sum + serverWeight(e));

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
        // the first page is the topology, the one under it the servers
        title: ValueListenableBuilder<bool>(
          valueListenable: onSecondPage,
          builder: (context, second, _) => Text(second ? t.avpn.topoServers : t.avpn.topologyTab),
        ),
        // the servers' reset, only on their page
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: onSecondPage,
            builder: (context, second, _) => second
                ? IconButton(
                    icon: const Icon(Icons.restart_alt_rounded),
                    tooltip: t.avpn.topoServersReset,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(t.avpn.topoServersResetAsk),
                          content: Text(t.avpn.topoServersResetBody),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.common.cancel)),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(t.avpn.topoServersReset),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) ref.read(connectionsProvider.notifier).resetServerTotals();
                    },
                  )
                : const SizedBox.shrink(),
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
                                        // counted: the size of a step is one connection, and no 100 KB cut
                                        unit: byTraffic.value ? 20480 : 1,
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
                        // the name of the page under this one, the arrow before it
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.keyboard_arrow_down_rounded, color: scheme.onSurfaceVariant),
                            const Gap(4),
                            Text(
                              t.avpn.topoServers,
                              style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  // the servers the VPN traffic went through, and the direct share
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: pageHeight - 12),
                    child: _Section(
                      child: TopologyServers(
                        rows: rows,
                        total: everything,
                        period: period.value,
                        onPeriod: (value) => period.value = value,
                        since: totals.since,
                        value: value,
                      ),
                    ),
                  ),
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

/// The servers the VPN traffic went through (a country each in the usual case) and the direct traffic, ranked
/// together by what they moved over a period: the amount, the share of the whole, and how long a server had a
/// connection open. The totals are kept until the user resets them.
class TopologyServers extends ConsumerWidget {
  const TopologyServers({
    super.key,
    required this.rows,
    required this.total,
    required this.period,
    required this.onPeriod,
    required this.since,
    required this.value,
  });

  /// a server that moved less than this isn't shown
  static const smallest = 10 * 1024 * 1024;

  /// the biggest first
  final List<({String name, double weight, Duration? time, bool direct})> rows;
  final double total;

  /// 0 session, 1 day, 2 month, 3 all the time
  final int period;
  final ValueChanged<int> onPeriod;
  final DateTime? since;
  final String Function(double) value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = scheme.surfaceContainerLow;
    final dots = homeLookNow == HomeLayout.dots;
    final vpnColour = AraLook.readableOn(scheme.primary, surface);
    final directColour = AraLook.readableOn(const Color(0xFF9AA0A6), surface);
    String two(int n) => n.toString().padLeft(2, '0');
    String time(Duration d) => d.inHours > 0
        ? t.avpn.topoTimeHm(h: d.inHours, m: d.inMinutes % 60)
        : (d.inMinutes > 0 ? t.avpn.topoTimeM(m: d.inMinutes) : t.avpn.topoTimeLess);
    final top = rows.isEmpty ? 0.0 : rows.first.weight;
    Widget row(({String name, double weight, Duration? time, bool direct}) r) {
      // "🇸🇪 Швеция 2 · БС": the mark moves to a frame of its own
      final whitelist = r.name.contains('БС');
      final name = whitelist ? r.name.replaceAll(RegExp(r'\s*·?\s*БС'), '').trim() : r.name;
      final colour = r.direct ? directColour : vpnColour;
      final share = total <= 0 ? 0.0 : r.weight / total;
      final spent = r.time;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: dots
                            ? flagsText(
                                name,
                                width: 17,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              )
                            : Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                      ),
                      // a whitelist server: a white frame, so it isn't taken for the country's regular one
                      if (whitelist) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 1.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.avpn.topoWhitelist,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(8),
                Text(value(r.weight), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    // no time recorded (it is kept from this version on): nothing is written
                    spent == null || spent == Duration.zero ? '' : time(spent),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  '${(share * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Gap(5),
            if (dots)
              DotBar(colour: colour, lit: top <= 0 ? 0 : r.weight / top)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(homeLookNow == HomeLayout.bento ? 5 : 4),
                child: LinearProgressIndicator(
                  value: top <= 0 ? 0 : r.weight / top,
                  minHeight: homeLookNow == HomeLayout.bento ? 10 : 6,
                  color: colour,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // the period: the session, the day (from 03:00), the last 30 days, or all the time since the last reset
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
          ),
          segments: [
            ButtonSegment(value: 0, label: Text(t.avpn.topoPeriodSession, maxLines: 1)),
            ButtonSegment(value: 1, label: Text(t.avpn.topoPeriodDay, maxLines: 1)),
            ButtonSegment(value: 2, label: Text(t.avpn.topoPeriodMonth, maxLines: 1)),
            ButtonSegment(value: 3, label: Text(t.avpn.topoPeriodAll, maxLines: 1)),
          ],
          selected: {period},
          onSelectionChanged: (s) => onPeriod(s.first),
        ),
        const Gap(14),
        Row(
          children: [
            Expanded(
              child: Text(
                period == 3 && since != null
                    ? t.avpn.topoServersSince(
                        date:
                            '${two(since!.day)}.${two(since!.month)}.${since!.year % 100} ${two(since!.hour)}:${two(since!.minute)}',
                      )
                    : '',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Text(value(total), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        const Gap(6),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              t.avpn.topoServersNone,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final r in rows) row(r),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.child, this.expand = false, this.trailing, this.solid = false});

  /// a pane with only a little see-through left in it, instead of the frosted glass

  /// the child takes the height the section is given (the section must be given one)
  final bool expand;
  final bool solid;

  /// at the right end of the title's line
  final Widget? trailing;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleText = Text(
      (title ?? '').toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          trailing == null
              ? titleText
              : Row(
                  children: [
                    Expanded(child: titleText),
                    trailing!,
                  ],
                ),
          const Gap(10),
        ],
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
