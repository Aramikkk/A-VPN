import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _logger = infraLogger('ConnectionQuality');

/// Ping through the VPN and packet loss: every three seconds, while the app is on screen and the VPN is up, a tiny
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

/// A period's ping: a bar per slot (its average, null when nothing answered), the share of each slot's probes
/// lost (0 to 1), how many slots the width holds, and the totals.
typedef PingPeriod = ({List<int?> bars, List<double> losses, int slots, PingBucket total});

/// A stretch of loss: when it began, how many minutes it went on, and the probes sent and lost in it.
typedef LossEpisode = ({DateTime start, int minutes, int sent, int lost});

/// The last day's loss, from [ConnectionQuality.lossDay].
typedef LossDay = ({PingBucket total, List<double?> minutes, List<LossEpisode> episodes});

class ConnectionQuality extends Notifier<List<int?>> {
  /// three minutes of samples (one every three seconds)
  static const length = 60;
  static const interval = Duration(seconds: 3);

  /// how far apart the probes are now (ten seconds in the super light mode)
  Duration _every = interval;
  static const timeout = Duration(seconds: 2);
  static const _minutesKept = 2 * 24 * 60;

  HttpClient? _client;
  Uri? _url;

  /// One probe now (the home screen's refresh), not at the next turn of the timer.
  void probeNow() {
    final client = _client;
    final url = _url;
    if (client != null && url != null) unawaited(_probe(client, url));
  }

  final _samples = <int?>[];
  final _minutes = <int, PingBucket>{};
  final _days = <int, PingBucket>{};
  bool _loaded = false;

  /// probes since the VPN last came up: the home button shows this connection only
  int sinceConnect = 0;

  /// this connection was started while the app ran (not found up when it opened): its first answer is the tunnel
  /// warming up and isn't recorded
  bool warmUp = false;
  bool _sawConnecting = false;

  /// an answer has come on this connection: the probes lost before it (the tunnel coming up) aren't recorded, nor
  /// the first answer itself after a fresh start
  bool _answered = false;
  DateTime? _startedProbing;
  static const startupGrace = Duration(seconds: 15);

  /// the last moment the VPN was seen up: a status that blinks off for a moment (the core's link restarting when
  /// the app comes back) isn't a new connection
  DateTime? _lastUp;

  /// the core's session the probes so far belong to
  DateTime? _session;
  bool _foreground = true;

  /// the home screen asks for the probes itself (at the same moment as the sites' delays): the own timer waits
  bool driven = false;

  /// the phone probes while the app is on screen; a computer all the time (in the tray too), for its watchdog
  bool get _probing => _foreground || PlatformUtils.isDesktop;

