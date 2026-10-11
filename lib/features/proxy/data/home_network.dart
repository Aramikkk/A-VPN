import 'dart:convert';
import 'dart:io';

import 'package:hiddify/utils/custom_loggers.dart';
import 'package:path/path.dart' as p;

/// A-VPN's "Server" mode: the user's own WireGuard server instead of the provider.
///
/// Every other profile that holds nothing but WireGuard (an imported `.conf`) is added to the start config
/// as a hidden endpoint, with a route rule sending that profile's allowed IPs to it, and a last rule sending
/// every other connection direct, so the provider's servers carry nothing. The patched core keeps route rules
/// from the start config and checks them before its own.
abstract class HomeNetwork {
  static final _logger = infraLogger('HomeNetwork');

  /// The core's direct outbound.
  static const _directTag = 'direct §hide§';

  /// Writes the config at [path] with the home networks added and returns its path, or [path] itself when
  /// there is no WireGuard profile to add. [activeConfigPath] is the active profile's own config, never added.
  ///
  /// The WireGuard always connects directly. Sending it through a provider server on mobile data was tried:
  /// the "LTE Only" servers don't carry its UDP, so the handshake never completed, and the half-open tunnel
  /// stalled the reload when the network changed.
  static Future<String> attach(String path, {required String activeConfigPath}) async {
    try {
      final homes = await _findWireGuardProfiles(File(activeConfigPath).parent, activeConfigPath);
      if (homes.isEmpty) return path;

      final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final endpoints = (config['endpoints'] as List?)?.toList() ?? [];
      final route = (config['route'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final rules = (route['rules'] as List?)?.toList() ?? [];

      for (final home in homes) {
        endpoints.add(home.endpoint);
        rules.add({'ip_cidr': home.cidrs, 'action': 'route', 'outbound': home.endpoint['tag']});
      }
      // the rest of the internet and the local network go direct: in Server mode the provider is off
      rules.add({
        'network': ['tcp', 'udp'],
        'action': 'route',
        'outbound': _directTag,
      });
      config['endpoints'] = endpoints;
      config['route'] = {...route, 'rules': rules};

      final out = File('$activeConfigPath.home.json');
      await out.writeAsString(jsonEncode(config));
      _logger.info('home networks added: ${homes.map((h) => h.endpoint['tag']).join(', ')}');
      return out.path;
    } catch (e, st) {
      _logger.warning('could not add the home network, starting without it', e, st);
      return path;
    }
  }

  /// Whether there is a WireGuard profile, besides the active one, that [attach] would add.
  static Future<bool> available(String activeConfigPath) async {
    try {
      return (await _findWireGuardProfiles(File(activeConfigPath).parent, activeConfigPath)).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<List<({Map<String, dynamic> endpoint, List<String> cidrs})>> _findWireGuardProfiles(
    Directory dir,
    String activeConfigPath,
  ) async {
    final found = <({Map<String, dynamic> endpoint, List<String> cidrs})>[];
    if (!await dir.exists()) return found;
    final active = p.normalize(activeConfigPath);
    await for (final entity in dir.list()) {
      if (entity is! File || p.normalize(entity.path) == active) continue;
      final name = p.basename(entity.path);
      // only a profile's own config: not the copies the app writes next to it, nor temp files
      if (!RegExp(r'^[^.]+\.json$').hasMatch(name)) continue;
      try {
        final config = jsonDecode(await entity.readAsString());
        if (config is! Map<String, dynamic>) continue;
        // the core's parser turns WireGuard into endpoints; a profile with any other server isn't a home one
        if (((config['outbounds'] as List?) ?? const []).isNotEmpty) continue;
        final items = ((config['endpoints'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
        if (items.isEmpty || items.any((item) => item['type'] != 'wireguard')) continue;
        for (final item in items) {
          final home = _homeEndpoint(item);
          if (home != null) found.add(home);
        }
      } catch (_) {
        // not a config this can read: skip it
      }
    }
    return found;
  }

  /// The endpoint renamed so the core keeps it out of its groups, and the networks it reaches. A peer that
  /// takes all traffic (0.0.0.0/0) isn't a home network: adding it would send the whole internet home.
  static ({Map<String, dynamic> endpoint, List<String> cidrs})? _homeEndpoint(Map<String, dynamic> wireguard) {
    final cidrs = <String>{
      for (final peer
          in (wireguard['peers'] as List?)?.whereType<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[])
        for (final cidr in (peer['allowed_ips'] as List?)?.whereType<String>() ?? const <String>[]) cidr,
    }.toList();
    if (cidrs.isEmpty || cidrs.any((c) => c.endsWith('/0'))) return null;
    final name = '${wireguard['tag'] ?? 'WireGuard'}'.replaceAll(RegExp(r'\s*§.*$'), '').trim();
    final endpoint = Map<String, dynamic>.of(wireguard)
      ..['tag'] = '🏠 $name §hide§'
      // the importer adds fake packets before the handshake; a plain WireGuard server doesn't expect them,
      // and the official WireGuard app the user's server works with sends none
      ..remove('noise');
    return (endpoint: endpoint, cidrs: cidrs);
  }
}
