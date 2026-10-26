import 'dart:convert';
import 'dart:io';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';

/// Persist each network's monitoring timeout with its prepared configuration.
Future<String> withNetworkPingTimeout(
  String path,
  NetworkKind network,
  Duration timeout, {
  int balancerTolerance = 150,
  bool siteGroups = false,
  int siteGroupsTolerance = 80,
}) async {
  final seconds = timeout.inSeconds.clamp(1, 120);
  final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  final experimental = Map<String, dynamic>.from(config['experimental'] as Map? ?? {});
  final monitoring = Map<String, dynamic>.from(experimental['monitoring'] as Map? ?? {});
  monitoring['url_test_timeout'] = '${seconds}s';
  // this network's own Auto per site (Settings → Ping → Sites): the core builds the groups from it
  monitoring['site_groups'] = siteGroups;
  monitoring['site_groups_tolerance'] = siteGroupsTolerance.clamp(10, 3000);
  experimental['monitoring'] = monitoring;
  config['experimental'] = experimental;
  for (final outbound in (config['outbounds'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
    if (outbound['tag'] != 'lowest') continue;
    final options = Map<String, dynamic>.from(outbound['options'] as Map? ?? {});
    options['tolerance'] = balancerTolerance;
    // Wi-Fi has dozens of servers: the background checks go eight at a time, twenty seconds apart, so a start (or a
    // resume after a pause) doesn't test them all at once. Mobile data has only a few: all of them at once.
    if (network == NetworkKind.wifi) {
      options['start_batch'] = 8;
      options['start_gap'] = '20s';
    } else {
      options.remove('start_batch');
      options.remove('start_gap');
    }
    outbound['options'] = options;
  }
  final output = File('$path.ping-${network.name}.json');
  await output.writeAsString(jsonEncode(config));
  return output.path;
}
