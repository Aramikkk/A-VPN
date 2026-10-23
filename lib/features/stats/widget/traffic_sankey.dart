import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
  });

  final String app;
  final String rule;
  final String out;
  final ConnectionRoute route;
  final double weight;
  final String host;
  final int count;
}

class SankeyNode {
  SankeyNode(this.key, this.label, this.route, this.column);

  final String key;
  final String label;
  final int column;

  /// the way the traffic of a rule or a destination went (null for an app: it can send in several ways)
  final ConnectionRoute? route;
  double weight = 0;
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
  double weight = 0;
  double fromY = 0;
  double toY = 0;
  final flows = <SankeyFlow>{};
}

/// The flow diagram's data: three columns (apps, rules, destinations) and the ribbons between them, each as thick
/// as the traffic it carries. Only the biggest of each column are kept, the rest added up in one "other" node.
class SankeyModel {
  SankeyModel._(this.columns, this.links, this.total);

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
    SankeyNode node(String key, String label, ConnectionRoute? route, int column) =>
        nodes.putIfAbsent(key, () => SankeyNode(key, label, route, column));
    final links = <String, SankeyLink>{};
    SankeyLink link(SankeyNode a, SankeyNode b, ConnectionRoute route) =>
        links.putIfAbsent('${a.key}>${b.key}', () => SankeyLink(a, b, route));

    for (final f in list) {
      final a = apps.contains(f.app) ? node('a|${f.app}', f.app, null, 0) : node('a|', otherApp, null, 0);
      final r = rules.contains(ruleKey(f))
          ? node('r|${ruleKey(f)}', f.rule, f.route, 1)
          : node('r|${f.route.index}|', otherRule, f.route, 1);
      final o = outs.contains(outKey(f))
          ? node('o|${outKey(f)}', f.out, f.route, 2)
          : node('o|${f.route.index}|', otherOut, f.route, 2);
      for (final n in [a, r, o]) {
        n.flows.add(f);
      }
      for (final l in [link(a, r, f.route), link(r, o, f.route)]) {
        l.weight += f.weight;
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
          return b.weight.compareTo(a.weight);
        });
    return SankeyModel._([column(0), column(1), column(2)], links.values.toList(), total);
  }

  /// Places the nodes in [height] (each column fills it, the room not taken by nodes shared between them as gaps)
  /// and the ribbons' ends along the nodes' sides, ordered by where they go so they cross as little as they can.
  /// Edges sit on whole pixels, so they stay crisp.
  void layout(double height, {double minGap = 6}) {
    if (isEmpty) return;
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

/// Where the columns stand in a width: the apps' names on the left, the nodes, the servers' names on the right.
class SankeyGeometry {
  SankeyGeometry(double width) {
    final labelL = math.min(88.0, width * .24);
    labelR = math.min(92.0, width * .25);
    this.labelL = labelL;
    final x2 = width - labelR - nodeW;
    xs = [labelL, (labelL + x2) / 2, x2];
  }

  static const nodeW = 8.0;
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
  int get connections => flows.fold<int>(0, (s, f) => s + f.count);
}

/// The traffic as a flow diagram: apps on the left, the rules that took them in the middle, and where it went (a
/// server, direct, blocked) on the right; each ribbon as thick as its traffic, in the way's colour. A tap on a
/// route shows its details.
class TrafficSankey extends ConsumerWidget {
  const TrafficSankey({super.key, required this.items, required this.weight, required this.value});

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
        ),
    ];
    return SankeyDiagram(
      flows: flows,
      value: value,
      otherApp: t.avpn.connOther,
      otherRule: t.avpn.connOther,
      otherOut: t.avpn.connOther,
      onSelect: (selection) async => showGlassPopup(
        context,
        SankeyDetails(selection: selection, value: value),
      ),
    );
  }
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
    this.onSelect,
    this.initialSelection,
  });

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

class _SankeyDiagramState extends State<SankeyDiagram> {
  late SankeyModel _model;
  Set<SankeyFlow> _lit = const {};

  SankeyModel _build() => SankeyModel.build(
    widget.flows,
    otherApp: widget.otherApp,
    otherRule: widget.otherRule,
    otherOut: widget.otherOut,
  );

  @override
  void initState() {
    super.initState();
    _model = _build();
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
  }

  Future<void> _select(SankeySelection selection) async {
    setState(() => _lit = selection.flows);
    await widget.onSelect?.call(selection);
    if (mounted) setState(() => _lit = const {});
  }

