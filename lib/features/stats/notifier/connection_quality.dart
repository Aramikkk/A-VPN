import 'dart:async';
import 'dart:io';

import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ping through the VPN and packet loss, measured while the Statistics tab is open: every 2 seconds a tiny
/// request (the connection test URL, which answers 204) goes through A-VPN's own proxy port, so it takes the
/// same path as the rest of the traffic. A probe that gets no answer in time counts as lost.
final connectionQualityProvider = NotifierProvider.autoDispose<ConnectionQuality, List<int?>>(ConnectionQuality.new);

class ConnectionQuality extends AutoDisposeNotifier<List<int?>> {
  /// one minute of samples
  static const length = 30;
  static const interval = Duration(seconds: 2);
  static const timeout = Duration(seconds: 2);

  HttpClient? _client;

  @override
  List<int?> build() {
    final connected = ref.watch(connectionNotifierProvider).valueOrNull is Connected;
    final port = ref.watch(ConfigOptions.mixedPort);
    final url = Uri.parse(ref.watch(ConfigOptions.connectionTestUrl));
    // the probes go through A-VPN's own proxy port: without it every probe would look lost
    if (!connected || !ref.watch(ConfigOptions.enableMixedPort)) return const [];

    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
    _client = client;
    final timer = Timer.periodic(interval, (_) => _probe(client, url));
    ref.onDispose(() {
      timer.cancel();
      client.close(force: true);
      _client = null;
    });
    unawaited(_probe(client, url));
    return const [];
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
    state = [...state.skip(state.length >= length ? state.length - length + 1 : 0), ms];
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
