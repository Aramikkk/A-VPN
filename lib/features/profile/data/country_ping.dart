import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/proxy/data/server_region_filter.dart';

/// How far each country of a profile is: the time a TCP connection to its servers takes, the fastest server counts.
/// Asked straight from the app, so it works with the VPN off, and for the countries switched off (the core pings only
/// the servers it uses).
abstract class CountryPing {
  /// A server of a profile: its country, address and port.
  static List<({String code, String host, int port})> serversOf(Map<String, dynamic> config) {
    final servers = <({String code, String host, int port})>[];
    for (final key in ['outbounds', 'endpoints']) {
      for (final item in ((config[key] as List?) ?? const []).whereType<Map<String, dynamic>>()) {
        final tag = item['tag'];
        final host = item['server'];
        final port = item['server_port'];
        if (tag is! String || tag.contains('§hide§') || host is! String || port is! int) continue;
        if (host == '0.0.0.0' || host == 'siski.com' || port < 2) continue;
        final code = ServerRegionFilter.serverKey(tag);
        if (code != null) servers.add((code: code, host: host, port: port));
      }
    }
    return servers;
  }

  static Future<List<({String code, String host, int port})>> serversOfFile(String path) async {
    try {
      return serversOf(jsonDecode(await File(path).readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const [];
    }
  }

  /// The countries' ping, each as soon as it is known: (country code, ms, or null when no server answered). A few
  /// servers of a country are asked (the first ones), all the servers at once.
  static Stream<(String, int?)> measure(
    List<({String code, String host, int port})> servers, {
    Duration timeout = const Duration(seconds: 3),
    int perCountry = 4,
  }) {
    final byCountry = <String, List<({String code, String host, int port})>>{};
    for (final server in servers) {
      final list = byCountry.putIfAbsent(server.code, () => []);
      if (list.length < perCountry) list.add(server);
    }
    final controller = StreamController<(String, int?)>();
    var open = byCountry.length;
    if (open == 0) {
      unawaited(controller.close());
      return controller.stream;
    }
    for (final entry in byCountry.entries) {
      unawaited(
        Future.wait([for (final server in entry.value) connector(server.host, server.port, timeout)]).then((times) {
          final answered = times.whereType<int>();
          if (!controller.isClosed) controller.add((entry.key, answered.isEmpty ? null : answered.reduce(_min)));
          if (--open == 0) unawaited(controller.close());
        }),
      );
    }
    return controller.stream;
  }

  /// How a connection is timed: the real one, or a stand-in in the tests.
  static Future<int?> Function(String host, int port, Duration timeout) connector = _connect;

  static int _min(int a, int b) => a < b ? a : b;

  /// The time a TCP connection to [host] takes, in ms; null when it didn't open in time.
  static Future<int?> _connect(String host, int port, Duration timeout) async {
    final watch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      watch.stop();
      socket.destroy();
      return watch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}