  /// the last time the watchdog reconnected
  DateTime? _rescued;
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);

  File? get _file {
    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    return dirs == null ? null : File('${dirs.baseDir.path}/ping_history.json');
  }

  @override
  List<int?> build() {
    if (!_loaded) _load();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final status = ref.watch(connectionNotifierProvider).valueOrNull;
    final connected = status is Connected;
    if (status is Connecting) _sawConnecting = true;
    if (connected) {
      // a new connection: one that went through "connecting", or the VPN down for more than a few seconds; the
      // core's link restarting on resume rebuilds this without either, and the gauge kept starting over
      final now = DateTime.now();
      // The core's session start decides when it is known: an auto-pause or a home Wi-Fi pause keeps the session
      // (the core resumes it), so the ping and the losses go on; only the on/off button starts a new one.
      final session = ref.watch(sessionStartProvider);
      final looksNew = _sawConnecting || _lastUp == null || now.difference(_lastUp!) > const Duration(seconds: 10);
      // the session not known yet (the core says it a moment after it comes up): by the status, as before
      final fresh = session != null && _session != null ? session != _session : looksNew;
      if (session != null) _session = session;
      if (fresh) {
        _startedProbing = now;
        warmUp = _sawConnecting;
        // a connection found up when the app opened (not started meanwhile): the tunnel is long warm, and the
        // last probes kept from before show at once (the fresh ones take over within the minute)
        final foundUp = !warmUp;
        sinceConnect = foundUp ? _samples.length : 0;
        _answered = foundUp;
      }
      _sawConnecting = false;
      _lastUp = now;
    }
    _every = ref.watch(superLightProvider) ? const Duration(seconds: 10) : interval;
    final port = ref.watch(ConfigOptions.mixedPort);
    final url = Uri.parse(pingUrl(ref.watch(ConfigOptions.connectionTestUrl), ref.watch(ConfigOptions.pingHttps)));
    _url = url;
    // the probes go through A-VPN's own proxy port: without it every probe would look lost
    if (!connected || !ref.watch(ConfigOptions.enableMixedPort)) return List.of(_samples);

    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
    _client = client;
    Timer? timer;
    void schedule() {
      timer?.cancel();
      // the app in front: at its own pace; a computer's watchdog while the window is hidden: a probe in 15 seconds is
      // enough (the phone does not probe at all out of sight)
      final every = _foreground ? _every : const Duration(seconds: 15);
      if (_probing) {
        timer = Timer.periodic(every, (_) {
          if (!driven) unawaited(_probe(client, url));
        });
      }
    }

    void background() {
      _foreground = false;
      schedule();
    }

    final lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        unawaited(_probe(client, url));
        schedule();
      },
      onHide: background,
      onPause: background,
    );
    schedule();
    ref.onDispose(() {
      lifecycle.dispose();
      timer?.cancel();
      client.close(force: true);
      _client = null;
    });
    if (_probing) unawaited(_probe(client, url));
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
    // the tunnel coming up: nothing recorded before the first answer, and that answer only when the connection was
    // found up (a fresh one's first answer is the warm-up, well over a second)
    if (!_answered) {
      if (ms == null && !startupGraceExpired(_startedProbing, now)) return;
      if (ms != null) {
        _answered = true;
        if (warmUp) {
          warmUp = false;
          return;
        }
      }
    }
    _samples.add(ms);
    sinceConnect++;
    _lastUp = now;
    if (_samples.length > length) _samples.removeAt(0);
    final minute = now.millisecondsSinceEpoch ~/ 60000;
    _minutes.putIfAbsent(minute, PingBucket.new).add(ms);
    final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;
    _days.putIfAbsent(day, PingBucket.new).add(ms);
    _minutes.removeWhere((m, _) => m < minute - _minutesKept);
    if (now.difference(_saved) > const Duration(minutes: 1)) _save();
    state = List.of(_samples);
    if (PlatformUtils.isDesktop && ms == null) unawaited(_watchdog());
    if (isDegraded(_samples)) unawaited(_retestServers());
  }

  /// The last probes say the connection got bad now (lost, or several times slower than it was): three losses in
  /// the last six, or all six answered at three times the earlier median and over 300 ms.
  @visibleForTesting
  static bool isDegraded(List<int?> samples) {
    const recent = 6;
    if (samples.length < recent) return false;
    final last = samples.sublist(samples.length - recent);
    if (last.where((s) => s == null).length >= 3) return true;
    final before = samples.sublist(0, samples.length - recent).whereType<int>().toList()..sort();
    if (before.length < 10 || last.any((s) => s == null)) return false;
    final median = before[before.length ~/ 2];
    final now = last.whereType<int>().reduce((a, b) => a + b) / recent;
    return now >= 300 && now >= median * 3;
  }

  DateTime? _retested;

  /// A bad stretch makes the servers be pinged at once, so the auto choice sees it now rather than at its next
  /// round (the core's own pings come every few minutes); once in two minutes at most.
  Future<void> _retestServers() async {
    final now = DateTime.now();
    if (_retested != null && now.difference(_retested!) < const Duration(minutes: 2)) return;
    _retested = now;
    _logger.info('the last probes got bad: pinging the servers now so the auto choice can move');
    await ref.read(proxyRepositoryProvider).urlTest('select').run();
  }

  /// A computer's VPN that stopped carrying anything (after sleep, a Wi-Fi change, a server gone quiet) is
  /// reconnected: half a minute of probes lost in a row while the internet itself answers, once in two minutes
  /// at most.
  Future<void> _watchdog() async {
    const inARow = 10;
    if (_samples.length < inARow || _samples.sublist(_samples.length - inARow).any((s) => s != null)) return;
    final now = DateTime.now();
    if (_rescued != null && now.difference(_rescued!) < const Duration(minutes: 2)) return;
    _rescued = now;
    // no internet at all (the Wi-Fi gone): nothing a reconnect would mend
    if (!await _internetAnswers()) {
      _rescued = null;
      return;
    }
    _logger.warning('the VPN carries nothing for half a minute while the internet answers: reconnecting');
    final profile = await ref.read(activeProfileProvider.future);
    await ref.read(connectionNotifierProvider.notifier).reconnect(profile);
  }

  /// Whether a Russian site answers straight, past the VPN's proxy (it goes direct by the rules anyway).
  Future<bool> _internetAnswers() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.headUrl(Uri.parse('https://ya.ru')).timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(const Duration(seconds: 4));
      await response.drain<void>();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// The loss since [since] (the session's start; the last day when null): the total, the share lost in each
  /// minute (null: no probes then; the oldest first) and the stretches of loss, the latest first (minutes with loss
  /// next to each other make one).
  LossDay lossDay({DateTime? since}) {
    final minuteNow = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final span = since == null
        ? 24 * 60
        : (minuteNow - since.millisecondsSinceEpoch ~/ 60000 + 1).clamp(1, _minutesKept);
    final total = PingBucket();
    final minutes = <double?>[];
    final episodes = <LossEpisode>[];
    PingBucket? open;
    int? openStart;
    var openLength = 0;
    void close() {
      if (open != null) {
        episodes.add((
          start: DateTime.fromMillisecondsSinceEpoch(openStart! * 60000),
          minutes: openLength,
          sent: open!.sent,
          lost: open!.lost,
        ));
      }
      open = null;
    }

    for (var m = minuteNow - span + 1; m <= minuteNow; m++) {
      final b = _minutes[m];
      if (b != null) total.merge(b);
      minutes.add(b == null || b.sent == 0 ? null : b.lost / b.sent);
      if (b != null && b.lost > 0) {
        if (open == null) {
          open = PingBucket();
          openStart = m;
          openLength = 0;
        }
        open!.merge(b);
        openLength++;
      } else {
        close();
      }
    }
    close();
    return (total: total, minutes: minutes, episodes: episodes.reversed.toList());
  }

  /// The ping and loss for [range]: the minute's probes one by one, longer periods averaged into slots.
  PingPeriod period(StatsRange range) {
    final minuteNow = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    if (range == StatsRange.minute) {
      final total = PingBucket();
      for (final s in _samples) {
        total.add(s);
      }
      return (
        bars: List.of(_samples),
        losses: [for (final s in _samples) s == null ? 1.0 : 0.0],
        slots: length,
        total: total,
      );
    }
    PingPeriod fromMinutes(int minutes, int perSlot) {
      final total = PingBucket();
      final bars = <int?>[];
      final losses = <double>[];
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
        losses.add(slot.sent == 0 ? 0 : slot.lost / slot.sent);
      }
      return (bars: bars, losses: losses, slots: minutes ~/ perSlot, total: total);
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
          return (bars: r.bars, losses: r.losses, slots: r.bars.length.clamp(2, 48), total: total);
        }
        final bars = [for (var d = days.first; d <= days.last; d++) _days[d]?.average];
        final losses = [
          for (var d = days.first; d <= days.last; d++)
            (_days[d]?.sent ?? 0) == 0 ? 0.0 : _days[d]!.lost / _days[d]!.sent,
        ];
        return (bars: bars, losses: losses, slots: bars.length, total: total);
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

/// After a bounded startup grace, failures count even if the tunnel never answered.
bool startupGraceExpired(DateTime? started, DateTime now) =>
    started != null && now.difference(started) >= ConnectionQuality.startupGrace;
