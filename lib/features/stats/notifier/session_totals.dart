import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Traffic totals of the whole VPN session. The core counts per configuration, and every reload (a network
/// change, a server switch, auto-pause) starts its counters from zero while the session goes on; this adds
/// up what each configuration counted until the session itself ends.
typedef SessionTotals = ({int up, int down, int? vpnUp, int? vpnDown});

final sessionTotalsProvider = NotifierProvider<SessionTotalsNotifier, SessionTotals>(SessionTotalsNotifier.new);

class SessionTotalsNotifier extends Notifier<SessionTotals> {
  DateTime? _session;
  SessionTotals _carried = (up: 0, down: 0, vpnUp: 0, vpnDown: 0);
  SessionTotals _last = (up: 0, down: 0, vpnUp: 0, vpnDown: 0);

  @override
  SessionTotals build() {
    ref.listen(statsNotifierProvider, (_, next) {
      final stats = next.valueOrNull;
      if (stats != null) state = add(stats);
    });
    return (up: 0, down: 0, vpnUp: null, vpnDown: null);
  }

  /// Takes one reading from the core and returns the session's totals so far.
  SessionTotals add(SystemInfo stats) {
    final session = stats.sessionStartedAt;
    final now = (
      up: stats.uplinkTotal.toInt(),
      down: stats.downlinkTotal.toInt(),
      vpnUp: stats.vpnUplinkTotal,
      vpnDown: stats.vpnDownlinkTotal,
    );
    if (session == null || session != _session) {
      // a new session (or the VPN is off): start over
      _session = session;
      _carried = (up: 0, down: 0, vpnUp: 0, vpnDown: 0);
    } else if (now.up < _last.up || now.down < _last.down) {
      // the core's counters went back to zero within the session: keep what they had counted
      _carried = (
        up: _carried.up + _last.up,
        down: _carried.down + _last.down,
        vpnUp: (_carried.vpnUp ?? 0) + (_last.vpnUp ?? 0),
        vpnDown: (_carried.vpnDown ?? 0) + (_last.vpnDown ?? 0),
      );
    }
    _last = now;
    return (
      up: _carried.up + now.up,
      down: _carried.down + now.down,
      vpnUp: now.vpnUp == null ? null : (_carried.vpnUp ?? 0) + now.vpnUp!,
      vpnDown: now.vpnDown == null ? null : (_carried.vpnDown ?? 0) + now.vpnDown!,
    );
  }
}
