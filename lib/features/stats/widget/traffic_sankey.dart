import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/profile/widget/profile_badge.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A connection that moved less than this is background chatter, and the flow diagram leaves it out.
const flowMinBytes = 20 * 1024;

/// One stretch of traffic: which app, under which rule, where it went (a server, direct or blocked), and how much.
/// [host] and [count] are for the details of a route.
class SankeyFlow {
  const SankeyFlow({
    required this.app,
    required this.rule,
    required this.out,
    required this.route,
    required this.weight,
    this.host = '',
    this.count = 1,
    this.site = '',
    this.speed = 0,
    this.id = '',
    this.live = true,
    this.closedAt,
  });

  /// when its connection closed (null: open, or not known)
  final DateTime? closedAt;

  /// open now (a closed one is still drawn, but dimmed)
  final bool live;

  /// the connection it is (empty when the flows aren't connections)
  final String id;

  /// the same flow, still on the picture after its connection closed: no speed any more
  SankeyFlow held() => SankeyFlow(
    app: app,
    rule: rule,
    out: out,
    route: route,
    weight: weight,
    host: host,
    count: count,
    site: site,
    speed: 0,
    id: id,
    live: false,
    closedAt: closedAt ?? DateTime.now(),
  );

  /// the middle column's name (the site, as a domain); empty: the rule's
  final String site;
  String get middle => site.isEmpty ? rule : site;

  /// bytes a second now
  final double speed;

  final String app;
  final String rule;
  final String out;
  final ConnectionRoute route;
  final double weight;
  final String host;
  final int count;

  /// the thickness it is given on the picture: the logarithm of its weight in [unit]s, so one huge flow doesn't
  /// swallow the others (the amounts written stay the real ones)
  double shownAt(double unit) => math.log(1 + weight / unit);

  double get shown => shownAt(flowMinBytes.toDouble());
}

class SankeyNode {
  SankeyNode(this.key, this.label, this.route, this.column);

  final String key;
  final String label;
  final int column;

  /// the way the traffic of a rule or a destination went (null for an app: it can send in several ways)
  final ConnectionRoute? route;

  /// on the picture (the flows' square roots added up)
  double weight = 0;

  /// the real amount (what is written)
  double get real => flows.fold<double>(0, (s, f) => s + f.weight);

  /// the speed now of what makes the node up
  double get speed => flows.fold<double>(0, (s, f) => s + f.speed);
  double y = 0;
  double h = 0;
  final outLinks = <SankeyLink>[];
  final inLinks = <SankeyLink>[];

  /// the flows that make this node up (a flow is in one node of each column)
  final flows = <SankeyFlow>{};
}

class SankeyLink {
  SankeyLink(this.from, this.to, this.route);

  final SankeyNode from;
  final SankeyNode to;
  final ConnectionRoute route;

  /// on the picture
  double weight = 0;
  double fromY = 0;
  double toY = 0;
  final flows = <SankeyFlow>{};
}

/// The flow diagram's data: three columns (apps, rules, destinations) and the ribbons between them, each as thick
/// as the traffic it carries. Only the biggest of each column are kept, the rest added up in one "other" node.
class SankeyModel {
  SankeyModel._(this.columns, this.links, this.total, this.maxUnit, {this.calm = false});

  /// calm: the nodes keep one size and sit from the top at a fixed distance, so that nothing slides about when a
  /// route comes or goes (the usual layout spreads each column over the whole height)
  final bool calm;

  /// Puts each column in the order the nodes were first seen (new ones last) instead of by name: [order] holds the
  /// places so far and gets the new nodes' places.
  void keepOrder(Map<String, int> order) {
    for (final column in columns) {
      for (final n in column) {
        order.putIfAbsent(n.key, () => order.length);
      }
      column.sort((a, b) => order[a.key]!.compareTo(order[b.key]!));
    }
  }

  /// the thickest a unit of weight may be drawn (no limit when null): with few links they stay slim, not huge
  final double? maxUnit;

  final List<List<SankeyNode>> columns;
  final List<SankeyLink> links;
  final double total;

  bool get isEmpty => total <= 0;

  int get widest => columns.map((c) => c.length).fold<int>(0, math.max);

