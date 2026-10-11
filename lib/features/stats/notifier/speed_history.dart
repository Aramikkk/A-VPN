import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The last minute of download and upload speed (one sample a second, oldest first), for the speed graph.
final speedHistoryProvider = NotifierProvider<SpeedHistory, List<({int down, int up})>>(SpeedHistory.new);

class SpeedHistory extends Notifier<List<({int down, int up})>> {
  static const length = 60;

  @override
  List<({int down, int up})> build() {
    ref.listen(statsNotifierProvider, (_, next) {
      final stats = next.valueOrNull;
      if (stats == null) return;
      final sample = (down: stats.downlink.toInt(), up: stats.uplink.toInt());
      state = [...state.skip(state.length >= length ? state.length - length + 1 : 0), sample];
    });
    return const [];
  }
}
