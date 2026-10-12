import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ping through the VPN and packet loss: every 2 seconds, while the app is on screen and the VPN is up, a tiny
/// request (the connection test URL, which answers 204) goes through A-VPN's own proxy port, so it takes the same
/// path as the rest of the traffic; a probe that gets no answer in time counts as lost. The state is the last
/// minute's probes; every probe is also counted by the minute (two days) and by the day (for good) and saved, so
/// the Statistics tab can show ping and loss for any period and nothing starts over when the app reopens.
final connectionQualityProvider = NotifierProvider<ConnectionQuality, List<int?>>(ConnectionQuality.new);

/// Probes in some stretch of time: how many went out, how many got no answer, and the answers' total, fastest
/// and slowest time.
class PingBucket {
  PingBucket([this.sent = 0, this.lost = 0, this.sum = 0, this.min = 0, this.max = 0]);

  int sent;
  int lost;
  int sum;
  int min;
  int max;

  int get answered => sent - lost;
  int? get average => answered == 0 ? null : (sum / answered).round();

  void add(int? ms) {
    sent++;
    if (ms == null) {
      lost++;
      return;
    }
    min = answered == 1 ? ms : (ms < min ? ms : min);
    max = ms > max ? ms : max;
    sum += ms;
  }

  void merge(PingBucket b) {
    if (b.answered > 0) {
      min = answered == 0 ? b.min : (b.min < min ? b.min : min);
      max = b.max > max ? b.max : max;
    }
    sent += b.sent;
    lost += b.lost;
    sum += b.sum;
  }

  List<int> toJson() => [sent, lost, sum, min, max];

  factory PingBucket.fromJson(Object? json) {
    final l = json is List ? json.whereType<num>().map((n) => n.toInt()).toList() : const <int>[];
    int at(int i) => l.length > i ? l[i] : 0;
    return PingBucket(at(0), at(1), at(2), at(3), at(4));
  }
}

/// A period's ping: a bar per slot (its average, null when nothing answered), how many slots the width holds,
/// and the totals.
typedef PingPeriod = ({List<int?> bars, int slots, PingBucket total});

class ConnectionQuality extends Notifier<List<int?>> {
  /// one minute of samples
  static const length = 30;
  static const interval = Duration(seconds: 2);
  static const timeout = Duration(seconds: 2);
  static const _minutesKept = 2 * 24 * 60;

