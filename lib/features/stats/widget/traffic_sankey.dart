import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One stretch of traffic: which app, under which rule, where it went (a server, direct or blocked), and how much.
typedef SankeyFlow = ({String app, String rule, String out, ConnectionRoute route, double weight});

class SankeyNode {
  SankeyNode(this.key, this.label, this.route);

  final String key;
  final String label;

  /// the way the traffic of a rule or a destination went (null for an app: it can send in several ways)
  final ConnectionRoute? route;
  double weight = 0;
  double y = 0;
  double h = 0;
  final outLinks = <SankeyLink>[];
  final inLinks = <SankeyLink>[];
}

class SankeyLink {
  SankeyLink(this.from, this.to, this.route);

  final SankeyNode from;
  final SankeyNode to;
  final ConnectionRoute route;
  double weight = 0;
  double fromY = 0;
  double toY = 0;
}

/// The flow diagram's data: three columns (apps, rules, destinations) and the ribbons between them, each as thick
/// as the traffic it carries. Only the biggest of each column are kept, the rest added up in one "other" node.
class SankeyModel {
  SankeyModel._(this.columns, this.links, this.total);

  final List<List<SankeyNode>> columns;
  final List<SankeyLink> links;
  final double total;

  bool get isEmpty => total <= 0;

  static SankeyModel build(
    Iterable<SankeyFlow> flows, {
    required String otherApp,
    required String otherRule,
    required String otherOut,
    int top = 6,
    double minShare = .02,
  }) {
    final list = flows.where((f) => f.weight > 0).toList();
    final total = list.fold<double>(0, (s, f) => s + f.weight);
    if (total <= 0) return SankeyModel._(const [[], [], []], const [], 0);

    // a column keeps the biggest keys that are worth a node, everything else goes to its "other"
    Set<String> keep(String Function(SankeyFlow) keyOf) {
      final by = <String, double>{};
      for (final f in list) {
        by[keyOf(f)] = (by[keyOf(f)] ?? 0) + f.weight;
      }
      final ranked = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return {
        for (final e in ranked.take(top))
          if (e.value >= total * minShare) e.key,
      };
    }

    String ruleKey(SankeyFlow f) => '${f.route.index}|${f.rule}';
    String outKey(SankeyFlow f) => '${f.route.index}|${f.out}';
    final apps = keep((f) => f.app);
    final rules = keep(ruleKey);
    // "direct" and "blocked" are one destination each, always shown; the servers are ranked
    final outs = keep(outKey)..addAll([for (final f in list) if (f.route != ConnectionRoute.vpn) outKey(f)]);

    final nodes = <String, SankeyNode>{};
    SankeyNode node(String key, String label, ConnectionRoute? route) =>
        nodes.putIfAbsent(key, () => SankeyNode(key, label, route));
    final links = <String, SankeyLink>{};
    SankeyLink link(SankeyNode a, SankeyNode b, ConnectionRoute route) =>
        links.putIfAbsent('${a.key}>${b.key}', () => SankeyLink(a, b, route));

    for (final f in list) {
      final a = apps.contains(f.app) ? node('a|${f.app}', f.app, null) : node('a|', otherApp, null);
      final r = rules.contains(ruleKey(f))
          ? node('r|${ruleKey(f)}', f.rule, f.route)
          : node('r|${f.route.index}|', otherRule, f.route);
      final o = outs.contains(outKey(f))
          ? node('o|${outKey(f)}', f.out, f.route)
          : node('o|${f.route.index}|', otherOut, f.route);
      for (final l in [link(a, r, f.route), link(r, o, f.route)]) {
        l.weight += f.weight;
      }
    }
    for (final l in links.values) {
      l.from.outLinks.add(l);
      l.to.inLinks.add(l);
    }
    for (final n in nodes.values) {
      n.weight = math.max(n.outLinks.fold<double>(0, (s, l) => s + l.weight), n.inLinks.fold<double>(0, (s, l) => s + l.weight));
    }

    List<SankeyNode> column(String prefix, {required bool byRoute}) =>
        nodes.values.where((n) => n.key.startsWith(prefix)).toList()..sort((a, b) {
          if (byRoute) {
            final r = a.route!.index.compareTo(b.route!.index);
            if (r != 0) return r;
          }
          // "other" last within its group
          final aOther = a.key.endsWith('|');
          final bOther = b.key.endsWith('|');
          if (aOther != bOther) return aOther ? 1 : -1;
          return b.weight.compareTo(a.weight);
        });
    return SankeyModel._(
      [column('a|', byRoute: false), column('r|', byRoute: true), column('o|', byRoute: true)],
      links.values.toList(),
      total,
    );
  }

