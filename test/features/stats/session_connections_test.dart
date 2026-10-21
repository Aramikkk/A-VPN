import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';

SeenConnection _conn(String id, DateTime start, {int? session}) => SeenConnection(
  id: id,
  session: session,
  app: 'app',
  host: 'host',
  port: 443,
  network: 'tcp',
  route: ConnectionRoute.vpn,
  outbound: '',
  rule: '',
  start: start,
  up: 1,
  down: 1,
  active: true,
);

void main() {
  final start = DateTime(2026, 10, 21, 12);
  final state = ConnectionsState(
    sessionItems: [
      _conn('this', start.add(const Duration(minutes: 5)), session: start.millisecondsSinceEpoch),
      _conn('unstamped', start.add(const Duration(minutes: 6))),
      _conn('old', start.subtract(const Duration(hours: 2)), session: start.millisecondsSinceEpoch - 1),
    ],
  );

  test('the VPN on: this session\'s connections only', () {
    final list = sessionConnections(state, connected: true, sessionStart: start);
    expect(list.map((c) => c.id), ['this', 'unstamped']);
  });

  test('the VPN off or the session unknown: none', () {
    expect(sessionConnections(state, connected: false, sessionStart: start), isEmpty);
    expect(sessionConnections(state, connected: true, sessionStart: null), isEmpty);
  });
}