  static SankeyModel build(
    Iterable<SankeyFlow> flows, {
    required String otherApp,
    required String otherRule,
    required String otherOut,
    int top = 6,
    double minShare = .02,

    /// what one step of the scale is: bytes (the smallest flow shown) or one connection
    double unit = 20480,

    /// every route (an app to a site to a destination) as thick as any other, and the nodes in a fixed order
    /// (by name): nothing changes size or place as the traffic moves, only what is written
    bool even = false,
    bool calm = false,
  }) {
    final list = flows.where((f) => f.weight > 0).toList();
    // what a flow weighs on the picture: one route, one unit (even), or the logarithm of its traffic
    final seenRoutes = <String>{};
    double shown(SankeyFlow f, String routeKey) {
      if (!even) return f.shownAt(unit);
      return seenRoutes.add(routeKey) ? 1 : 0;
    }

    var total = 0.0;
    if (even) {
      total = list.map((f) => '${f.app}|${f.middle}|${f.route.index}|${f.out}').toSet().length.toDouble();
    } else {
      total = list.fold<double>(0, (s, f) => s + f.shownAt(unit));
    }
    if (total <= 0) return SankeyModel._(const [[], [], []], const [], 0, null);

    // a column keeps the biggest keys that are worth a node, everything else goes to its "other"
    Set<String> keep(String Function(SankeyFlow) keyOf) {
      final by = <String, double>{};
      for (final f in list) {
        by[keyOf(f)] = (by[keyOf(f)] ?? 0) + (even ? f.weight : f.shownAt(unit));
      }
      final ranked = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return {
        for (final e in ranked.take(top))
          if (even || e.value >= total * minShare) e.key,
      };
    }

    String ruleKey(SankeyFlow f) => '${f.route.index}|${f.middle}';
    String outKey(SankeyFlow f) => '${f.route.index}|${f.out}';
    final apps = keep((f) => f.app);
    final rules = keep(ruleKey);
    // "direct" and "blocked" are one destination each, always shown; the servers are ranked
    final outs = keep(outKey)..addAll([for (final f in list) if (f.route != ConnectionRoute.vpn) outKey(f)]);

    final nodes = <String, SankeyNode>{};
    SankeyNode node(String key, String label, ConnectionRoute? route, int column) =>
        nodes.putIfAbsent(key, () => SankeyNode(key, label, route, column));
    final links = <String, SankeyLink>{};
    SankeyLink link(SankeyNode a, SankeyNode b, ConnectionRoute route) =>
        links.putIfAbsent('${a.key}>${b.key}', () => SankeyLink(a, b, route));

    for (final f in list) {
      final a = apps.contains(f.app) ? node('a|${f.app}', f.app, null, 0) : node('a|', otherApp, null, 0);
      final r = rules.contains(ruleKey(f))
          ? node('r|${ruleKey(f)}', f.middle, f.route, 1)
          : node('r|${f.route.index}|', otherRule, f.route, 1);
      final o = outs.contains(outKey(f))
          ? node('o|${outKey(f)}', f.out, f.route, 2)
          : node('o|${f.route.index}|', otherOut, f.route, 2);
      for (final n in [a, r, o]) {
        n.flows.add(f);
      }
      final weight = shown(f, '${a.key}|${r.key}|${o.key}');
      for (final l in [link(a, r, f.route), link(r, o, f.route)]) {
        l.weight += weight;
        l.flows.add(f);
      }
    }
    for (final l in links.values) {
      l.from.outLinks.add(l);
      l.to.inLinks.add(l);
    }
    for (final n in nodes.values) {
      n.weight = math.max(
        n.outLinks.fold<double>(0, (s, l) => s + l.weight),
        n.inLinks.fold<double>(0, (s, l) => s + l.weight),
      );
    }

    List<SankeyNode> column(int index) =>
        nodes.values.where((n) => n.column == index).toList()..sort((a, b) {
          if (index > 0) {
            final r = a.route!.index.compareTo(b.route!.index);
            if (r != 0) return r;
          }
          // "other" last within its group
          final aOther = a.key.endsWith('|');
          final bOther = b.key.endsWith('|');
          if (aOther != bOther) return aOther ? 1 : -1;
          if (even) return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          return b.weight.compareTo(a.weight);
        });
    return SankeyModel._([column(0), column(1), column(2)], links.values.toList(), total, even ? (calm ? 22 : 44) : null, calm: calm);
  }

  /// Places the nodes in [height] (each column fills it, the room not taken by nodes shared between them as gaps)
  /// and the ribbons' ends along the nodes' sides, ordered by where they go so they cross as little as they can.
  /// Edges sit on whole pixels, so they stay crisp.
  void layout(double height, {double minGap = 6}) {
    if (isEmpty) return;
    final gapBetween = calm ? 10.0 : minGap;
    // what the columns really hold (the routes joined in an "other" node count once), so the picture fills the height
    final routes = columns.first.fold<double>(0, (s, n) => s + n.weight);
    var k = (height - gapBetween * (widest - 1)) / (routes > 0 ? routes : total);
    // calm: a route is at most an eighth of the height thick, so a few routes fill the page and many fit on it
    final cap = calm && maxUnit != null ? ((height - 12) / 8).clamp(22.0, 64.0) : maxUnit;
    if (cap != null && k > cap) k = cap;
    for (final column in columns) {
      if (column.isEmpty) continue;
      final used = column.fold<double>(0, (s, n) => s + n.weight * k);
      // calm: from the top at a fixed distance; otherwise each column spread over the whole height
      final gap = calm ? gapBetween : (column.length > 1 ? (height - used) / (column.length - 1) : 0.0);
      var y = calm || column.length > 1 ? 0.0 : (height - used) / 2;
      for (final n in column) {
        n.y = y;
        n.h = n.weight * k;
        y += n.h + gap;
      }
    }
    for (final n in columns.expand((c) => c)) {
      var y = n.y;
      for (final l in n.outLinks..sort((a, b) => a.to.y.compareTo(b.to.y))) {
        l.fromY = y;
        y += l.weight * k;
      }
      y = n.y;
      for (final l in n.inLinks..sort((a, b) => a.from.y.compareTo(b.from.y))) {
        l.toY = y;
        y += l.weight * k;
      }
    }
    _k = k;
  }

  double _k = 0;

  /// a ribbon's thickness in pixels
  double thickness(SankeyLink l) => l.weight * _k;
}

/// Where the columns stand in a width: the apps' names on the left, the nodes, the servers' names on the right.
class SankeyGeometry {
  SankeyGeometry(double width) {
    final labelL = math.min(88.0, width * .24);
    labelR = math.min(70.0, width * .19);
    this.labelL = labelL;
    final x2 = width - labelR - nodeW;
    xs = [labelL, (labelL + x2) / 2, x2];
  }

  static const nodeW = 6.0;

  /// the room over the nodes for the columns' names
  static const headerH = 20.0;
  late final double labelL;
  late final double labelR;
  late final List<double> xs;

  Path ribbon(SankeyModel model, SankeyLink l) {
    final xa = xs[l.from.column] + nodeW;
    final xb = xs[l.to.column];
    final th = model.thickness(l);
    final mid = (xa + xb) / 2;
    return Path()
      ..moveTo(xa, l.fromY)
      ..cubicTo(mid, l.fromY, mid, l.toY, xb, l.toY)
      ..lineTo(xb, l.toY + th)
      ..cubicTo(mid, l.toY + th, mid, l.fromY + th, xa, l.fromY + th)
      ..close();
  }

