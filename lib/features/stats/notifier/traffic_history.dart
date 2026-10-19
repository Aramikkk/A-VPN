import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The periods the Statistics tab can show.
enum StatsRange { minute, tenMinutes, hour, day, all }

/// The Connections and Topology tabs keep a day that starts at 03:00 local time: everything since then counts
/// as today, and at 03:00 they start over (a night out past midnight still counts with the evening).
const statsDayStartHour = 3;

/// The start of the statistics day [now] is in.
DateTime statsDayStart(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, statsDayStartHour);
  return now.isBefore(today) ? DateTime(now.year, now.month, now.day - 1, statsDayStartHour) : today;
}

/// Bytes moved in some stretch of time: down, up, and how much of it went through the VPN.
class TrafficAmount {
  TrafficAmount([this.down = 0, this.up = 0, this.vpn = 0]);

  int down;
  int up;
  int vpn;

  int get total => down + up;

  void add(int d, int u, int v) {
    down += d;
    up += u;
    vpn += v;
  }

  List<int> toJson() => [down, up, vpn];

  factory TrafficAmount.fromJson(Object? json) {
    final l = json is List ? json.whereType<num>().map((n) => n.toInt()).toList() : const <int>[];
    return TrafficAmount(l.isNotEmpty ? l[0] : 0, l.length > 1 ? l[1] : 0, l.length > 2 ? l[2] : 0);
  }
}

/// A period's graph and totals: the average speed in each slot (oldest first, as many slots as [slots]), the
/// length of a slot, and what moved in the whole period.
typedef RangeSeries = ({List<({int down, int up})> points, int slots, Duration slot, TrafficAmount total});

/// The traffic, kept by the second for ten minutes, by the minute for two days and by the day for good, and
/// saved to disk, so the Statistics tab can show the last minute, ten minutes, hour, day or all the time. It
/// counts from the core's totals: when the app was away the traffic in between is spread over the time it was
/// away.
final trafficHistoryProvider = NotifierProvider<TrafficHistory, int>(TrafficHistory.new);

class TrafficHistory extends Notifier<int> {
  static const _secondsKept = 600;
  static const _minutesKept = 2 * 24 * 60;

  /// by second since the epoch: the readings come about once a second but not exactly, so each one is spread over
  /// the seconds it covers, and the graph's slots are whole stretches of clock time (they kept shifting by a
  /// reading, and the ten-minute graph jumped about as it redrew)
  final _seconds = <int, TrafficAmount>{};

  /// by minute since the epoch
  final _minutes = <int, TrafficAmount>{};

  /// by local day (days since the epoch)
  final _days = <int, TrafficAmount>{};

  // the core's counters at the last reading, to take the difference from
  int? _session;
  int _lastTotal = -1;
  int _lastVpn = 0;
  int? _lastVpnUp;
  int? _lastVpnDown;
  // down and up apart (not kept on disk: the first reading after a start splits by the session's share)
  int _lastDown = -1;
  int _lastUp = -1;
  DateTime? _lastAt;
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loaded = false;

  File? get _file {
    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    return dirs == null ? null : File('${dirs.baseDir.path}/traffic_history.json');
  }

  @override
  int build() {
    ref.listen(statsNotifierProvider, (_, next) {
      final stats = next.valueOrNull;
      if (stats != null) _take(stats, DateTime.now());
    });
    return 0;
  }