  void _tap(Offset at, double width, double height) {
    final geometry = SankeyGeometry(width);
    _model.layout(height);
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
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Colours = ({Color vpn, Color direct, Color block, Color app, Color ink, Color soft, Color halo});

class _SankeyPainter extends CustomPainter {
  _SankeyPainter(this.model, this.c, this.value, this.family, this.brightness, this.lit);

  final SankeyModel model;
  final _Colours c;
  final String Function(double w) value;
  final String? family;
  final Brightness brightness;
  final Set<SankeyFlow> lit;

  Color _route(ConnectionRoute? r) => switch (r) {
    ConnectionRoute.vpn => c.vpn,
    ConnectionRoute.direct => c.direct,
    ConnectionRoute.block => c.block,
    null => c.app,
  };

  TextPainter _text(
    String text,
    double width, {
    required bool strong,
    required double size,
    Color? color,
    int lines = 1,
    Paint? foreground,
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
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width);
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
    final back = _text(text, width, strong: strong, size: size, lines: lines, foreground: halo);
    final front = _text(text, width, strong: strong, size: size, color: (color ?? c.ink).withValues(alpha: alpha), lines: lines);
    final dx = (right ? at.dx - front.width : at.dx).roundToDouble();
    final dy = at.dy.roundToDouble();
    back.paint(canvas, Offset(dx, dy));
    front.paint(canvas, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = SankeyGeometry(size.width);
    final xs = g.xs;
    model.layout(size.height);
    final picking = lit.isNotEmpty;
    bool on(Set<SankeyFlow> flows) => !picking || flows.any(lit.contains);

    final day = brightness == Brightness.light;
    // the ribbons, thick ones under thin ones
    final links = [...model.links]..sort((a, b) => model.thickness(b).compareTo(model.thickness(a)));
    for (final l in links) {
      final path = g.ribbon(model, l);
      final colour = _route(l.route);
      final bright = on(l.flows);
      final k = bright ? 1.0 : .22;
      final xa = xs[l.from.column] + SankeyGeometry.nodeW;
      final xb = xs[l.to.column];
      final from = l.from.route == null ? c.app : colour;
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            colors: [
              from.withValues(alpha: (day ? .2 : .26) * k),
              colour.withValues(alpha: (day ? .5 : .58) * k),
            ],
          ).createShader(Rect.fromLTRB(xa, 0, xb, size.height)),
      );
      // a thin edge gives the ribbon its shape against the background
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = colour.withValues(alpha: (bright ? .5 : .12)),
      );
    }

    final lastBottom = [-99.0, -99.0, -99.0];
    for (final (ci, column) in model.columns.indexed) {
      for (final n in column) {
        final bright = on(n.flows);
        final alpha = bright ? 1.0 : .3;
        final fill = _route(n.route);
        final top = n.y.roundToDouble();
        final bottom = math.max((n.y + n.h).roundToDouble(), top + 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(xs[ci], top, xs[ci] + SankeyGeometry.nodeW, bottom),
            const Radius.circular(4),
          ),
          Paint()
            ..isAntiAlias = true
            ..color = (ci == 0 ? fill.withValues(alpha: .8) : fill).withValues(alpha: (ci == 0 ? .8 : 1) * alpha),
        );
        // a label only where the one above it is done: thin neighbours would print over each other
        final tall = n.h >= 28;
        final labelTop = n.y + n.h / 2 - (tall ? 13 : 7);
        if (labelTop < lastBottom[ci] + 1) continue;
        lastBottom[ci] = labelTop + (tall ? 27 : 14);
        final amount = value(n.weight);
        switch (ci) {
          case 0:
            _label(canvas, n.label, Offset(xs[0] - 7, labelTop), g.labelL - 9, right: true, alpha: alpha);
            if (tall) {
              _label(canvas, amount, Offset(xs[0] - 7, labelTop + 13), g.labelL - 9, right: true, strong: false, size: 10.5, color: c.soft, alpha: alpha);
            }
          case 1:
            final room = (xs[2] - xs[1]) - SankeyGeometry.nodeW - 10;
            _label(canvas, n.label, Offset(xs[1] + SankeyGeometry.nodeW + 5, labelTop), room, lines: n.h >= 44 ? 3 : (tall ? 2 : 1), strong: false, size: 10.5, alpha: alpha);
          default:
            _label(canvas, n.label, Offset(xs[2] + SankeyGeometry.nodeW + 7, labelTop), g.labelR - 9, alpha: alpha);
            if (tall) {
              _label(canvas, amount, Offset(xs[2] + SankeyGeometry.nodeW + 7, labelTop + 13), g.labelR - 9, strong: false, size: 10.5, color: c.soft, alpha: alpha);
            }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SankeyPainter old) => true;
}

/// The details of a tapped route: how much, its share, how many connections, and what it is made of (the apps, the
/// sites, the servers, the rules), each with its amount.
class SankeyDetails extends ConsumerWidget {
  const SankeyDetails({super.key, required this.selection, required this.value, this.rows = 5});

  final SankeySelection selection;
  final String Function(double w) value;
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
