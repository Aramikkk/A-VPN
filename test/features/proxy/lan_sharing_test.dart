import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/lan_sharing.dart';

void main() {
  test('only private IPv4 addresses are offered to other devices', () {
    for (final ip in ['192.168.43.1', '10.193.12.5', '172.20.10.1', '172.31.255.254']) {
      expect(LanSharing.isPrivate(ip), isTrue, reason: ip);
    }
    for (final ip in ['8.8.8.8', '172.32.0.1', '100.64.0.1', 'fe80::1', '192.169.0.1']) {
      expect(LanSharing.isPrivate(ip), isFalse, reason: ip);
    }
  });
}