  /// the area that takes a tap for a node: the node and its name, at least a finger's height
  Rect hit(SankeyNode n, double width) {
    final h = math.max(n.h, 22.0);
    final top = n.y + n.h / 2 - h / 2;
    return switch (n.column) {
      0 => Rect.fromLTWH(0, top, xs[0] + nodeW + 4, h),
      1 => Rect.fromLTWH(xs[1] - 4, top, (xs[2] - xs[1]) * .8, h),
      _ => Rect.fromLTWH(xs[2] - 4, top, width - xs[2] + 4, h),
    };
  }
}

/// What was tapped: a node, or a ribbon between two, with the flows it holds.
class SankeySelection {
  const SankeySelection({required this.title, required this.route, required this.flows, required this.total});

  final String title;
  final ConnectionRoute? route;
  final Set<SankeyFlow> flows;

  /// all the diagram holds, for the share
  final double total;

  double get weight => flows.fold<double>(0, (s, f) => s + f.weight);
  double get speed => flows.fold<double>(0, (s, f) => s + f.speed);
  int get connections => flows.fold<int>(0, (s, f) => s + f.count);
}

/// The traffic as a flow diagram: apps on the left, the rules that took them in the middle, and where it went (a
/// server, direct, blocked) on the right; each ribbon as thick as its traffic, in the way's colour. A tap on a
/// route shows its details.
class TrafficSankey extends ConsumerWidget {
  const TrafficSankey({
    super.key,
    required this.items,
    required this.weight,
    required this.value,
    this.height,
    this.unit = 20480,
    this.speed,
    this.speedValue,
  });

  /// one step of the thickness scale: bytes, or 1 when connections are counted
  final double unit;

  /// a connection's speed now (bytes a second), and how it is written; null: no speeds
  final double Function(SeenConnection c)? speed;
  final String Function(double bytesPerSecond)? speedValue;

  /// null: by how many names the widest column holds
  final double? height;

  final List<SeenConnection> items;
  final double Function(SeenConnection c) weight;
  final String Function(double w) value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final flows = <SankeyFlow>[
      for (final c in items)
        SankeyFlow(
          app: c.app.isEmpty ? t.avpn.connUnknownApp : connectionAppName(t, apps, c.app),
          rule: ruleLabel(c.rule, t, apps: apps) ?? t.avpn.connRuleDefault,
          out: switch (c.route) {
            ConnectionRoute.vpn => c.outbound.isEmpty ? t.avpn.statsViaVpn : c.outbound,
            ConnectionRoute.direct => t.avpn.statsDirect,
            ConnectionRoute.block => t.avpn.connBlocked,
          },
          route: c.route,
          weight: weight(c),
          host: c.host,
          count: c.count,
          site: siteOf(c.host),
          speed: speed?.call(c) ?? 0,
          id: c.id,
          live: c.active,
          closedAt: c.ended,
        ),
    ];
    return SankeyDiagram(
      flows: flows,
      value: value,
      height: height,
      unit: unit,
      even: true,
      calm: true,
      look: SankeyLook.dots,
      speedValue: speedValue,
      headers: [t.avpn.sankeyApps, t.avpn.sankeySites, t.avpn.sankeyTo],
      otherApp: t.avpn.connOther,
      otherRule: t.avpn.connOther,
      otherOut: t.avpn.connOther,
      onSelect: (selection) async => showGlassPopup(
        context,
        SankeyDetails(selection: selection, value: value, speedValue: speedValue),
      ),
    );
  }
}

/// How the routes are drawn in the ribbons view.
enum SankeyLook {
  /// wide translucent ribbons
  ribbons,

  /// thin curves, the colour running from the app to the server
  thin,

  /// ribbons, the open ones with a soft glow along them
  glow,

  /// ribbons with right-angle steps instead of curves
  steps,

  /// thin curves with dots running along the ones in use
  dots,

  /// open: solid ribbons; closed: only a dashed outline
  dashed,
}

/// The diagram itself, from flows already named (the preview and the tests draw it without any providers).
class SankeyDiagram extends StatefulWidget {
  const SankeyDiagram({
    super.key,
    required this.flows,
    required this.value,
    required this.otherApp,
    required this.otherRule,
    required this.otherOut,
    this.height,
    this.unit = 20480,
    this.even = false,
    this.calm = false,
    this.chips = false,
    this.look = SankeyLook.ribbons,
    this.speedValue,
    this.headers = const [],
    this.onSelect,
    this.initialSelection,
  });

  final double unit;

  /// every route as thick as any other, in a fixed order: only the written amounts change
  final bool even;

  /// chips: each node a plate of one size in a row of its own, joined by thin lines (a dot where it moves), instead
  /// of ribbons as wide as the traffic; the rows start from the top and keep their places (needs [calm] data)
  final bool chips;

  /// how the routes are drawn (ribbons view)
  final SankeyLook look;

  /// calm: fixed sizes from the top, the nodes in the order they came, a route kept a few seconds after its
  /// connection closed (see [SankeyModel.calm])
  final bool calm;

  /// a speed (bytes a second) as written, or null when there are no speeds to show
  final String Function(double bytesPerSecond)? speedValue;

  /// the three columns' names (apps, sites, where it goes)
  final List<String> headers;

  final List<SankeyFlow> flows;
  final String Function(double w) value;
  final String otherApp;
  final String otherRule;
  final String otherOut;

  /// null: by how many nodes the widest column has, so each name has its line
  final double? height;

  /// called with what was tapped; the diagram keeps it lit until this is done
  final Future<void> Function(SankeySelection selection)? onSelect;

  /// for the preview: a node lit from the start (a node's key, "a|Chrome")
  final String? initialSelection;

  @override
  State<SankeyDiagram> createState() => _SankeyDiagramState();
}

