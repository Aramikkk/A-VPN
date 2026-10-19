import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hiddify/core/directories/directories_provider.dart';
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
  File? _file;
  Future<void> _pendingSave = Future.value();
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, Object?> snapshot() => {
    'session': _session?.millisecondsSinceEpoch,
    'carried': [_carried.up, _carried.down, _carried.vpnUp, _carried.vpnDown],
    'last': [_last.up, _last.down, _last.vpnUp, _last.vpnDown],
  };

  void restore(Map<String, dynamic> json) {
    SessionTotals read(String key) {
      final v = json[key] as List;
      return (up: v[0] as int, down: v[1] as int, vpnUp: v[2] as int?, vpnDown: v[3] as int?);
    }

    final session = json['session'] as int;
    final carried = read('carried');
    final last = read('last');
    _session = DateTime.fromMillisecondsSinceEpoch(session);
    _carried = carried;
    _last = last;
    _total = (
      up: carried.up + last.up,
      down: carried.down + last.down,
      vpnUp: last.vpnUp == null ? null : (carried.vpnUp ?? 0) + last.vpnUp!,
      vpnDown: last.vpnDown == null ? null : (carried.vpnDown ?? 0) + last.vpnDown!,
    );
  }

  DateTime? _session;
  SessionTotals _carried = (up: 0, down: 0, vpnUp: 0, vpnDown: 0);
  SessionTotals _last = (up: 0, down: 0, vpnUp: 0, vpnDown: 0);
  SessionTotals _total = (up: 0, down: 0, vpnUp: null, vpnDown: null);

  @override
  SessionTotals build() {
    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    if (dirs != null) {
      _file = File('${dirs.baseDir.path}/session_totals.json');
      try {
        if (_file!.existsSync()) restore(jsonDecode(_file!.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {
        /* An unreadable snapshot is ignored. */
      }
    }
    ref.onDispose(_save);
    ref.listen(statsNotifierProvider, (_, next) {
      final stats = next.valueOrNull;
      if (stats != null) state = add(stats);
    });
    return _total;
  }

  /// Takes one reading from the core and returns the session's totals so far.
  SessionTotals add(SystemInfo stats) {
    final session = stats.sessionStartedAt;
    // A blank reading is also emitted while the statistics stream reconnects.
    // Only an actual new core session can reset the accumulated traffic.
    if (session == null) return _total;
    final now = (
      up: stats.uplinkTotal.toInt(),
      down: stats.downlinkTotal.toInt(),
      vpnUp: stats.vpnUplinkTotal,
      vpnDown: stats.vpnDownlinkTotal,
    );
    if (session != _session) {
      // A manual VPN restart starts a new session.
      _session = session;
      _carried = (up: 0, down: 0, vpnUp: 0, vpnDown: 0);
    } else {
      // Outbound counters can reset on their own when servers are replaced.
      int carry(int? current, int? previous, int? total) =>
          (total ?? 0) + (current != null && previous != null && current < previous ? previous : 0);
      _carried = (
        up: carry(now.up, _last.up, _carried.up),
        down: carry(now.down, _last.down, _carried.down),
        vpnUp: carry(now.vpnUp, _last.vpnUp, _carried.vpnUp),
        vpnDown: carry(now.vpnDown, _last.vpnDown, _carried.vpnDown),
      );
    }
    _last = now;
    _total = (
      up: _carried.up + now.up,
      down: _carried.down + now.down,
      vpnUp: now.vpnUp == null ? null : (_carried.vpnUp ?? 0) + now.vpnUp!,
      vpnDown: now.vpnDown == null ? null : (_carried.vpnDown ?? 0) + now.vpnDown!,
    );
    // Live counters still update every second; disk checkpoints need not force a
    // filesystem flush at that frequency. Disposal saves the final reading too.
    final timestamp = DateTime.now();
    if (timestamp.difference(_saved) >= const Duration(seconds: 10)) {
      _saved = timestamp;
      _save();
    }
    return _total;
  }

  void _save() {
    final file = _file;
    if (file != null && _session != null) {
      final json = jsonEncode(snapshot());
      // Serialize writes so an older snapshot cannot overwrite a newer reading.
      _pendingSave = _pendingSave.then((_) async {
        try {
          await file.writeAsString(json, flush: true);
        } catch (_) {
          /* Keep live totals when storage is unavailable. */
        }
      });
      unawaited(_pendingSave);
    }
  }
}
