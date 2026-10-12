import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';

/// One column's node: its label, colour and weight.
class FlowNode {
  FlowNode(this.column, this.label, this.color);

  final int column;
  final String label;
  final Color color;
  double weight = 0;
  Rect rect = Rect.zero;

  // where the next link leaves / arrives, from the top of the node
  double outOffset = 0;
  double inOffset = 0;
}

class FlowLink {
  FlowLink(this.from, this.to);

  final FlowNode from;
  final FlowNode to;
  double weight = 0;
}

/// The connections as flows between columns — app → rule → route → server — each node as tall as the
/// connections (or traffic) through it. Built from [items]; small nodes in a column fold into "other".
class ConnectionFlow {
  ConnectionFlow._(this.columns, this.links);

  final List<List<FlowNode>> columns;
  final List<FlowLink> links;

  bool get isEmpty => links.isEmpty;

  factory ConnectionFlow.build(
    List<SeenConnection> items, {
    required bool byTraffic,
    required String Function(String app) appName,
    required String Function(String rule) ruleName,
    required String Function(ConnectionRoute route) routeName,
    required String other,
    required List<Color> palette,
    required Color Function(ConnectionRoute route) routeColor,
    int maxPerColumn = 6,
  }) {
    double weightOf(SeenConnection c) => byTraffic ? c.total.toDouble() : 1;
    // each connection's path; a direct or blocked one ends at the route
    final paths = <(List<String>, double, ConnectionRoute)>[
      for (final c in items)
        (
          [
            appName(c.app),
            ruleName(c.rule),
            routeName(c.route),
            if (c.route == ConnectionRoute.vpn && c.outbound.isNotEmpty) c.outbound,
          ],
          weightOf(c),
          c.route,
        ),
    ].where((p) => p.$2 > 0).toList();

    // the biggest nodes of each column keep their names, the rest is "other"
    final keep = <int, Set<String>>{};
    for (var col = 0; col < 4; col++) {
      final totals = <String, double>{};
      for (final (path, w, _) in paths) {
        if (col < path.length) totals[path[col]] = (totals[path[col]] ?? 0) + w;
      }
      final sorted = totals.keys.toList()..sort((a, b) => totals[b]!.compareTo(totals[a]!));
      keep[col] = sorted.take(col == 2 ? 3 : maxPerColumn - 1).toSet();
      if (sorted.length == maxPerColumn) keep[col]!.add(sorted.last);
    }

    final nodes = <String, FlowNode>{};
    final links = <String, FlowLink>{};
    FlowNode node(int col, String label, ConnectionRoute route) => nodes.putIfAbsent(
      '$col\u0000$label',
      () => FlowNode(col, label, col == 2 ? routeColor(route) : palette[col % palette.length]),
    );
    for (final (path, w, route) in paths) {
      final named = [for (var col = 0; col < path.length; col++) keep[col]!.contains(path[col]) ? path[col] : other];
      FlowNode? previous;
      for (var col = 0; col < named.length; col++) {
        final n = node(col, named[col], route);
        final from = previous;
        if (from != null) {
          links.putIfAbsent('${from.column}\u0000${from.label}\u0001${n.label}', () => FlowLink(from, n)).weight += w;
        }
        previous = n;
      }
    }
    // a node weighs what passes through it: the bigger of what comes in and what goes out
    for (final n in nodes.values) {
      final inW = links.values.where((l) => l.to == n).fold<double>(0, (s, l) => s + l.weight);
      final outW = links.values.where((l) => l.from == n).fold<double>(0, (s, l) => s + l.weight);
      n.weight = inW > outW ? inW : outW;
    }
    final columns = [
      for (var col = 0; col < 4; col++)
        nodes.values.where((n) => n.column == col).toList()..sort((a, b) {
          // "other" last, then by weight
          if (a.label == other) return 1;
          if (b.label == other) return -1;
          return b.weight.compareTo(a.weight);
        }),
    ].where((c) => c.isNotEmpty).toList();
    return ConnectionFlow._(columns, links.values.toList());
  }
}

/// Draws a [ConnectionFlow]: bars for the nodes, bands for the links, names beside the bars.
class ConnectionFlowPainter extends CustomPainter {
  ConnectionFlowPainter(this.flow, {required this.textStyle, required this.background});

  final ConnectionFlow flow;
  final TextStyle textStyle;
  final Color background;