  void _load() {
    _loaded = true;
    try {
      final file = _file;
      if (file == null || !file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      (json['minutes'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => _minutes[int.parse(k)] = TrafficAmount.fromJson(v),
      );
      (json['days'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _days[int.parse(k)] = TrafficAmount.fromJson(v));
      _session = json['session'] as int?;
      _lastTotal = (json['lastTotal'] as int?) ?? -1;
      _lastVpn = (json['lastVpn'] as int?) ?? 0;
      _lastUp = json['lastUp'] as int? ?? -1;
      _lastDown = json['lastDown'] as int? ?? -1;
      _lastVpnUp = json['lastVpnUp'] as int?;
      _lastVpnDown = json['lastVpnDown'] as int?;
      final at = json['lastAt'] as int?;
      _lastAt = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    } catch (_) {
      // an unreadable history starts over
    }
  }

  void _save() {
    final file = _file;
    if (file == null) return;
    _saved = DateTime.now();
    final json = jsonEncode({
      'minutes': {for (final e in _minutes.entries) '${e.key}': e.value.toJson()},
      'days': {for (final e in _days.entries) '${e.key}': e.value.toJson()},
      'session': _session,
      'lastTotal': _lastTotal,
      'lastVpn': _lastVpn,
      'lastUp': _lastUp,
      'lastDown': _lastDown,
      'lastVpnUp': _lastVpnUp,
      'lastVpnDown': _lastVpnDown,
      'lastAt': _lastAt?.millisecondsSinceEpoch,
    });
    unawaited(file.writeAsString(json).then((_) {}, onError: (_) {}));
  }

  /// A reading of the core's counters at [now], as the stats stream gives them.
  @visibleForTesting
  void take(SystemInfo stats, DateTime now) => _take(stats, now);

  void _take(SystemInfo stats, DateTime now) {
    if (!_loaded) _load();
    final session = stats.sessionStartedAt?.millisecondsSinceEpoch;
    if (session == null) return;
    final up = stats.uplinkTotal.toInt();
    final down = stats.downlinkTotal.toInt();
    final total = up + down;
    final vpn = (stats.vpnUplinkTotal ?? 0) + (stats.vpnDownlinkTotal ?? 0);
    int dTotal;
    int dVpn;
    // the counters as they were before this reading (0: counting from the start)
    var fromDown = _lastDown;
    var fromUp = _lastUp;
    if (session != _session || _lastTotal < 0) {
      // a new VPN session (or the first reading): count from its start if it began after the last reading
      final fresh = _lastAt == null || session >= _lastAt!.millisecondsSinceEpoch;
      dTotal = fresh ? total : 0;
      dVpn = fresh ? vpn : 0;
      fromDown = fresh ? 0 : down;
      fromUp = fresh ? 0 : up;
    } else {
      int delta(int current, int previous) => current < previous ? current : current - previous;
      fromDown = _lastDown < 0 ? -1 : (down < _lastDown ? 0 : _lastDown);
      fromUp = _lastUp < 0 ? -1 : (up < _lastUp ? 0 : _lastUp);
      dTotal = _lastDown < 0 || _lastUp < 0 ? delta(total, _lastTotal) : down - fromDown + up - fromUp;
      final vu = stats.vpnUplinkTotal;
      final vd = stats.vpnDownlinkTotal;
      dVpn = vu != null && vd != null && _lastVpnUp != null && _lastVpnDown != null
          ? delta(vu, _lastVpnUp!) + delta(vd, _lastVpnDown!)
          : delta(vpn, _lastVpn);
    }
    final known = fromDown >= 0 && fromUp >= 0 && down >= fromDown && up >= fromUp;
    final dDown = known ? down - fromDown : (total == 0 ? 0 : (dTotal * down / total).round());
    final dUp = known ? up - fromUp : dTotal - dDown;
    final from = _lastAt;
    _session = session;
    _lastTotal = total;
    _lastVpn = vpn;
    _lastVpnUp = stats.vpnUplinkTotal;
    _lastVpnDown = stats.vpnDownlinkTotal;
    _lastDown = down;
    _lastUp = up;
    _lastAt = now;

    final gap = from == null ? Duration.zero : now.difference(from);
    if (gap > const Duration(seconds: 5) && gap < const Duration(days: 7)) {
      // the app was away: spread what moved meanwhile over the minutes it was away
      final first = from!.millisecondsSinceEpoch ~/ 60000;
      final last = now.millisecondsSinceEpoch ~/ 60000;
      final n = last - first + 1;
      for (var m = first; m <= last; m++) {
        _addMinute(m, dDown ~/ n, dUp ~/ n, dVpn ~/ n);
      }
    } else {
      _addMinute(now.millisecondsSinceEpoch ~/ 60000, dDown, dUp, dVpn);
      // spread over the seconds since the last reading
      final last = now.millisecondsSinceEpoch ~/ 1000;
      final first = from == null ? last : math.min(last, from.millisecondsSinceEpoch ~/ 1000 + 1);
      final n = last - first + 1;
      for (var sec = first; sec <= last; sec++) {
        // the remainder in the last second, so nothing is lost to rounding
        final tail = sec == last;
        _seconds
            .putIfAbsent(sec, TrafficAmount.new)
            .add(
              tail ? dDown - dDown ~/ n * (n - 1) : dDown ~/ n,
              tail ? dUp - dUp ~/ n * (n - 1) : dUp ~/ n,
              tail ? dVpn - dVpn ~/ n * (n - 1) : dVpn ~/ n,
            );
      }
      _seconds.removeWhere((sec, _) => sec <= last - _secondsKept);
    }
    final oldest = now.millisecondsSinceEpoch ~/ 60000 - _minutesKept;
    _minutes.removeWhere((m, _) => m < oldest);
    if (now.difference(_saved) > const Duration(minutes: 1)) _save();
    state = state + 1;
  }

  void _addMinute(int minute, int down, int up, int vpn) {
    _minutes.putIfAbsent(minute, TrafficAmount.new).add(down, up, vpn);
    final local = DateTime.fromMillisecondsSinceEpoch(minute * 60000);
    final day = DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ 86400000;
    _days.putIfAbsent(day, TrafficAmount.new).add(down, up, vpn);
  }

  /// The graph and the totals for [range], as of [now].
  RangeSeries series(StatsRange range, [DateTime? now]) {
    final at = now ?? DateTime.now();
    final minuteNow = at.millisecondsSinceEpoch ~/ 60000;
    // the slots are whole stretches of clock time ending with the last complete one, so they don't shift as the
    // readings come in; each shows its fastest second (an average of five flattened every burst to a fraction of
    // the speed the phone had), and a second with nothing moved counts as nothing
    RangeSeries fromSeconds(int seconds, int perPoint) {
      final total = TrafficAmount();
      final points = <({int down, int up})>[];
      final nowSec = at.millisecondsSinceEpoch ~/ 1000;
      final end = (nowSec ~/ perPoint) * perPoint;
      final firstKnown = _seconds.isEmpty ? end : _seconds.keys.reduce(math.min);
      var start = end - seconds;
      // from the first second there is anything for, so a fresh start doesn't draw a long flat line
      if (firstKnown > start) start = (firstKnown ~/ perPoint) * perPoint;
      for (var slot = start; slot < end; slot += perPoint) {
        var d = 0;
        var u = 0;
        for (var sec = slot; sec < slot + perPoint; sec++) {
          final amount = _seconds[sec];
          if (amount == null) continue;
          d = math.max(d, amount.down);
          u = math.max(u, amount.up);
          total.add(amount.down, amount.up, amount.vpn);
        }
        points.add((down: d, up: u));
      }
      return (points: points, slots: seconds ~/ perPoint, slot: Duration(seconds: perPoint), total: total);
    }

    // whole stretches of clock time again (a day's slots shifted every minute); each slot shows its fastest minute,
    // and the minute under way counts by the seconds it has had (it read as a dip at the right edge)
    RangeSeries fromMinutes(int minutes, int perPoint) {
      final total = TrafficAmount();
      final points = <({int down, int up})>[];
      final end = (minuteNow ~/ perPoint) * perPoint + perPoint;
      var start = end - minutes;
      // from the first minute there is anything for, so a fresh install doesn't draw a long flat line
      final firstKnown = _minutes.keys.where((m) => m >= start).fold<int?>(null, (a, m) => a == null || m < a ? m : a);
      if (firstKnown == null) {
        return (points: points, slots: minutes ~/ perPoint, slot: Duration(minutes: perPoint), total: total);
      }
      start = math.max(start, (firstKnown ~/ perPoint) * perPoint);
      final secondsNow = math.max(1, at.second);
      for (var m = start; m < end; m += perPoint) {
        var d = 0;
        var u = 0;
        for (var k = m; k < m + perPoint && k <= minuteNow; k++) {
          final a = _minutes[k];
          if (a == null) continue;
          final seconds = k == minuteNow ? secondsNow : 60;
          d = math.max(d, a.down ~/ seconds);
          u = math.max(u, a.up ~/ seconds);
          total.add(a.down, a.up, a.vpn);
        }
        points.add((down: d, up: u));
      }
      return (points: points, slots: minutes ~/ perPoint, slot: Duration(minutes: perPoint), total: total);
    }

    switch (range) {
      case StatsRange.minute:
        return fromSeconds(60, 1);
      case StatsRange.tenMinutes:
        return fromSeconds(600, 5);
      case StatsRange.hour:
        return fromMinutes(60, 1);
      case StatsRange.day:
        return fromMinutes(24 * 60, 15);
      case StatsRange.all:
        final total = TrafficAmount();
        for (final d in _days.values) {
          total.add(d.down, d.up, d.vpn);
        }
        final days = _days.keys.toList()..sort();
        if (days.length <= 2) {
          // two days or less: by the hour from the minutes kept
          final r = fromMinutes(48 * 60, 60);
          return (points: r.points, slots: r.points.length.clamp(2, 48), slot: r.slot, total: total);
        }
        // today by the seconds it has had so far, not a whole day's (it read as a dip at the end)
        final local = at;
        final today = DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ 86400000;
        final todaySeconds = math.max(1, local.hour * 3600 + local.minute * 60 + local.second);
        final points = [
          for (var d = days.first; d <= days.last; d++)
            (
              down: (_days[d]?.down ?? 0) ~/ (d == today ? todaySeconds : 86400),
              up: (_days[d]?.up ?? 0) ~/ (d == today ? todaySeconds : 86400),
            ),
        ];
        return (points: points, slots: points.length, slot: const Duration(days: 1), total: total);
    }
  }

  /// What moved from [start] on (to the minute).
  TrafficAmount amountFrom(DateTime start) {
    if (!_loaded) _load();
    final from = start.millisecondsSinceEpoch ~/ 60000;
    final total = TrafficAmount();
    for (final e in _minutes.entries) {
      if (e.key >= from) total.add(e.value.down, e.value.up, e.value.vpn);
    }
    return total;
  }

  /// When the history starts (for the "all time" axis).
  DateTime? get since {
    if (_days.isEmpty) return null;
    final first = _days.keys.reduce((a, b) => a < b ? a : b);
    final d = DateTime.fromMillisecondsSinceEpoch(first * 86400000, isUtc: true);
    return DateTime(d.year, d.month, d.day);
  }
}

/// The period the Statistics tab shows.
final statsRangeProvider = NotifierProvider<StatsRangeNotifier, StatsRange>(StatsRangeNotifier.new);

class StatsRangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.minute;

  StatsRange get range => state;
  set range(StatsRange value) => state = value;
}
