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
  int priorityProfile = 0,
  int priorityMargin = 0,
}) async {
  final seconds = timeout.inSeconds.clamp(1, 120);
  final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  final experimental = Map<String, dynamic>.from(config['experimental'] as Map? ?? {});
  final monitoring = Map<String, dynamic>.from(experimental['monitoring'] as Map? ?? {});
  monitoring['url_test_timeout'] = '${seconds}s';
  // this network's own Auto per site (Settings → Ping → Sites): the core builds the groups from it
  monitoring['site_groups'] = siteGroups;
  monitoring['site_groups_tolerance'] = siteGroupsTolerance.clamp(10, 3000);
  _setPriority(monitoring, priorityProfile, priorityMargin);
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

/// The priority subscription (1 = the active profile, 2 = the first added...; 0 = none) and its margin in ms, for the
/// core's automatic choice (it reads them from the monitoring block).
void _setPriority(Map<String, dynamic> monitoring, int profile, int margin) {
  if (profile > 0 && margin > 0) {
    monitoring['priority_profile'] = profile;
    monitoring['priority_margin'] = margin.clamp(1, 2000);
  } else {
    monitoring.remove('priority_profile');
    monitoring.remove('priority_margin');
  }
}

/// [path] with only the priority subscription set (the computer's config has no other network-specific parts).
Future<String> withPriority(String path, NetworkKind network, int profile, int margin) async {
  if (profile <= 0 || margin <= 0) return path;
  final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  final experimental = Map<String, dynamic>.from(config['experimental'] as Map? ?? {});
  final monitoring = Map<String, dynamic>.from(experimental['monitoring'] as Map? ?? {});
  _setPriority(monitoring, profile, margin);
  experimental['monitoring'] = monitoring;
  config['experimental'] = experimental;
  final output = File('$path.priority-${network.name}.json');
  await output.writeAsString(jsonEncode(config));
  return output.path;
}
