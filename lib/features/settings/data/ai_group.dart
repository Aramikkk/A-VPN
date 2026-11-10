import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

/// How many servers the AI group has: the main one and two backups.
const aiGroupMaxServers = 3;

/// The servers the core's AI group gets for [network]: the user's list for that network in order (the main one, then the
/// backups), without blanks and repeats, at most [aiGroupMaxServers]. On mobile data only the whitelist servers
/// (the others don't work there). Empty when the group is off.
List<String> aiServersFor({
  required bool enabled,
  required NetworkKind network,
  required List<String> wifi,
  required List<String> mobile,
}) {
  if (!enabled) return const [];
  final onMobile = network == NetworkKind.mobile;
  final seen = <String>{};
  final servers = <String>[];
  for (final raw in onMobile ? mobile : wifi) {
    final tag = raw.trim();
    if (tag.isEmpty || !seen.add(tag)) continue;
    if (onMobile && !ServerRegionFilter.isMobileOnly(tag)) continue;
    servers.add(tag);
    if (servers.length == aiGroupMaxServers) break;
  }
  return servers;
}

/// [current] with row [index] (0: main, 1 and 2: backups) set to [tag], or cleared when [tag] is null (the rows below
/// move up). A server already in another row moves: the list never repeats a server, and never has more than
/// [aiGroupMaxServers].
List<String> setAiServer(List<String> current, int index, String? tag) {
  final list = [...current];
  if (tag == null) {
    if (index >= 0 && index < list.length) list.removeAt(index);
    return list;
  }
  final at = index < list.length ? index : list.length;
  if (at == list.length) {
    list.add(tag);
  } else {
    list[at] = tag;
  }
  return [
    for (var i = 0; i < list.length; i++)
      if (list[i] != tag || i == at) list[i],
  ].take(aiGroupMaxServers).toList();
}

/// The servers offered for an AI group row: no groups (Auto...), no hidden or switched-off ones, on mobile data only the
/// whitelist servers and on Wi-Fi none of them, and none that [taken] by the other rows already.
List<OutboundInfo> aiCandidates(
  Iterable<OutboundInfo> items, {
  required NetworkKind network,
  required Iterable<String> taken,
}) {
  final used = taken.toSet();
  final result = <OutboundInfo>[];
  for (final item in items) {
    if (item.isGroup || !item.isVisible || item.tag.contains('§hide§') || used.contains(item.tag)) continue;
    final mobileOnly = ServerRegionFilter.isMobileOnly(item.tag);
    if (network == NetworkKind.mobile && !mobileOnly) continue;
    if (network != NetworkKind.mobile && mobileOnly) continue;
    result.add(item);
  }
  // the fastest first, the ones that did not answer last (the order of the list for equal pings)
  int rank(OutboundInfo e) => e.urlTestDelay > 0 && e.urlTestDelay < 65000 ? e.urlTestDelay : 1 << 30;
  final order = {for (var i = 0; i < result.length; i++) result[i].tag: i};
  result.sort((a, b) {
    final byPing = rank(a).compareTo(rank(b));
    return byPing != 0 ? byPing : order[a.tag]!.compareTo(order[b.tag]!);
  });
  return result;
}
