import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/proxy/data/hidden_servers.dart';

/// The servers in a profile's config, reached straight (a TCP connection to each one's address, the VPN still
/// off): which answer from this network and how fast. Placeholders, groups and hidden servers are left out.
class PrePing {
  PrePing._();

  /// Each server's (tag, host, port) from the config at [path].
  static Future<List<(String, String, int)>> servers(String path) async {
    try {
      final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      return [
        for (final key in ['outbounds', 'endpoints'])
          for (final item in (config[key] as List?) ?? const [])
            if (item is Map<String, dynamic> &&
                item['tag'] is String &&
                item['server'] is String &&
                item['server_port'] is int &&
                item['server'] != '0.0.0.0' &&
                (item['server_port'] as int) > 1 &&
                !isHiddenServer(item['tag'] as String))
              (item['tag'] as String, item['server'] as String, item['server_port'] as int),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Connects to every server at once; [onResult] gets each one's time in ms (null: no answer in [timeout]).
  static Future<void> run(
    List<(String, String, int)> servers,
    void Function(String tag, int? ms) onResult, {
    Duration timeout = const Duration(milliseconds: 2500),
  }) => Future.wait([
    for (final (tag, host, port) in servers)
      () async {
        final watch = Stopwatch()..start();
        try {
          final socket = await Socket.connect(host, port, timeout: timeout);
          final ms = watch.elapsedMilliseconds;
          socket.destroy();
          onResult(tag, ms);
        } catch (_) {
          onResult(tag, null);
        }
      }(),
  ]);
}
