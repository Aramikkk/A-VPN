import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// When the VPN session started, as the core last said, kept while the statistics stream blinks (it comes back
/// empty for a moment when the app returns from the background, and the traffic card flipped to the whole day's
/// list and back). Null until the core has said.
/// Gone with its last listener, as the statistics are (no polling for nothing).
final sessionStartProvider = AutoDisposeNotifierProvider<SessionStart, DateTime?>(SessionStart.new);

class SessionStart extends AutoDisposeNotifier<DateTime?> {
  @override
  DateTime? build() {
    ref.listen(statsNotifierProvider, (_, next) {
      final start = next.valueOrNull?.sessionStartedAt;
      if (start != null && start != state) state = start;
    });
    return ref.read(statsNotifierProvider).valueOrNull?.sessionStartedAt;
  }
}
