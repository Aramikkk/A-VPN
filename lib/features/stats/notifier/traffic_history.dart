import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The periods the Statistics tab can show.
enum StatsRange { minute, tenMinutes, hour, day, all }

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

  /// per second, newest last
  final _seconds = <TrafficAmount>[];

  /// by minute since the epoch
  final _minutes = <int, TrafficAmount>{};

  /// by local day (days since the epoch)
  final _days = <int, TrafficAmount>{};

  // the core's counters at the last reading, to take the difference from
  int? _session;
  int _lastTotal = -1;
  int _lastVpn = 0;
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
      'lastAt': _lastAt?.millisecondsSinceEpoch,
    });
    unawaited(file.writeAsString(json).then((_) {}, onError: (_) {}));
  }

  void _take(SystemInfo stats, DateTime now) {
    if (!_loaded) _load();
    final session = stats.sessionStartedAt?.millisecondsSinceEpoch;
    final up = stats.uplinkTotal.toInt();
    final down = stats.downlinkTotal.toInt();
    final total = up + down;
    final vpn = (stats.vpnUplinkTotal ?? 0) + (stats.vpnDownlinkTotal ?? 0);
    int dTotal;
    int dVpn;
    if (session == null || session != _session || _lastTotal < 0) {
      // a new VPN session (or the first reading): count from its start if it began after the last reading
      final fresh = session != null && (_lastAt == null || session >= _lastAt!.millisecondsSinceEpoch);
      dTotal = fresh ? total : 0;
      dVpn = fresh ? vpn : 0;
    } else if (total < _lastTotal) {
      // the core reloaded (a server or network change) and started its counters over
      dTotal = total;
      dVpn = vpn;
    } else {
      dTotal = total - _lastTotal;
      dVpn = (vpn - _lastVpn).clamp(0, dTotal);
    }
    // the split between down and up follows the session's
    final dDown = total == 0 ? 0 : (dTotal * down / total).round();
    final dUp = dTotal - dDown;
    final from = _lastAt;
    _session = session;
    _lastTotal = total;
    _lastVpn = vpn;
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
      _seconds.add(TrafficAmount(dDown, dUp, dVpn));
      if (_seconds.length > _secondsKept) _seconds.removeAt(0);
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
    RangeSeries fromSeconds(int seconds, int perPoint) {
      final recent = _seconds.length > seconds ? _seconds.sublist(_seconds.length - seconds) : List.of(_seconds);
      final total = TrafficAmount();
      final points = <({int down, int up})>[];
      for (var i = 0; i < recent.length; i += perPoint) {
        final chunk = recent.sublist(i, (i + perPoint).clamp(0, recent.length));
        var d = 0;
        var u = 0;
        for (final s in chunk) {
          d += s.down;
          u += s.up;
          total.add(s.down, s.up, s.vpn);
        }
        points.add((down: d ~/ chunk.length, up: u ~/ chunk.length));
      }
      return (points: points, slots: seconds ~/ perPoint, slot: Duration(seconds: perPoint), total: total);
    }

    RangeSeries fromMinutes(int minutes, int perPoint) {
      final total = TrafficAmount();
      final points = <({int down, int up})>[];
      final start = minuteNow - minutes + 1;
      // from the first minute there is anything for, so a fresh install doesn't draw a long flat line
      final firstKnown = _minutes.keys.where((m) => m >= start).fold<int?>(null, (a, m) => a == null || m < a ? m : a);
      if (firstKnown == null) {
        return (points: points, slots: minutes ~/ perPoint, slot: Duration(minutes: perPoint), total: total);
      }
      final firstSlot = start + ((firstKnown - start) ~/ perPoint) * perPoint;
      for (var m = firstSlot; m <= minuteNow; m += perPoint) {
        var d = 0;
        var u = 0;
        for (var k = m; k < m + perPoint && k <= minuteNow; k++) {
          final a = _minutes[k];
          if (a == null) continue;
          d += a.down;
          u += a.up;
          total.add(a.down, a.up, a.vpn);
        }
        points.add((down: d ~/ (perPoint * 60), up: u ~/ (perPoint * 60)));
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
        final points = [
          for (var d = days.first; d <= days.last; d++)
            (down: (_days[d]?.down ?? 0) ~/ 86400, up: (_days[d]?.up ?? 0) ~/ 86400),
        ];
        return (points: points, slots: points.length, slot: const Duration(days: 1), total: total);
    }
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
