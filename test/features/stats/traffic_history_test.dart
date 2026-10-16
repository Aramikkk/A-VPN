import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _NoStats extends StatsNotifier {
  @override
  Stream<SystemInfo> build() => const Stream.empty();
}

final _session = DateTime(2026, 10, 16, 12);

SystemInfo _reading(int down, int up) =>
    SystemInfo(downlinkTotal: Int64(down), uplinkTotal: Int64(up))
      ..unknownFields.mergeVarintField(102, Int64(_session.millisecondsSinceEpoch));

void main() {
  late ProviderContainer container;
  late TrafficHistory history;

  setUp(() {
    container = ProviderContainer(overrides: [statsNotifierProvider.overrideWith(_NoStats.new)]);
    container.read(trafficHistoryProvider);
    history = container.read(trafficHistoryProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('ten minutes: slots on the clock, the fastest second, down and up apart', () {
    final start = _session.add(const Duration(seconds: 1));
    var down = 0;
    var up = 0;
    history.take(_reading(0, 0), start);
    // a burst: 2 MB/s down, 100 KB/s up for 3 s, read at uneven moments (1.3 s, then 1.7 s apart)
    down += (1.3 * 2000000).round();
    up += (1.3 * 100000).round();
    history.take(_reading(down, up), start.add(const Duration(milliseconds: 1300)));
    down += (1.7 * 2000000).round();
    up += (1.7 * 100000).round();
    history.take(_reading(down, up), start.add(const Duration(milliseconds: 3000)));
    final now = start.add(const Duration(seconds: 12));
    final series = history.series(StatsRange.tenMinutes, now);
    final peak = series.points.map((p) => p.down).reduce((a, b) => a > b ? a : b);
    final peakUp = series.points.map((p) => p.up).reduce((a, b) => a > b ? a : b);
    // a burst read every ~1.5 s still shows about its speed, not a fifth of it
    expect(peak, greaterThan(1500000));
    expect(peakUp, lessThan(200000));
    expect(series.total.down, down);
    expect(series.total.up, up);
    // the same moment a second later: the slots don't shift
    final later = history.series(StatsRange.tenMinutes, now.add(const Duration(seconds: 1)));
    expect(later.points.take(series.points.length).toList(), series.points);
  });

  test('an hour: the minute under way counts by the seconds it has had', () {
    final start = DateTime(2026, 10, 16, 12, 30, 0);
    history.take(_reading(0, 0), start);
    for (var s = 1; s <= 10; s++) {
      history.take(_reading(s * 1000000, 0), start.add(Duration(seconds: s)));
    }
    final series = history.series(StatsRange.hour, start.add(const Duration(seconds: 10)));
    // 1 MB/s for the 10 s of this minute, not 10 MB spread over a whole minute
    expect(series.points.last.down, closeTo(1000000, 1));
  });
}