  /// Places the nodes in [height] (each column fills it, the room not taken by nodes shared between them as gaps)
  /// and the ribbons' ends along the nodes' sides, ordered by where they go so they cross as little as they can.
  void layout(double height, {double minGap = 5}) {
    if (isEmpty) return;
    final widest = columns.map((c) => c.length).fold<int>(1, math.max);
    final k = (height - minGap * (widest - 1)) / total;
    for (final column in columns) {
      if (column.isEmpty) continue;
      final used = column.fold<double>(0, (s, n) => s + n.weight * k);
      final gap = column.length > 1 ? (height - used) / (column.length - 1) : 0.0;
      var y = column.length > 1 ? 0.0 : (height - used) / 2;
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

/// The traffic as a flow diagram: apps on the left, the rules that took them in the middle, and where it went (a
/// server, direct, blocked) on the right; each ribbon as thick as its traffic, in the way's colour.
class TrafficSankey extends ConsumerWidget {
  const TrafficSankey({super.key, required this.items, required this.weight, required this.value, this.height = 300});

  final List<SeenConnection> items;
  final double Function(SeenConnection c) weight;
  final String Function(double w) value;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final flows = <SankeyFlow>[
      for (final c in items)
        (
          app: c.app.isEmpty ? '' : connectionAppName(t, apps, c.app),
          rule: ruleLabel(c.rule, t, apps: apps) ?? t.avpn.connRuleDefault,
          out: switch (c.route) {
            ConnectionRoute.vpn => c.outbound.isEmpty ? t.avpn.statsViaVpn : c.outbound,
            ConnectionRoute.direct => t.avpn.statsDirect,
            ConnectionRoute.block => t.avpn.connBlocked,
          },
          route: c.route,
          weight: weight(c),
        ),
    ];
    return SankeyDiagram(
      flows: flows,
      value: value,
      height: height,
      otherApp: t.avpn.connOther,
      otherRule: t.avpn.connOther,
      otherOut: t.avpn.connOther,
    );
  }
}

/// The diagram itself, from flows already named (the preview and the tests draw it without any providers).
class SankeyDiagram extends StatelessWidget {
  const SankeyDiagram({
    super.key,
    required this.flows,
    required this.value,
    required this.otherApp,
    required this.otherRule,
    required this.otherOut,
    this.height = 300,
  });

  final List<SankeyFlow> flows;
  final String Function(double w) value;
  final String otherApp;
  final String otherRule;
  final String otherOut;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final model = SankeyModel.build(flows, otherApp: otherApp, otherRule: otherRule, otherOut: otherOut);
    if (model.isEmpty) return SizedBox(height: height * .5);
    final colours = (
      vpn: theme.araAccent,
      direct: const Color(0xFF9AA0A6),
      block: scheme.error,
      app: scheme.onSurfaceVariant,
      ink: scheme.onSurface,
      soft: scheme.onSurfaceVariant,
      halo: scheme.surfaceContainerLow,
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SankeyPainter(model, colours, value, theme.textTheme.labelSmall?.fontFamily, theme.brightness),
      ),
    );
  }
}

typedef _Colours = ({Color vpn, Color direct, Color block, Color app, Color ink, Color soft, Color halo});

class _SankeyPainter extends CustomPainter {
  _SankeyPainter(this.model, this.c, this.value, this.family, this.brightness);

