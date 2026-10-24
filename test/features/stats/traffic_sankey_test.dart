import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/traffic_sankey.dart';

SankeyFlow flow(String app, String rule, String out, ConnectionRoute route, double w) =>
    SankeyFlow(app: app, rule: rule, out: out, route: route, weight: w);

SankeyModel build(List<SankeyFlow> flows) =>
    SankeyModel.build(flows, otherApp: 'other', otherRule: 'other', otherOut: 'other');

void main() {
  final flows = [
    flow('Chrome', 'ru', 'direct', ConnectionRoute.direct, 400),
    flow('Chrome', 'rest', 'SE', ConnectionRoute.vpn, 100),
    flow('Telegram', 'tg', 'NL', ConnectionRoute.vpn, 300),
    flow('Disk', 'ru', 'direct', ConnectionRoute.direct, 200),
  ];

  test('every column holds all the traffic', () {
    final model = build(flows);
    final shown = flows.fold<double>(0, (s, f) => s + f.shown);
    for (final column in model.columns) {
      expect(column.fold<double>(0, (s, n) => s + n.weight), closeTo(shown, 1e-6));
      expect(column.fold<double>(0, (s, n) => s + n.real), closeTo(1000, 1e-6));
    }
    expect(model.columns.map((c) => c.length), [3, 3, 3]);
  });

  test('a ribbon is as heavy at both its nodes', () {
    final model = build(flows);
    for (final node in model.columns[1]) {
      final into = node.inLinks.fold<double>(0, (s, l) => s + l.weight);
      final out = node.outLinks.fold<double>(0, (s, l) => s + l.weight);
      expect(into, closeTo(out, 1e-6), reason: node.label);
    }
  });

  test('the small and the many are added up in other; direct and blocked stay', () {
    final many = [
      for (var i = 0; i < 12; i++) flow('app$i', 'r$i', 'srv$i', ConnectionRoute.vpn, 100.0 - i),
      flow('tiny', 'tiny', 'direct', ConnectionRoute.direct, 1),
      flow('tiny', 'ads', 'blocked', ConnectionRoute.block, 1),
    ];
    final model = build(many);
    expect(model.columns[0].length, lessThanOrEqualTo(7));
    expect(model.columns[0].any((n) => n.label == 'other'), isTrue);
    final outs = model.columns[2].map((n) => n.label).toList();
    expect(outs, containsAll(['direct', 'blocked']));
    for (final column in model.columns) {
      expect(column.fold<double>(0, (s, n) => s + n.real), closeTo(many.fold<double>(0, (s, f) => s + f.weight), 1e-6));
    }
  });

  test('the layout keeps nodes inside the height and apart', () {
    final model = build(flows)..layout(300);
    for (final column in model.columns) {
      var bottom = -1.0;
      for (final n in column) {
        expect(n.y, greaterThanOrEqualTo(bottom - 1e-6));
        bottom = n.y + n.h;
      }
      expect(bottom, lessThanOrEqualTo(300 + 1e-6));
    }
    // ribbons stay inside their nodes
    for (final l in model.links) {
      expect(l.fromY, greaterThanOrEqualTo(l.from.y - 1e-6));
      expect(l.fromY + model.thickness(l), lessThanOrEqualTo(l.from.y + l.from.h + 1e-6));
      expect(l.toY, greaterThanOrEqualTo(l.to.y - 1e-6));
      expect(l.toY + model.thickness(l), lessThanOrEqualTo(l.to.y + l.to.h + 1e-6));
    }
  });

  test('a node knows its flows, a ribbon too', () {
    final model = build(flows);
    final chrome = model.columns[0].firstWhere((n) => n.label == 'Chrome');
    expect(chrome.flows.length, 2);
    for (final l in chrome.outLinks) {
      expect(l.flows.every(chrome.flows.contains), isTrue);
    }
    expect(model.columns[2].firstWhere((n) => n.label == 'direct').flows.length, 2);
  });

  test('a tap finds a node and then a ribbon', () {
    final model = build(flows)..layout(300);
    final g = SankeyGeometry(360);
    final tg = model.columns[0].firstWhere((n) => n.label == 'Telegram');
    expect(g.hit(tg, 360).contains(Offset(20, tg.y + tg.h / 2)), isTrue);
    final link = model.links.firstWhere((l) => l.from.label == 'Telegram');
    final path = g.ribbon(model, link);
    final x = (g.xs[0] + SankeyGeometry.nodeW + g.xs[1]) / 2;
    expect(path.contains(Offset(x, (link.fromY + link.toY) / 2 + model.thickness(link) / 2)), isTrue);
  });

  test('one huge flow does not swallow the rest', () {
    final model = build([
      flow('big', 'r1', 'o1', ConnectionRoute.vpn, 400000),
      flow('a', 'r2', 'o2', ConnectionRoute.vpn, 40000),
      flow('b', 'r3', 'o3', ConnectionRoute.vpn, 30000),
    ]);
    final big = model.columns[0].firstWhere((n) => n.label == 'big');
    final a = model.columns[0].firstWhere((n) => n.label == 'a');
    // 10 times the traffic, about 3 times the width
    expect(big.weight / a.weight, lessThan(3.5));
    expect(big.real / a.real, closeTo(10, 1e-9));
  });


  group('even: nothing changes size or place as traffic moves', () {
    SankeyModel even(List<SankeyFlow> f) =>
        SankeyModel.build(f, otherApp: 'other', otherRule: 'other', otherOut: 'other', even: true);

    test('every route is as thick as any other, whatever its traffic', () {
      final model = even([
        flow('Chrome', 'a.com', 'direct', ConnectionRoute.direct, 5000000),
        flow('Telegram', 'b.org', 'SE', ConnectionRoute.vpn, 30),
        flow('Disk', 'c.net', 'direct', ConnectionRoute.direct, 400),
      ]);
      final weights = model.links.map((l) => l.weight).toSet();
      expect(weights, {1.0});
    });

    test('two connections of one route are one route', () {
      final model = even([
        flow('Chrome', 'a.com', 'direct', ConnectionRoute.direct, 100),
        flow('Chrome', 'a.com', 'direct', ConnectionRoute.direct, 900),
      ]);
      expect(model.links.map((l) => l.weight), everyElement(1.0));
      expect(model.total, 1);
      expect(model.columns[0].single.real, 1000);
    });

    test('the same places when the amounts change', () {
      List<String> order(double a, double b) => even([
        flow('Zed', 'z.com', 'direct', ConnectionRoute.direct, a),
        flow('Alpha', 'a.com', 'direct', ConnectionRoute.direct, b),
      ]).columns[0].map((n) => n.label).toList();
      expect(order(10, 9000), order(9000, 10));
      expect(order(10, 9000), ['Alpha', 'Zed']);
    });

    test('a node keeps its height when only its traffic grows', () {
      double height(double bytes) {
        final model = even([
          flow('Chrome', 'a.com', 'direct', ConnectionRoute.direct, bytes),
          flow('Disk', 'b.com', 'direct', ConnectionRoute.direct, 100),
        ])..layout(400);
        return model.columns[0].firstWhere((n) => n.label == 'Chrome').h;
      }

      expect(height(1000), height(900000));
    });

    test('few routes stay slim, not huge', () {
      final model = even([flow('Chrome', 'a.com', 'direct', ConnectionRoute.direct, 5)])..layout(500);
      expect(model.columns[0].single.h, lessThanOrEqualTo(44));
    });
  });

  test('a host as its site', () {
    expect(siteOf('rr4---sn.googlevideo.com'), 'googlevideo.com');
    expect(siteOf('api.telegram.org'), 'telegram.org');
    expect(siteOf('a.b.example.co.uk'), 'example.co.uk');
    expect(siteOf('192.168.31.1'), '192.168.31.1');
    expect(siteOf('ya.ru'), 'ya.ru');
    expect(siteOf(''), '');
  });

  test('speed: smoothed, and the reading alone after a long gap', () {
    expect(smoothRate(previous: 0, bytes: 2000, elapsed: const Duration(seconds: 2)), 500);
    expect(smoothRate(previous: 1000, bytes: 0, elapsed: const Duration(seconds: 2)), 500);
    expect(smoothRate(previous: 5000, bytes: 3000, elapsed: const Duration(seconds: 30)), 100);
    expect(smoothRate(previous: 700, bytes: 10, elapsed: const Duration(milliseconds: 50)), 700);
    expect(smoothRate(previous: 400, bytes: -5, elapsed: const Duration(seconds: 2)), 200);
  });

  test('no traffic, no diagram', () {
    expect(build([]).isEmpty, isTrue);
    expect(build([flow('a', 'r', 'o', ConnectionRoute.vpn, 0)]).isEmpty, isTrue);
  });
}
