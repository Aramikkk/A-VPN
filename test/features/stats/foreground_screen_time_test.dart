import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/foreground_screen_time.dart';

void main() {
  test('screen-time UI polling defaults to a low frequency', () {
    expect(foregroundScreenTimePollInterval, const Duration(seconds: 10));
  });

  test('screen-time snapshot keeps positive app durations and usage-access state', () {
    final snapshot = parseForegroundScreenTime({
      'hasUsageAccess': true,
      'apps': {'com.example.reader': 12_345, 'com.example.zero': 0, 'invalid': 'later'},
    });

    expect(snapshot.hasUsageAccess, isTrue);
    expect(snapshot.apps, {'com.example.reader': const Duration(milliseconds: 12_345)});
  });

  test('screen-time snapshot polling waits for its configured interval', () {
    fakeAsync((async) {
      var reads = 0;
      pollForegroundScreenTime(() async {
        reads++;
        return {'hasUsageAccess': true};
      }, interval: const Duration(seconds: 10)).listen((_) {});

      async.flushMicrotasks();
      expect(reads, 1);
      async.elapse(const Duration(seconds: 9));
      expect(reads, 1);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(reads, 2);
    });
  });
}
