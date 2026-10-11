import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

SystemInfo reading(int up, int down, {int vpn = 0, int start = 1000}) =>
    SystemInfo(uplinkTotal: Int64(up), downlinkTotal: Int64(down))
      ..unknownFields.mergeVarintField(100, Int64(vpn))
      ..unknownFields.mergeVarintField(101, Int64(vpn))
      ..unknownFields.mergeVarintField(102, Int64(start));

void main() {
  test('a reload within the session keeps what was counted before it', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(10, 100, vpn: 50));
    totals.add(reading(20, 300, vpn: 80));
    final after = totals.add(reading(5, 40, vpn: 10)); // the core restarted its counters
    expect(after.up, 25);
    expect(after.down, 340);
    expect(after.vpnDown, 90);
  });

  test('a new session starts from zero', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(20, 300));
    final next = totals.add(reading(5, 40, start: 2000));
    expect(next.down, 40);
  });
}