  final SankeyModel model;
  final _Colours c;
  final String Function(double w) value;
  final String? family;
  final Brightness brightness;

  static const _node = 7.0;

  Color _route(ConnectionRoute? r) => switch (r) {
    ConnectionRoute.vpn => c.vpn,
    ConnectionRoute.direct => c.direct,
    ConnectionRoute.block => c.block,
    null => c.app,
  };

  TextPainter _text(String text, double width, {required bool strong, Color? color, int lines = 1, Paint? foreground}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontFamilyFallback: const ['Emoji'],
          fontSize: 10.5,
          height: 1.15,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
          color: foreground == null ? (color ?? c.ink) : null,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width);
  }

  /// a label with a halo of the card's colour, so it reads over the ribbons
  void _label(Canvas canvas, String text, Offset at, double width, {bool right = false, bool strong = true, Color? color, int lines = 1}) {
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = c.halo.withValues(alpha: .85);
    final back = _text(text, width, strong: strong, lines: lines, foreground: halo);
    final front = _text(text, width, strong: strong, color: color, lines: lines);
    final dx = right ? at.dx - front.width : at.dx;
    back.paint(canvas, Offset(dx, at.dy));
    front.paint(canvas, Offset(dx, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final labelL = math.min(88.0, size.width * .24);
    final labelR = math.min(92.0, size.width * .25);
    final x0 = labelL;
    final x2 = size.width - labelR - _node;
    final x1 = (x0 + x2) / 2;
    final xs = [x0, x1, x2];
    model.layout(size.height);

    final day = brightness == Brightness.light;
    // the ribbons, thick ones under thin ones
    final links = [...model.links]..sort((a, b) => model.thickness(b).compareTo(model.thickness(a)));
    for (final l in links) {
      final column = model.columns.indexWhere((col) => col.contains(l.from));
      final xa = xs[column] + _node;
      final xb = xs[column + 1];
      final th = model.thickness(l);
      final mid = (xa + xb) / 2;
      final path = Path()
        ..moveTo(xa, l.fromY)
        ..cubicTo(mid, l.fromY, mid, l.toY, xb, l.toY)
        ..lineTo(xb, l.toY + th)
        ..cubicTo(mid, l.toY + th, mid, l.fromY + th, xa, l.fromY + th)
        ..close();
      final colour = _route(l.route);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              colour.withValues(alpha: day ? .16 : .2),
              colour.withValues(alpha: day ? .42 : .5),
            ],
          ).createShader(Rect.fromLTRB(xa, 0, xb, size.height)),
      );
    }

    var lastBottom = [-99.0, -99.0, -99.0];
    for (final (ci, column) in model.columns.indexed) {
      for (final n in column) {
        final fill = _route(n.route);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(xs[ci], n.y, _node, math.max(n.h, 3)),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, Paint()..color = ci == 0 ? fill.withValues(alpha: .75) : fill);
        // a label only where the one above it is done: thin neighbours would print over each other
        final tall = n.h >= 26;
        final top = n.y + n.h / 2 - (tall ? 12 : 6);
        if (top < lastBottom[ci] + 1) continue;
        lastBottom[ci] = top + (tall ? 25 : 12);
        final amount = value(n.weight);
        switch (ci) {
          case 0:
            _label(canvas, n.label, Offset(xs[0] - 6, top), labelL - 8, right: true);
            if (tall) _label(canvas, amount, Offset(xs[0] - 6, top + 12), labelL - 8, right: true, strong: false, color: c.soft);
          case 1:
            final room = (x2 - x1) - _node - 8;
            _label(canvas, n.label, Offset(xs[1] + _node + 4, top), room, lines: tall ? 2 : 1, strong: false);
          default:
            _label(canvas, n.label, Offset(xs[2] + _node + 6, top), labelR - 8);
            if (tall) _label(canvas, amount, Offset(xs[2] + _node + 6, top + 12), labelR - 8, strong: false, color: c.soft);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SankeyPainter old) => old.model != model || old.brightness != brightness || old.c != c;
}
