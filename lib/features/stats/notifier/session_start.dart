import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// How many times the user switched the VPN off by hand in this run of the app. A session goes on through an auto-pause
/// and a change of network (the core starts again then, with a new start time), and ends only with this.
int manualStopCount = 0;

/// When the VPN session started, as the core last said, kept while the statistics stream blinks (it comes back
/// empty for a moment when the app returns from the background, and the traffic card flipped to the whole day's
/// list and back). Null until the core has said.
/// Gone with its last listener, as the statistics are (no polling for nothing).
final sessionStartProvider = AutoDisposeNotifierProvider<SessionStart, DateTime?>(SessionStart.new);

class SessionStart extends AutoDisposeNotifier<DateTime?> {
  /// the core's own start time last seen, and the count of manual stops then
  DateTime? _core;
  int _stops = 0;

  void _take(DateTime? start) {
    if (start == null || start == _core) return;
    final first = _core == null;
    _core = start;
    // a new run of the core: the same session if the user didn't switch the VPN off (auto-pause, Wi-Fi to LTE)
    if (first || state == null || manualStopCount != _stops) {
      state = start;
    }
    _stops = manualStopCount;
  }

  @override
  DateTime? build() {
    _stops = manualStopCount;
    ref.listen(statsNotifierProvider, (_, next) => _take(next.valueOrNull?.sessionStartedAt));
    final first = ref.read(statsNotifierProvider).valueOrNull?.sessionStartedAt;
    _core = first;
    return first;
  }
}
