import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';

void main() {
  test('HTTPS marks a delay good later than HTTP does (the TLS handshake takes round trips)', () {
    final http = siteGrade(false);
    final https = siteGrade(true);
    expect((http.good, http.slow), (150, 300));
    expect(https.good, greaterThan(http.good));
    expect(https.slow, greaterThan(http.slow));
    expect(https.scale, greaterThan(http.scale));
    // a delay that is slow over HTTP is still good over HTTPS
    expect(200 < https.good, isTrue);
    expect(200 >= http.good, isTrue);
  });
}
