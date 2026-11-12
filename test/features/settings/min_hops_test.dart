import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/data/min_hops.dart';

void main() {
  group('hopsTolerance', () {
    test('off: the setting as it is', () {
      expect(hopsTolerance(minHops: false, mobile: false, user: 50), 50);
      expect(hopsTolerance(minHops: false, mobile: true, user: 25), 25);
    });

    test('on: a server is left only when another is far faster, a little more on mobile data (its pings swing more)', () {
      expect(hopsTolerance(minHops: true, mobile: false, user: 50), 300);
      expect(hopsTolerance(minHops: true, mobile: true, user: 25), 350);
    });

    test('on: a threshold the user set higher than that stays', () {
      expect(hopsTolerance(minHops: true, mobile: false, user: 700), 700);
      expect(hopsTolerance(minHops: true, mobile: true, user: 500), 500);
    });
  });

  group('hopsInterval', () {
    test('off: the interval as it is', () {
      expect(hopsInterval(minHops: false, user: const Duration(minutes: 10)), const Duration(minutes: 10));
    });

    test('on: the servers are checked every half hour at the most often', () {
      expect(hopsInterval(minHops: true, user: const Duration(minutes: 10)), const Duration(minutes: 30));
      expect(hopsInterval(minHops: true, user: const Duration(seconds: 30)), const Duration(minutes: 30));
    });

    test('on: a longer interval the user set stays', () {
      expect(hopsInterval(minHops: true, user: const Duration(hours: 2)), const Duration(hours: 2));
    });
  });
}