class _SankeyDiagramState extends State<SankeyDiagram> with SingleTickerProviderStateMixin {
  late SankeyModel _model;

  /// 0..1 round and round: a light runs along the ribbons where traffic moves, and they breathe (stopped while
  /// nothing moves, so an idle diagram costs nothing)
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  void _syncPulse() {
    final moving = _model.links.any(_movingLink);
    if (moving && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!moving && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Set<SankeyFlow> _lit = const {};

  /// the places the nodes took in the order they came (calm)
  final _order = <String, int>{};

  /// the flows seen lately, by connection, and when each was last open (calm)
  final _held = <String, ({SankeyFlow flow, DateTime seen})>{};

  /// how long a route stays after its connection closed (calm)
  static const _hold = Duration(seconds: 8);

  /// how long a closed connection stays on the picture
  static const _closedKeep = Duration(minutes: 10);

  SankeyModel _build() {
    var flows = widget.flows;
    if (widget.calm) {
      final now = DateTime.now();
      // a closed one stays ten minutes (one whose closing isn't known is an old one: gone)
      flows = [
        for (final f in flows)
          if (f.live || (f.closedAt != null && now.difference(f.closedAt!) <= _closedKeep)) f,
      ];
      final present = <String>{};
      for (final (i, f) in flows.indexed) {
        final key = f.id.isEmpty ? '#$i' : f.id;
        present.add(key);
        _held[key] = (flow: f, seen: now);
      }
      _held.removeWhere((key, v) => !present.contains(key) && now.difference(v.seen) > _hold);
      flows = [for (final e in _held.entries) present.contains(e.key) ? e.value.flow : e.value.flow.held()];
      // as many routes as the height holds: the open ones first, then the closed by how lately they closed, so the
      // oldest give way to newer ones
      final room = (((widget.height ?? 500) - SankeyGeometry.headerH) / 30).floor().clamp(6, 40);
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      flows.sort((a, b) {
        if (a.live != b.live) return a.live ? -1 : 1;
        return (b.closedAt ?? epoch).compareTo(a.closedAt ?? epoch);
      });
      final routes = <String>{};
      flows = [
        for (final f in flows)
          if (routes.contains('${f.app}|${f.middle}|${f.route.index}|${f.out}') ||
              (routes.length < room && routes.add('${f.app}|${f.middle}|${f.route.index}|${f.out}')))
            f,
      ];
    }
    // chips: as many rows as the height holds, the last of them "other"
    final rows = widget.chips ? (((widget.height ?? 500) - _ChipsLayout.headerH) / _ChipsLayout.pitch).floor() : 9;
    final model = SankeyModel.build(
      flows,
      otherApp: widget.otherApp,
      otherRule: widget.otherRule,
      otherOut: widget.otherOut,
      unit: widget.unit,
      even: widget.even,
      calm: widget.calm,
      top: widget.chips ? math.max(2, rows - 3) : (widget.calm ? 9 : 6),
    );
    if (widget.calm) model.keepOrder(_order);
    return model;
  }

  @override
  void initState() {
    super.initState();
    _model = _build();
    _syncPulse();
    final key = widget.initialSelection;
    if (key != null) {
      final node = _model.columns.expand((c) => c).where((n) => n.key == key).firstOrNull;
      if (node != null) _lit = node.flows;
    }
  }

  @override
  void didUpdateWidget(SankeyDiagram old) {
    super.didUpdateWidget(old);
    _model = _build();
    _syncPulse();
  }

  Future<void> _select(SankeySelection selection) async {
    setState(() => _lit = selection.flows);
    await widget.onSelect?.call(selection);
    if (mounted) setState(() => _lit = const {});
  }

  void _tap(Offset at, double width, double height) {
    final geometry = SankeyGeometry(width);
    _model.layout(height - SankeyGeometry.headerH);
    at = at.translate(0, -SankeyGeometry.headerH);
    for (final n in _model.columns.expand((c) => c)) {
      if (geometry.hit(n, width).contains(at)) {
        unawaited(_select(SankeySelection(title: n.label, route: n.route, flows: n.flows, total: _model.total)));
        return;
      }
    }
    // a ribbon: the thinnest first, so a thin one under a thick one can still be got
    final links = [..._model.links]..sort((a, b) => a.weight.compareTo(b.weight));
    for (final l in links) {
      if (geometry.ribbon(_model, l).contains(at)) {
        unawaited(
          _select(
            SankeySelection(title: '${l.from.label} → ${l.to.label}', route: l.route, flows: l.flows, total: _model.total),
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_model.isEmpty) return const SizedBox(height: 120);
    // a line of 40 for each name in the widest column, so the names never meet
    final height = widget.height ?? (60 + 40.0 * _model.widest).clamp(260.0, 500.0);
    if (widget.chips) {
      return _ChipsView(
        model: _model,
        height: height,
        lit: _lit,
        value: widget.value,
        speedValue: widget.speedValue,
        headers: widget.headers,
        onNode: widget.onSelect == null
            ? null
            : (n) => unawaited(_select(SankeySelection(title: n.label, route: n.route, flows: n.flows, total: _model.total))),
        onLink: widget.onSelect == null
            ? null
            : (l) => unawaited(
                _select(
                  SankeySelection(title: '${l.from.label} → ${l.to.label}', route: l.route, flows: l.flows, total: _model.total),
                ),
              ),
      );
    }
    final colours = (
      vpn: theme.araAccent,
      direct: const Color(0xFF9AA0A6),
      block: scheme.error,
      app: scheme.onSurfaceVariant,
      ink: scheme.onSurface,
      soft: scheme.onSurfaceVariant,
      halo: scheme.surfaceContainerLow,
    );
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onSelect == null ? null : (d) => _tap(d.localPosition, box.maxWidth, height),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SankeyPainter(
              _model,
              colours,
              widget.value,
              theme.textTheme.labelSmall?.fontFamily,
              theme.brightness,
              _lit,
              widget.headers,
              widget.speedValue,
              _pulse,
              widget.look,
            ),
          ),
        ),
      ),
    );
  }
}

/// A server's name as its flag alone (the flag, then the country and tags: only the flag); null where it has no flag.
String? _flagOnly(String name) =>
    RegExp(r'^[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true).firstMatch(name.trimLeft())?.group(0);

/// a route with traffic moving on it now (the speed's mark, as in the chips)
bool _movingLink(SankeyLink l) => l.flows.fold<double>(0, (s, f) => s + f.speed) > 512;

typedef _Colours = ({Color vpn, Color direct, Color block, Color app, Color ink, Color soft, Color halo});

class _SankeyPainter extends CustomPainter {
  _SankeyPainter(this.model, this.c, this.value, this.family, this.brightness, this.lit, this.headers, this.speedValue, this.pulse, this.look)
      : super(repaint: pulse);

  final SankeyLook look;

  /// the pulse's turn, 0..1
  final Animation<double> pulse;

  final List<String> headers;
  final String Function(double)? speedValue;

  final SankeyModel model;
  final _Colours c;
  final String Function(double w) value;
  final String? family;
  final Brightness brightness;
  final Set<SankeyFlow> lit;

  Color _route(ConnectionRoute? r) => _soft(switch (r) {
    ConnectionRoute.vpn => c.vpn,
    ConnectionRoute.direct => c.direct,
    ConnectionRoute.block => c.block,
    null => c.app,
  });

  /// a colour near black on a light page (or near white on a dark one) is drawn lighter: a pure black node and
  /// ribbon looks heavy on a picture of many thin lines
  Color _soft(Color colour) {
    final lum = colour.computeLuminance();
    if (brightness == Brightness.light && lum < .12) return Color.lerp(colour, Colors.white, .5)!;
    if (brightness == Brightness.dark && lum > .85) return Color.lerp(colour, Colors.black, .4)!;
    return colour;
  }

  /// Laid-out labels kept between paints: the names hardly ever change, and laying text out is most of a paint's
  /// cost (the diagram is painted again at every poll). The key holds everything that makes a label look as it does.
  static final _labels = <String, TextPainter>{};

  TextPainter _text(
    String text,
    double width, {
    required bool strong,
    required double size,
    Color? color,
    int lines = 1,
    Paint? foreground,
    bool right = false,
  }) {
    final key =
        '$text|${width.round()}|$size|$strong|$lines|$right|${family ?? ''}|${foreground == null ? (color ?? c.ink).toARGB32() : 'h${foreground.color.toARGB32()}'}';
    final kept = _labels[key];
    if (kept != null) return kept;
    // a long session shows many names: start the keeping over rather than let it grow
    if (_labels.length > 600) _labels.clear();
    return _labels[key] = _build(text, width, strong: strong, size: size, color: color, lines: lines, foreground: foreground, right: right);
  }

  TextPainter _build(
    String text,
    double width, {
    required bool strong,
    required double size,
    Color? color,
    int lines = 1,
    Paint? foreground,
    bool right = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const ['Emoji'],
          fontSize: size,
          height: 1.15,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          color: foreground == null ? (color ?? c.ink) : null,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: right ? TextAlign.right : TextAlign.left,
      maxLines: lines,
      ellipsis: '…',
    )..layout(minWidth: right ? width : 0, maxWidth: width);
  }

  /// a label with a halo of the card's colour, so it reads over the ribbons
  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double width, {
    bool right = false,
    bool strong = true,
    double size = 11.5,
    Color? color,
    int lines = 1,
    double alpha = 1,
  }) {
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..color = c.halo.withValues(alpha: .9 * alpha);
    final back = _text(text, width, strong: strong, size: size, lines: lines, foreground: halo, right: right);
    final front = _text(text, width, strong: strong, size: size, color: (color ?? c.ink).withValues(alpha: alpha), lines: lines, right: right);
    final dx = (right ? at.dx - front.width : at.dx).roundToDouble();
    final dy = at.dy.roundToDouble();
    back.paint(canvas, Offset(dx, dy));
    front.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = SankeyGeometry(size.width);
    final xs = g.xs;
    // the columns' names over them, then the picture under
    for (final (i, title) in headers.indexed) {
      if (title.isEmpty) continue;
      final width = i == 1 ? (xs[2] - xs[1]) : (i == 0 ? g.labelL : g.labelR + 10);
      final p = _text(title.toUpperCase(), width, strong: true, size: 9.5, color: c.soft);
      p.paint(canvas, Offset(i == 0 ? xs[0] - 7 - p.width : (i == 1 ? xs[1] : xs[2]), 0));
    }
    canvas.save();
    canvas.translate(0, SankeyGeometry.headerH);
    model.layout(size.height - SankeyGeometry.headerH);
    final picking = lit.isNotEmpty;
    bool on(Set<SankeyFlow> flows) => !picking || flows.any(lit.contains);

    final day = brightness == Brightness.light;
    // the ribbons, thick ones under thin ones
    final links = [...model.links]..sort((a, b) => model.thickness(b).compareTo(model.thickness(a)));
    for (final l in links) {
      final path = g.ribbon(model, l);
      final colour = _route(l.route);
      final bright = on(l.flows);
      // where traffic moves the ribbon is full colour and its brightness swells and ebbs; a still one is pale
      final live = l.flows.any((f) => f.live);
      final moving = live && _movingLink(l);
      final breath = !live ? .2 : (moving ? .85 + .15 * math.sin(pulse.value * 2 * math.pi) : .85);
      final k = (bright ? 1.0 : .22) * breath;
      final xa = xs[l.from.column] + SankeyGeometry.nodeW;
      final xb = xs[l.to.column];
      final from = l.from.route == null ? c.app : colour;
      final th = model.thickness(l);
      final centre = Path()
        ..moveTo(xa, l.fromY + th / 2)
        ..cubicTo((xa + xb) / 2, l.fromY + th / 2, (xa + xb) / 2, l.toY + th / 2, xb, l.toY + th / 2);
      final shaderBox = Rect.fromLTRB(xa, 0, xb, size.height);
      final fill = Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          colors: [from.withValues(alpha: (day ? .2 : .26) * k), colour.withValues(alpha: (day ? .5 : .58) * k)],
        ).createShader(shaderBox);
      final edge = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = colour.withValues(alpha: (bright ? (live ? .55 : .14) : .1));
      switch (look) {
        case SankeyLook.ribbons:
          canvas.drawPath(path, fill);
          canvas.drawPath(path, edge);
        case SankeyLook.glow:
          if (live && bright) {
            canvas.drawPath(
              path,
              Paint()
                ..isAntiAlias = true
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
                ..color = colour.withValues(alpha: .55 * breath),
            );
          }
          canvas.drawPath(path, fill);
          canvas.drawPath(
            path,
            edge
              ..strokeWidth = live ? 1.3 : .8
              ..color = colour.withValues(alpha: live ? .9 : .12),
          );
        case SankeyLook.steps:
          final mid = ((xa + xb) / 2).roundToDouble();
          final stepped = Path()
            ..moveTo(xa, l.fromY)
            ..lineTo(mid, l.fromY)
            ..lineTo(mid, l.toY)
            ..lineTo(xb, l.toY)
            ..lineTo(xb, l.toY + th)
            ..lineTo(mid, l.toY + th)
            ..lineTo(mid, l.fromY + th)
            ..lineTo(xa, l.fromY + th)
            ..close();
          canvas.drawPath(stepped, fill);
          canvas.drawPath(stepped, edge);
        case SankeyLook.thin || SankeyLook.dots:
          canvas.drawPath(
            centre,
            Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = live ? 2.6 : 1.6
              ..shader = LinearGradient(
                colors: [from.withValues(alpha: (live ? .95 : .35) * (bright ? 1 : .3)), colour.withValues(alpha: (live ? 1 : .35) * (bright ? 1 : .3))],
              ).createShader(shaderBox),
          );
          if (look == SankeyLook.dots && live && bright) {
            final metric = centre.computeMetrics().first;
            for (var d = 0; d < 3; d++) {
              final at = ((pulse.value + d / 3) % 1.0) * metric.length;
              canvas.drawCircle(metric.getTangentForOffset(at)!.position, 3.2, Paint()..color = colour);
            }
          }
        case SankeyLook.dashed:
          if (live) {
            canvas.drawPath(path, fill);
            canvas.drawPath(path, edge);
          } else {
            // closed: no fill, only the outline, in dashes
            final dash = Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = colour.withValues(alpha: bright ? .6 : .2);
            for (final metric in path.computeMetrics()) {
              for (var at = 0.0; at < metric.length; at += 9) {
                canvas.drawPath(metric.extractPath(at, math.min(at + 5, metric.length)), dash);
              }
            }
          }
      }
    }

    final lastBottom = [-99.0, -99.0, -99.0];
    for (final (ci, column) in model.columns.indexed) {
      for (final n in column) {
        final bright = on(n.flows);
        final live = n.flows.any((f) => f.live);
        final alpha = (bright ? 1.0 : .3) * (live ? 1.0 : .32);
        final fill = _route(n.route);
        final top = n.y.roundToDouble();
        final bottom = math.max((n.y + n.h).roundToDouble(), top + 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(xs[ci], top, xs[ci] + SankeyGeometry.nodeW, bottom),
            const Radius.circular(3),
          ),
          Paint()
            ..isAntiAlias = true
            ..color = (ci == 0 ? fill.withValues(alpha: .8) : fill).withValues(alpha: (ci == 0 ? .8 : 1) * alpha),
        );
        // the name over two lines at most, the amount under it where the node is tall; a label only where the one
        // above it is done: thin neighbours would print over each other
        final tall = n.h >= 18;
        final amount = value(n.real);
        final speedText = speedValue?.call(n.speed);
        final lines = 1 + (tall && speedText != null && n.h >= 44 ? 1 : 0);
        final width = switch (ci) {
          0 => g.labelL - 9,
          1 => (xs[2] - xs[1]) - SankeyGeometry.nodeW - 6,
          _ => g.labelR - 9,
        };
        final nameStrong = ci != 1;
        final nameSize = ci == 1 ? 10.0 : 11.5;
        // a site is one line (a domain broken in the middle reads badly), an app or a server up to two
        final nameLines = ci == 1 ? 1 : 2;
        // a server of one of several subscriptions: its mark (a coloured circle with the letter) before the name
        final mark = ci == 2 ? splitMark(n.label) : (profile: null, text: n.label);
        final badge = mark.profile != null && mark.profile! >= 0 && mark.profile! < profileBadgesNow.length
            ? profileBadgesNow[mark.profile!]
            : null;
        final nameW = width - (badge == null ? 0 : 15);
        // a server: its flag alone; the direct way and a block: an icon
        final flag = ci == 2 ? _flagOnly(mark.text) : null;
        final icon = ci == 2 ? switch (n.route) {
          ConnectionRoute.direct => Icons.trending_flat_rounded,
          ConnectionRoute.block => Icons.block_rounded,
          _ => null,
        } : null;
        final shownName = flag ?? mark.text;
        final shownSize = flag != null ? 17.0 : nameSize;
        final shownLines = flag != null || icon != null ? 1 : nameLines;
        final nameH = icon != null ? 20.0 : _text(shownName, nameW, strong: nameStrong, size: shownSize, lines: shownLines, right: ci == 0).height;
        final blockH = nameH + (tall ? 13 * lines : 0);
        final labelTop = n.y + n.h / 2 - blockH / 2;
        if (labelTop < lastBottom[ci] + 1) continue;
        lastBottom[ci] = labelTop + blockH;
        final x = switch (ci) {
          0 => xs[0] - 7,
          1 => xs[1] + SankeyGeometry.nodeW + 5,
          _ => xs[2] + SankeyGeometry.nodeW + 7 + (badge == null ? 0 : 15),
        };
        if (badge != null) {
          final cy = labelTop + nameH / 2;
          final cx = xs[2] + SankeyGeometry.nodeW + 7 + 6;
          canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = badge.colour.withValues(alpha: alpha));
          final letter = _text(badge.letter, 12, strong: true, size: 8.5, color: Colors.white);
          letter.paint(canvas, Offset(cx - letter.width / 2, cy - letter.height / 2));
        }
        if (icon != null) {
          final glyph = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 19, color: _route(n.route).withValues(alpha: alpha)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          glyph.paint(canvas, Offset(x, labelTop));
        } else {
          _label(canvas, shownName, Offset(x, labelTop), nameW, right: ci == 0, strong: nameStrong, size: shownSize, lines: shownLines, alpha: alpha);
        }
        if (tall) {
          _label(canvas, amount, Offset(x, labelTop + nameH), width, right: ci == 0, strong: false, size: 10.5, color: c.soft, alpha: alpha);
          if (lines == 2) {
            _label(canvas, speedText!, Offset(x, labelTop + nameH + 13), width, right: ci == 0, strong: false, size: 10.5, color: c.soft, alpha: alpha);
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SankeyPainter old) => true;
}

/// The details of a tapped route: how much, its share, how many connections, and what it is made of (the apps, the
/// sites, the servers, the rules), each with its amount.
class SankeyDetails extends ConsumerWidget {
  const SankeyDetails({super.key, required this.selection, required this.value, this.speedValue, this.rows = 5});

  final SankeySelection selection;
  final String Function(double w) value;
  final String Function(double bytesPerSecond)? speedValue;
  final int rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = switch (selection.route) {
      ConnectionRoute.vpn => theme.araAccent,
      ConnectionRoute.direct => const Color(0xFF9AA0A6),
      ConnectionRoute.block => scheme.error,
      null => scheme.onSurfaceVariant,
    };
    final routeName = switch (selection.route) {
      ConnectionRoute.vpn => t.avpn.statsViaVpn,
      ConnectionRoute.direct => t.avpn.statsDirect,
      ConnectionRoute.block => t.avpn.connBlocked,
      null => null,
    };
    final share = selection.total <= 0 ? 0 : (selection.weight / selection.total * 100).round();
    Map<String, double> by(String Function(SankeyFlow) keyOf) {
      final m = <String, double>{};
      for (final f in selection.flows) {
        final k = keyOf(f);
        if (k.isEmpty) continue;
        m[k] = (m[k] ?? 0) + f.weight;
      }
      return m;
    }

    final sections = [
      (t.avpn.sankeyApps, by((f) => f.app)),
      (t.avpn.sankeySites, by((f) => f.host)),
      (t.avpn.sankeyRules, by((f) => f.rule)),
      (t.avpn.sankeyServers, {
        for (final e in by((f) => f.route == ConnectionRoute.vpn ? f.out : '').entries) e.key: e.value,
      }),
    ].where((s) => s.$2.length > 1 || (s.$2.length == 1 && s.$1 == t.avpn.sankeySites)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 36,
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(5)),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selection.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFamilyFallback: const ['Emoji'],
                        ),
                      ),
                      if (routeName != null)
                        Text(
                          routeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AraLook.readableOn(colour, scheme.surfaceContainerLow),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(10),
            Row(
              children: [
                Text(
                  value(selection.weight),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Gap(10),
                Text(
                  t.avpn.sankeyShare(share: share, count: selection.connections),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (speedValue != null)
              Text(
                '${t.avpn.sankeySpeed}: ${speedValue!(selection.speed)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            for (final (title, data) in sections) ...[
              const Gap(14),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Gap(6),
              _Rows(data: data, total: selection.weight, colour: colour, value: value, rows: rows),
            ],
          ],
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.data, required this.total, required this.colour, required this.value, required this.rows});

  final Map<String, double> data;
  final double total;
  final Color colour;
  final String Function(double w) value;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ranked = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final e in ranked.take(rows))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontFamilyFallback: const ['Emoji']),
                      ),
                    ),
                    const Gap(8),
                    Text(value(e.value), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const Gap(3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: total <= 0 ? 0 : (e.value / total).clamp(0.0, 1.0),
                    minHeight: 3,
                    color: colour,
                    backgroundColor: scheme.onSurface.withValues(alpha: .08),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A host as the site it belongs to, for the diagram's middle column: "rr4---sn.googlevideo.com" becomes
/// "googlevideo.com", "api.telegram.org" "telegram.org", "a.b.example.co.uk" "example.co.uk"; an address stays as it is.
String siteOf(String host) {
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return '';
  if (RegExp(r'^[\d.]+$').hasMatch(h) || h.contains(':')) return h;
  final parts = h.split('.');
  if (parts.length <= 2) return h;
  // a second-level zone of a country (co.uk, com.tr): one more label
  const zones = {'co', 'com', 'org', 'net', 'gov', 'edu', 'ac'};
  final keep = parts.last.length == 2 && zones.contains(parts[parts.length - 2]) ? 3 : 2;
  return parts.sublist(parts.length - keep).join('.');
}

/// Where the plates stand in the chips view.
class _ChipsLayout {
  static const headerH = 22.0;
  static const pitch = 56.0;
  static const chipH = 46.0;
}

/// The diagram as plates and thin lines: three columns of plates (an app, a site, a server) in rows of one size from
/// the top, each plate with its name, its traffic and its speed; a thin line for each route, a dot on it where the
/// traffic is moving. A tap on a plate or a line picks that route out (the rest dims) and shows its details.
class _ChipsView extends StatelessWidget {
  const _ChipsView({
    required this.model,
    required this.height,
    required this.lit,
    required this.value,
    required this.speedValue,
    required this.headers,
    required this.onNode,
    required this.onLink,
  });

  final SankeyModel model;
  final double height;
  final Set<SankeyFlow> lit;
  final String Function(double w) value;
  final String Function(double bytesPerSecond)? speedValue;
  final List<String> headers;
  final void Function(SankeyNode node)? onNode;
  final void Function(SankeyLink link)? onLink;

  static final _flag = RegExp(r'^([\u{1F1E6}-\u{1F1FF}]{2})\s*', unicode: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final picking = lit.isNotEmpty;
    Color routeColour(ConnectionRoute? r) => switch (r) {
      ConnectionRoute.vpn => accent,
      ConnectionRoute.direct => const Color(0xFF9AA0A6),
      ConnectionRoute.block => scheme.error,
      null => scheme.onSurfaceVariant,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final colW = [w * .285, w * .295, w * .30];
        final xs = [0.0, w * .35, w * .70];
        double top(int i) => _ChipsLayout.headerH + i * _ChipsLayout.pitch;
        final lines = [
          for (final l in model.links)
            (
              link: l,
              from: Offset(xs[l.from.column] + colW[l.from.column], top(model.columns[l.from.column].indexOf(l.from)) + _ChipsLayout.chipH / 2),
              to: Offset(xs[l.to.column], top(model.columns[l.to.column].indexOf(l.to)) + _ChipsLayout.chipH / 2),
              moving: l.flows.fold<double>(0, (s, f) => s + f.speed) > 512,
              on: !picking || l.flows.any(lit.contains),
            ),
        ];
        Widget plate(SankeyNode n, int col, int i) {
          final on = !picking || n.flows.any(lit.contains);
          final flag = _flag.firstMatch(n.label);
          final name = flag == null ? n.label : n.label.substring(flag.end);
          final speed = speedValue?.call(n.speed);
          // the speed only where something moves
          final second = speed == null || n.speed < 1 ? value(n.real) : '${value(n.real)} · $speed';
          return Positioned(
            left: xs[col],
            top: top(i),
            width: colW[col],
            height: _ChipsLayout.chipH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNode == null ? null : () => onNode!(n),
              child: AnimatedOpacity(
                opacity: on ? 1 : .35,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: picking && on ? routeColour(n.route ?? ConnectionRoute.vpn).withValues(alpha: .9) : scheme.onSurface.withValues(alpha: .08),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (flag != null) ...[
                        Text(flag.group(1)!, style: const TextStyle(fontSize: 15, fontFamilyFallback: ['Emoji'])),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                fontFamilyFallback: const ['Emoji'],
                              ),
                            ),
                            Text(
                              second,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // a tap on the space between the plates: the line nearest to it, if one is close
            onTapUp: onLink == null
                ? null
                : (d) {
                    SankeyLink? best;
                    var nearest = 14.0;
                    for (final line in lines) {
                      final d2 = _distanceToCurve(d.localPosition, line.from, line.to);
                      if (d2 < nearest) {
                        nearest = d2;
                        best = line.link;
                      }
                    }
                    if (best != null) onLink!(best);
                  },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChipLines(
                      [for (final line in lines) (from: line.from, to: line.to, colour: routeColour(line.link.route), moving: line.moving, on: line.on)],
                      scheme.onSurface,
                      accent,
                    ),
                  ),
                ),
                for (final (i, title) in headers.indexed)
                  if (title.isNotEmpty)
                    Positioned(
                      left: xs[i],
                      top: 0,
                      width: colW[i],
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                for (final (col, column) in model.columns.indexed)
                  for (final (i, n) in column.indexed) plate(n, col, i),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The line between two plates as a curve (the same one the painter draws): the nearest it comes to [at].
double _distanceToCurve(Offset at, Offset from, Offset to) {
  final mid = (from.dx + to.dx) / 2;
  var best = double.infinity;
  for (var i = 0; i <= 24; i++) {
    final t = i / 24;
    final u = 1 - t;
    final x = u * u * u * from.dx + 3 * u * u * t * mid + 3 * u * t * t * mid + t * t * t * to.dx;
    final y = u * u * u * from.dy + 3 * u * u * t * from.dy + 3 * u * t * t * to.dy + t * t * t * to.dy;
    best = math.min(best, (Offset(x, y) - at).distance);
  }
  return best;
}

typedef _ChipLine = ({Offset from, Offset to, Color colour, bool moving, bool on});

class _ChipLines extends CustomPainter {
  _ChipLines(this.lines, this.ink, this.accent);

  final List<_ChipLine> lines;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // the dimmed ones first, so a picked route lies over them
    final ordered = [...lines]..sort((a, b) => (a.on ? 1 : 0).compareTo(b.on ? 1 : 0));
    for (final l in ordered) {
      final mid = (l.from.dx + l.to.dx) / 2;
      final path = Path()
        ..moveTo(l.from.dx, l.from.dy)
        ..cubicTo(mid, l.from.dy, mid, l.to.dy, l.to.dx, l.to.dy);
      final base = l.moving ? l.colour : ink;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round
          ..color = base.withValues(alpha: l.on ? (l.moving ? .85 : .3) : .1),
      );
      if (l.moving && l.on) {
        final metric = path.computeMetrics().first;
        canvas.drawCircle(metric.getTangentForOffset(metric.length * .5)!.position, 3, Paint()..color = l.colour);
      }
    }
  }

  @override
  bool shouldRepaint(_ChipLines old) => true;
}