  static const bar = 10.0;
  static const gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (flow.isEmpty) return;
    final cols = flow.columns.length;
    // the last column keeps room for its names on the right
    final step = cols == 1 ? 0.0 : (size.width * .66 - bar) / (cols - 1);
    final total = flow.columns.first.fold<double>(0, (s, n) => s + n.weight);
    for (var c = 0; c < cols; c++) {
      final column = flow.columns[c];
      final colTotal = column.fold<double>(0, (s, n) => s + n.weight);
      final room = size.height - gap * (column.length - 1);
      // every column on the first one's scale, centred
      final scale = room / (total > colTotal ? total : colTotal);
      var y = (size.height - colTotal * scale - gap * (column.length - 1)) / 2;
      for (final n in column) {
        final h = (n.weight * scale).clamp(2.0, size.height);
        n
          ..rect = Rect.fromLTWH(c * step, y, bar, h)
          ..outOffset = 0
          ..inOffset = 0;
        y += h + gap;
      }
    }

    // bands, in the order of their ends so they don't cross at the bars
    final ordered = [...flow.links]
      ..sort((a, b) {
        final byFrom = a.from.rect.top.compareTo(b.from.rect.top);
        return byFrom != 0 ? byFrom : a.to.rect.top.compareTo(b.to.rect.top);
      });
    final incoming = [...flow.links]
      ..sort((a, b) {
        final byTo = a.to.rect.top.compareTo(b.to.rect.top);
        return byTo != 0 ? byTo : a.from.rect.top.compareTo(b.from.rect.top);
      });
    final inTop = <FlowLink, double>{};
    for (final l in incoming) {
      final h = l.to.rect.height * l.weight / (l.to.weight == 0 ? 1 : l.to.weight);
      inTop[l] = l.to.rect.top + l.to.inOffset;
      l.to.inOffset += h;
    }
    for (final l in ordered) {
      final hFrom = l.from.rect.height * l.weight / (l.from.weight == 0 ? 1 : l.from.weight);
      final hTo = l.to.rect.height * l.weight / (l.to.weight == 0 ? 1 : l.to.weight);
      final y0 = l.from.rect.top + l.from.outOffset;
      l.from.outOffset += hFrom;
      final y1 = inTop[l]!;
      final x0 = l.from.rect.right;
      final x1 = l.to.rect.left;
      final mid = (x0 + x1) / 2;
      final path = Path()
        ..moveTo(x0, y0)
        ..cubicTo(mid, y0, mid, y1, x1, y1)
        ..lineTo(x1, y1 + hTo)
        ..cubicTo(mid, y1 + hTo, mid, y0 + hFrom, x0, y0 + hFrom)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [l.from.color.withValues(alpha: .38), l.to.color.withValues(alpha: .38)],
          ).createShader(Rect.fromLTRB(x0, 0, x1, size.height)),
      );
    }

    // bars and names on top
    for (var c = 0; c < cols; c++) {
      final maxWidth = c == cols - 1 ? size.width - flow.columns[c].first.rect.right - 6 : step - bar - 8;
      for (final n in flow.columns[c]) {
        canvas.drawRRect(RRect.fromRectAndRadius(n.rect, const Radius.circular(2)), Paint()..color = n.color);
        if (n.rect.height < 9 && flow.columns[c].length > 3) continue; // no room for a name
        final text = TextPainter(
          text: TextSpan(text: n.label, style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth.clamp(10, double.infinity));
        final at = Offset(n.rect.right + 5, n.rect.center.dy - text.height / 2);
        // a backing so the name reads over the bands
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(at.dx - 2, at.dy, text.width + 4, text.height),
            const Radius.circular(3),
          ),
          Paint()..color = background.withValues(alpha: .55),
        );
        text.paint(canvas, at);
      }
    }
  }

  @override
  bool shouldRepaint(ConnectionFlowPainter old) => true;
}

/// The column colours from the theme: its accent and two hues from it, kept readable on [surface]; a colourless
/// accent (Monochrome, OLED) gets blue, green and amber.
List<Color> flowPalette(Color primary, Color surface) {
  final hsl = HSLColor.fromColor(primary);
  final base = hsl.saturation < .12
      ? const [Color(0xFF6E8BFF), Color(0xFF7FD18B), Color(0xFFF2C14E), Color(0xFFE88B8B)]
      : [primary, hsl.withHue((hsl.hue + 120) % 360).toColor(), primary, hsl.withHue((hsl.hue + 220) % 360).toColor()];
  return [for (final c in base) AraLook.readableOn(c, surface)];
}
