import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];

  test('reads the VPN totals the core sends as unknown fields', () {
    // what A-VPN's core puts on the wire: the known totals plus fields 100 and 101
    final sent = SystemInfo(uplinkTotal: Int64(10), downlinkTotal: Int64(20))
      ..unknownFields.mergeVarintField(100, Int64(3))
      ..unknownFields.mergeVarintField(101, Int64(7));
    final received = SystemInfo.fromBuffer(sent.writeToBuffer());
    expect(received.downlinkTotal.toInt(), 20);
    expect(received.vpnUplinkTotal, 3);
    expect(received.vpnDownlinkTotal, 7);
  });

  test('a core without them gives null', () {
    expect(SystemInfo(downlinkTotal: Int64(5)).vpnDownlinkTotal, isNull);
  });

  test('formats sizes', () {
    expect(formatBytes(0, units), '0 Б');
    expect(formatBytes(1536, units), '1,5 КБ');
    expect(formatBytes(150 * 1024 * 1024, units), '150 МБ');
    expect(formatBytes(10 * 1024 * 1024, units), '10 МБ');
    expect(formatBytes(3 * 1024 * 1024 * 1024 + 400 * 1024 * 1024, units), '3,4 ГБ');
  });
}
