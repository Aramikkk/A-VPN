import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/route_rules/notifier/rule_groups.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';
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

  /// The rules, in order: the routing list from Settings → Routing as it is (its groups send AI, Google, social
  /// networks and the blocked sites through the VPN, Russian sites and apps direct), then everything else
  /// direct. [extraProxyHosts]: hosts that must also go through the VPN (the ping test URL, so the ping shows
  /// the VPN's latency).
  static List<Map<String, dynamic>> rules({required List<Rule> list, List<String> extraProxyHosts = const []}) => [
    if (extraProxyHosts.isNotEmpty) {'domain_suffix': extraProxyHosts, 'action': 'route', 'outbound': _proxyTag},
    ...splitGroups(list.where((rule) => rule.enabled)).map(ruleJson).nonNulls,
    // the rest of the internet
    {
      'network': ['tcp', 'udp'],
      'action': 'route',
      'outbound': _directTag,
    },
  ];

  /// A rule of the list as a sing-box route rule; null when it has nothing this mode can match on. Its rule-sets
  /// are named by the core's tags (the file's name without .srs): the core sets up their download for the
  /// same list, so blocking ads works here too. One with a region in its address is left out.
  static Map<String, dynamic>? ruleJson(Rule rule) {
    if (rule.ruleSets.any((url) => url.contains('{region}'))) return null;
    final json = <String, dynamic>{};
    void put(String key, Iterable<Object> values) {
      if (values.isNotEmpty) json[key] = values.toList();
    }

    put('rule_set', rule.ruleSets.map(ruleSetTag));
    put('domain', rule.domains);
    put('domain_suffix', rule.domainSuffixes);
    put('domain_keyword', rule.domainKeywords);
    put('domain_regex', rule.domainRegexes);
    put('ip_cidr', rule.ipCidrs);
    put('source_ip_cidr', rule.sourceIpCidrs);
    put('package_name', rule.packageNames);
    // here every Google app, not only the listed ones
    if (BuiltinRule.of(rule) == BuiltinRule.googleProxy && rule.packageNames.isNotEmpty) {
      put('package_name_regex', googleAppPatterns);
    }
    put('process_name', rule.processNames);
    put('process_path', rule.processPaths);
    // single ports and ranges ("1000:2000") go in different fields, as the core does
    (Iterable<int>, Iterable<String>) ports(List<String> values) {
      final trimmed = values.map((v) => v.trim());
      return (trimmed.where((v) => !v.contains(':')).map(int.tryParse).nonNulls, trimmed.where((v) => v.contains(':')));
    }

    final (port, portRange) = ports(rule.portRanges);
    put('port', port);
    put('port_range', portRange);
    final (sourcePort, sourcePortRange) = ports(rule.sourcePortRanges);
    put('source_port', sourcePort);
    put('source_port_range', sourcePortRange);
    if (json.isEmpty && rule.network == Network.all && rule.protocols.isEmpty) return null;
    if (rule.network != Network.all) json['network'] = [if (rule.network == Network.tcp) 'tcp' else 'udp'];
    // by value: release builds drop the enums' names
    const protocols = {0: 'tls', 1: 'http', 2: 'quic', 3: 'stun', 4: 'dns', 5: 'bittorrent'};
    put('protocol', rule.protocols.map((p) => protocols[p.value]).nonNulls);
    return switch (rule.outbound) {
      Outbound.block => {...json, 'action': 'reject'},
      Outbound.proxy => {...json, 'action': 'route', 'outbound': _proxyTag},
      _ => {...json, 'action': 'route', 'outbound': _directTag},
    };
  }

  /// The core's tag for a rule-set at [url]: the file's name without its extension.
  static String ruleSetTag(String url) {
    final name = url.trim().split('?').first.split('#').first.split('/').last;
    return name.endsWith('.srs') || name.endsWith('.json') ? name.substring(0, name.lastIndexOf('.')) : name;
  }

  /// Writes the config at [path] with the rules added, next to [activeConfigPath], and returns its path;
  /// [path] itself when it can't.
  static Future<String> attach(
    String path, {
    required String activeConfigPath,
    required List<Rule> list,
    List<String> extraProxyHosts = const [],
  }) async {
    try {
      final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final route = (config['route'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final existing = (route['rules'] as List?)?.toList() ?? [];
      config['route'] = {
        ...route,
        'rules': [...existing, ...rules(list: list, extraProxyHosts: extraProxyHosts)],
      };
      final out = File('$activeConfigPath.blocked-only.json');
      await out.writeAsString(jsonEncode(config));
      _logger.info('only blocked sites through the VPN, everything else direct');
      return out.path;
    } catch (e, st) {
      _logger.warning('could not add the blocked-only rules, everything goes through the VPN', e, st);
      return path;
    }
  }
}
