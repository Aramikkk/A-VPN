part of 'traffic_sankey.dart';

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
    // an empty model holds constant lists, which can't be sorted
    if (isEmpty) return;
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
    final outs = keep(outKey)
      ..addAll([
        for (final f in list)
          if (f.route != ConnectionRoute.vpn) outKey(f),
      ]);

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

    List<SankeyNode> column(int index) => nodes.values.where((n) => n.column == index).toList()
      ..sort((a, b) {
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
    return SankeyModel._(
      [column(0), column(1), column(2)],
      links.values.toList(),
      total,
      even ? (calm ? 22 : 44) : null,
      calm: calm,
    );
  }

  /// Places the nodes in [height] (each column fills it, the room not taken by nodes shared between them as gaps)
  /// and the ribbons' ends along the nodes' sides, ordered by where they go so they cross as little as they can.
  /// Edges sit on whole pixels, so they stay crisp.
  void layout(double height, {double minGap = 6, bool spread = false}) {
    if (isEmpty) return;
    if (calm) {
      _layoutEqual(height, spread);
      return;
    }
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

  /// calm: every node the same size, from the top at a fixed distance, whatever it carries; the lines meet a node one
  /// after the other along it (a line's ends are its centres: thickness 0), in the order of where they go.
  void _layoutEqual(double height, bool spread) {
    const gap = 10.0;
    for (final (ci, column) in columns.indexed) {
      if (column.isEmpty) continue;
      if (spread) {
        // each column over the whole length, the first at one end and the last at the other, all of one size (the
        // servers' wider: the lines of many routes meet them)
        final cap = const [44.0, 56.0, 120.0][ci];
        final size = math.min(cap, math.max(18.0, (height - gap * (column.length - 1)) / column.length));
        for (final (i, n) in column.indexed) {
          n.h = size;
          n.y = column.length == 1 ? (height - size) / 2 : i * (height - size) / (column.length - 1);
        }
        continue;
      }
      final nodeH = ((height - gap * (widest - 1)) / widest).clamp(18.0, 44.0);
      var y = 0.0;
      for (final n in column) {
        n.y = y;
        n.h = nodeH;
        y += nodeH + gap;
      }
    }
    for (final n in columns.expand((c) => c)) {
      final outs = [...n.outLinks]..sort((a, b) => a.to.y.compareTo(b.to.y));
      for (final (i, l) in outs.indexed) {
        l.fromY = n.y + n.h * (i + .5) / outs.length;
      }
      final ins = [...n.inLinks]..sort((a, b) => a.from.y.compareTo(b.from.y));
      for (final (i, l) in ins.indexed) {
        l.toY = n.y + n.h * (i + .5) / ins.length;
      }
    }
    _k = 0;
  }

  double _k = 0;

  /// a ribbon's thickness in pixels
  double thickness(SankeyLink l) => l.weight * _k;
}

/// Where the columns stand in a width: the apps' names on the left, the nodes, the servers' names on the right.
class SankeyGeometry {
  SankeyGeometry(double width, {bool stepped = false, double middleW = 118, bool badges = false}) {
    if (stepped) {
      // symmetric: an icon (30) or a flag (34) at each edge, the same room for both, the sites in the middle (their bar and
      // their names together centred between the two bars)
      // (the apps' tiles start a little further from the picture's edge than the flags end from the other, so the left room
      // is the smaller: both sides then stand the same distance from the card's edge)
      final sideL = glyph + 8 + edge - 14;
      // (a subscription's badge before the flag takes 15 more on the right)
      final sideR = glyph + 8 + edge - 6 + (badges ? 15 : 0);
      this.labelL = sideL;
      labelR = sideR;
      final x2 = width - sideR - nodeW;
      final group = nodeW + 5 + middleW;
      xs = [sideL, ((sideL + nodeW + x2) - group) / 2, x2];
      return;
    }
    final labelL = math.min(88.0, width * .24);
    labelR = math.min(70.0, width * .19);
    this.labelL = labelL;
    final x2 = width - labelR - nodeW;
    xs = [labelL, (labelL + x2) / 2, x2];
  }

  /// the widest of the glyphs at the sides (the flag), and the room left at the edge of the picture
  static const glyph = 40.0;
  static const edge = 2.0;

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
