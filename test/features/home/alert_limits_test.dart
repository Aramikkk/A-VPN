import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/model/alert_limits.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';

void main() {
  group('alertLimits', () {
    test('Wi-Fi keeps the marks it had: a ping of 300 ms or a loss of 15 % is the accent', () {
      final w = alertLimits(mobile: false);
      expect(w.ping, 300);
      expect(w.loss, 15.0);
    });

    test('mobile data is milder: a ping of 200-230 ms and a loss of 30-40 % are what it is, not an alarm', () {
      final m = alertLimits(mobile: true);
      for (final ping in [200, 230, 300, 400]) {
        expect(ping >= m.ping, isFalse, reason: '$ping ms is normal on mobile data');
      }
      for (final loss in [30.0, 40.0]) {
        expect(loss >= m.loss, isFalse, reason: '$loss % is normal on mobile data');
      }
    });

    test('mobile data still has an alarm: far worse than usual is the accent', () {
      final m = alertLimits(mobile: true);
      expect(800 >= m.ping, isTrue);
      expect(80.0 >= m.loss, isTrue);
    });

    test('mobile data is never stricter than Wi-Fi', () {
      final w = alertLimits(mobile: false);
      final m = alertLimits(mobile: true);
      expect(m.ping, greaterThanOrEqualTo(w.ping));
      expect(m.loss, greaterThanOrEqualTo(w.loss));
      expect(m.siteSlow, greaterThanOrEqualTo(w.siteSlow));
    });
  });

  group('siteGrade on mobile data', () {
    test('a site at 181-231 ms is good on mobile data, over HTTP too', () {
      final g = siteGrade(false, mobile: true);
      for (final ms in [181, 207, 231]) {
        expect(ms < g.good, isTrue, reason: '$ms ms is good on mobile data');
      }
    });

    test('Wi-Fi marks are as they were', () {
      expect(siteGrade(false).good, 150);
      expect(siteGrade(true).good, 250);
      expect(siteGrade(false, mobile: false).slow, 300);
    });

    test('mobile marks are wider than Wi-Fi ones for both methods', () {
      for (final https in [false, true]) {
        final w = siteGrade(https);
        final m = siteGrade(https, mobile: true);
        expect(m.good, greaterThan(w.good));
        expect(m.slow, greaterThan(w.slow));
        expect(m.scale, greaterThan(w.scale));
      }
    });
  });
}