  HttpClient? _client;
  final _samples = <int?>[];
  final _minutes = <int, PingBucket>{};
  final _days = <int, PingBucket>{};
  bool _loaded = false;
  bool _foreground = true;
  AppLifecycleListener? _lifecycle;
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);

  File? get _file {
    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    return dirs == null ? null : File('${dirs.baseDir.path}/ping_history.json');
  }

  @override
  List<int?> build() {
    if (!_loaded) _load();
    _lifecycle ??= AppLifecycleListener(
      onResume: () => _foreground = true,
      onHide: () => _foreground = false,
      onPause: () => _foreground = false,
    );
    final connected = ref.watch(connectionNotifierProvider).valueOrNull is Connected;
    final port = ref.watch(ConfigOptions.mixedPort);
    final url = Uri.parse(ref.watch(ConfigOptions.connectionTestUrl));
    // the probes go through A-VPN's own proxy port: without it every probe would look lost
    if (!connected || !ref.watch(ConfigOptions.enableMixedPort)) return List.of(_samples);

    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
    _client = client;
    final timer = Timer.periodic(interval, (_) {
      if (_foreground) _probe(client, url);
    });
    ref.onDispose(() {
      timer.cancel();
      client.close(force: true);
      _client = null;
    });
    if (_foreground) unawaited(_probe(client, url));
    return List.of(_samples);
  }

  void _load() {
    _loaded = true;
    try {
      final file = _file;
      if (file == null || !file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _samples.addAll((json['samples'] as List? ?? const []).map((e) => e is num ? e.toInt() : null));
      (json['minutes'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => _minutes[int.parse(k)] = PingBucket.fromJson(v),
      );
      (json['days'] as Map<String, dynamic>? ?? {}).forEach((k, v) => _days[int.parse(k)] = PingBucket.fromJson(v));
    } catch (_) {
      // an unreadable history starts over
    }
  }

  void _save() {
    final file = _file;
    if (file == null) return;
    _saved = DateTime.now();
    final json = jsonEncode({
      'samples': _samples,
      'minutes': {for (final e in _minutes.entries) '${e.key}': e.value.toJson()},
      'days': {for (final e in _days.entries) '${e.key}': e.value.toJson()},
    });
    unawaited(file.writeAsString(json).then((_) {}, onError: (_) {}));
  }

  Future<void> _probe(HttpClient client, Uri url) async {
    int? ms;
    final watch = Stopwatch()..start();
    try {
      final request = await client.headUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      ms = watch.elapsedMilliseconds;
    } catch (_) {
      ms = null; // lost
    }
    if (!identical(client, _client)) return; // disposed meanwhile
    final now = DateTime.now();
    _samples.add(ms);
    if (_samples.length > length) _samples.removeAt(0);
    final minute = now.millisecondsSinceEpoch ~/ 60000;
    _minutes.putIfAbsent(minute, PingBucket.new).add(ms);
    final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;
    _days.putIfAbsent(day, PingBucket.new).add(ms);
    _minutes.removeWhere((m, _) => m < minute - _minutesKept);
    if (now.difference(_saved) > const Duration(minutes: 1)) _save();
    state = List.of(_samples);
  }

  /// The ping and loss for [range]: the minute's probes one by one, longer periods averaged into slots.
  PingPeriod period(StatsRange range) {
    final minuteNow = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    if (range == StatsRange.minute) {
      final total = PingBucket();
      for (final s in _samples) {
        total.add(s);
      }
      return (bars: List.of(_samples), slots: length, total: total);
    }
    PingPeriod fromMinutes(int minutes, int perSlot) {
      final total = PingBucket();
      final bars = <int?>[];
      for (var m = minuteNow - minutes + 1; m <= minuteNow; m += perSlot) {
        final slot = PingBucket();
        for (var k = m; k < m + perSlot && k <= minuteNow; k++) {
          final b = _minutes[k];
          if (b != null) slot.merge(b);
        }
        total.merge(slot);
        // slots before the first probe aren't drawn
        if (slot.sent == 0 && bars.isEmpty) continue;
        bars.add(slot.sent == 0 ? 0 : slot.average);
      }
      return (bars: bars, slots: minutes ~/ perSlot, total: total);
    }

    switch (range) {
      case StatsRange.minute:
      case StatsRange.tenMinutes:
        return fromMinutes(10, 1);
      case StatsRange.hour:
        return fromMinutes(60, 2);
      case StatsRange.day:
        return fromMinutes(24 * 60, 30);
      case StatsRange.all:
        final total = PingBucket();
        for (final b in _days.values) {
          total.merge(b);
        }
        final days = _days.keys.toList()..sort();
        if (days.length <= 2) {
          final r = fromMinutes(48 * 60, 60);
          return (bars: r.bars, slots: r.bars.length.clamp(2, 48), total: total);
        }
        final bars = [for (var d = days.first; d <= days.last; d++) _days[d]?.average];
        return (bars: bars, slots: bars.length, total: total);
    }
  }
}

/// The latest ping and the loss over the samples, in percent; null without samples.
({int? ping, double? loss}) summarize(List<int?> samples) {
  if (samples.isEmpty) return (ping: null, loss: null);
  final lost = samples.where((s) => s == null).length;
  return (ping: samples.lastWhere((s) => s != null, orElse: () => null), loss: lost * 100 / samples.length);
}

/// The answered probes' average, fastest and slowest ping, and the jitter: the average change from one answer to
/// the next. Null when nothing answered.
({int avg, int min, int max, int jitter})? pingSpread(List<int?> samples) {
  final answered = samples.whereType<int>().toList();
  if (answered.isEmpty) return null;
  var change = 0;
  for (var i = 1; i < answered.length; i++) {
    change += (answered[i] - answered[i - 1]).abs();
  }
  return (
    avg: (answered.reduce((a, b) => a + b) / answered.length).round(),
    min: answered.reduce((a, b) => a < b ? a : b),
    max: answered.reduce((a, b) => a > b ? a : b),
    jitter: answered.length < 2 ? 0 : (change / (answered.length - 1)).round(),
  );
}
