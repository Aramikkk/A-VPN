import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/route_rules/notifier/blocked_list.dart';
import 'package:hiddify/features/route_rules/notifier/rkn_ru_domains.dart';
import 'package:hiddify/utils/custom_loggers.dart';

/// A-VPN's "only blocked through the VPN" mode: sites and services blocked in Russia go through the VPN,
/// everything else (Yandex Disk downloads, games, updates) goes direct.
///
/// Adds route rules to the start config; the patched core keeps them right after sniffing and DNS, ahead of
/// its own rules, so they decide every connection.
abstract class BlockedOnlyRouting {
  static final _logger = infraLogger('BlockedOnlyRouting');

  static const _directTag = 'direct §hide§';
  static const _proxyTag = 'select';

  /// The rules, in order. [extraProxyHosts]: hosts that must also go through the VPN (the ping test URL, so
  /// the ping shows the VPN's latency).
  static List<Map<String, dynamic>> rules({List<String> extraProxyHosts = const []}) {
    final domains = {...blockedDomains, ...rknRuDomains, ...extraProxyHosts}.toList()..sort();
    return [
      // the local network and the router
      {'ip_is_private': true, 'action': 'route', 'outbound': _directTag},
      // blocked sites over QUIC fall back to TCP, which the VPN carries better
      {'domain_suffix': domains, 'protocol': 'quic', 'action': 'reject'},
      {'domain_suffix': domains, 'action': 'route', 'outbound': _proxyTag},
      {'ip_cidr': blockedCidrs, 'action': 'route', 'outbound': _proxyTag},
      // the rest of the internet
      {
        'network': ['tcp', 'udp'],
        'action': 'route',
        'outbound': _directTag,
      },
    ];
  }

  /// Writes the config at [path] with the rules added, next to [activeConfigPath], and returns its path;
  /// [path] itself when it can't.
  static Future<String> attach(
    String path, {
    required String activeConfigPath,
    List<String> extraProxyHosts = const [],
  }) async {
    try {
      final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final route = (config['route'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final existing = (route['rules'] as List?)?.toList() ?? [];
      config['route'] = {
        ...route,
        'rules': [...existing, ...rules(extraProxyHosts: extraProxyHosts)],
      };
      final out = File('$activeConfigPath.blocked-only.json');
      await out.writeAsString(jsonEncode(config));
      _logger.info('only blocked sites through the VPN: ${blockedDomains.length} domains');
      return out.path;
    } catch (e, st) {
      _logger.warning('could not add the blocked-only rules, everything goes through the VPN', e, st);
      return path;
    }
  }
}
