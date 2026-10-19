import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';

void main() {
  test('the ping address follows the method, kept as http://', () {
    expect(pingUrl('http://www.gstatic.com/generate_204', true), 'https://www.gstatic.com/generate_204');
    expect(pingUrl('http://www.gstatic.com/generate_204', false), 'http://www.gstatic.com/generate_204');
    expect(pingUrl('https://example.org/ping', false), 'http://example.org/ping');
    expect(pingUrl('socks://x', true), 'socks://x');
  });

  test('HTTPS offers only the targets that answer over it', () {
    expect(pingTargetsFor(false), pingTargets);
    expect(pingTargetsFor(true).any((p) => p.url.contains('msftconnecttest')), isFalse);
    expect(pingTargetsFor(true).first.url, pingTargets.first.url);
    // the next target over HTTPS skips Microsoft
    final firefox = pingTargets.firstWhere((p) => p.url.contains('firefox')).url;
    expect(nextPingTarget(firefox, https: true).url, pingTargets.first.url);
  });
}
