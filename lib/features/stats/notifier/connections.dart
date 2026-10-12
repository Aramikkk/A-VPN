import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Where a connection went.
enum ConnectionRoute { vpn, direct, block }

/// One connection the core has seen: which app opened it, to which site, which way it went and how much it moved.
class SeenConnection {
  SeenConnection({
    required this.id,
    required this.app,
    required this.host,
    required this.port,
    required this.network,
    required this.route,
    required this.outbound,
    required this.rule,
    required this.start,
    required this.up,
    required this.down,
    required this.active,
  });

  final String id;

  /// the app's package (Android) or program path (Windows); empty when the core couldn't tell
  final String app;

  /// the site's name, or its address when the name isn't known
  final String host;
  final int port;

  /// tcp / udp
  final String network;
  final ConnectionRoute route;

  /// the server it went through ("🇸🇪 Sigma - Швеция 2"); empty for direct and blocked
  final String outbound;

  /// the routing rule that matched ("final" when none did)
  final String rule;
  final DateTime start;
  final int up;
  final int down;

  /// still open
  final bool active;

  int get total => up + down;

  SeenConnection closed() => SeenConnection(
    id: id,
    app: app,
    host: host,
    port: port,
    network: network,
    route: route,
    outbound: outbound,
    rule: rule,
    start: start,
    up: up,
    down: down,
    active: false,
  );

  /// One entry of the Clash API's /connections list.
  static SeenConnection? fromClash(Map<String, dynamic> json) {
    final id = json['id'];
    final meta = json['metadata'];
    if (id is! String || meta is! Map) return null;
    final chains = (json['chains'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final host = (meta['host'] as String?)?.trim() ?? '';
    final ip = (meta['destinationIP'] as String?)?.trim() ?? '';
    return SeenConnection(
      id: id,
      app: appOf((meta['processPath'] as String?) ?? ''),
      host: host.isNotEmpty ? host : ip,
      port: int.tryParse('${meta['destinationPort']}') ?? 0,
      network: (meta['network'] as String?) ?? '',
      route: routeOf(chains),
      outbound: routeOf(chains) == ConnectionRoute.vpn && chains.isNotEmpty ? serverName(chains.first) : '',
      rule: (json['rule'] as String?) ?? '',
      start: DateTime.tryParse('${json['start']}')?.toLocal() ?? DateTime.now(),
      up: (json['upload'] as num?)?.toInt() ?? 0,
      down: (json['download'] as num?)?.toInt() ?? 0,
      active: true,
    );
  }

  /// The core's "process path": "C:\…\chrome.exe", "com.google.android.youtube", or a user id with a name in
  /// brackets when there's no package ("1000 (android.uid.system)"). Kept as is apart from the brackets.
  static String appOf(String processPath) {
    final path = processPath.trim();
    final bracket = RegExp(r'^(\d+) \((.+)\)$').firstMatch(path);
    if (bracket != null) return bracket.group(2)!;
    final named = RegExp(r'^(.+) \(.+\)$').firstMatch(path);
    return named != null ? named.group(1)! : path;
  }

  /// The outbound chain, from the server outwards: "direct" and "block" are themselves; anything else went
  /// through the VPN.
  static ConnectionRoute routeOf(List<String> chains) {
    if (chains.isEmpty) return ConnectionRoute.direct;
    final first = chains.first.toLowerCase();
    if (first.startsWith('block') || first == 'reject') return ConnectionRoute.block;
    if (first.startsWith('direct') || first.contains('bypass')) return ConnectionRoute.direct;
    return ConnectionRoute.vpn;
  }

  /// "🇸🇪 Доступ - Швеция 2" → "🇸🇪 Швеция 2": the flag and the country, without the provider's prefix.
  static String serverName(String tag) {
    final name = tag.replaceAll(RegExp('Доступ', caseSensitive: false), 'Sigma').trim();
    final dash = name.indexOf(' - ');
    if (dash < 0) return name;
    final flag = RegExp(r'^(\S+)\s').firstMatch(name)?.group(1);
    final isFlag = flag != null && flag.runes.any((r) => r >= 0x1F1E6 && r <= 0x1F1FF);
    final country = name.substring(dash + 3).trim();
    return isFlag ? '$flag $country' : country;
  }
}

/// What the Connections tab shows.
class ConnectionsState {
  const ConnectionsState({this.items = const [], this.available = true, this.since});

  /// open ones and the ones closed this session (the latest [Connections.keepClosed]), newest first
  final List<SeenConnection> items;

  /// false: the core's connection list can't be reached (not connected, or the Clash API is off)
  final bool available;

  /// when the list started (the session's start, as far as this tab knows)
  final DateTime? since;
}

/// The connections the core reports through its local Clash API, every 2 seconds while the tab is open, with
/// the ones that have closed since kept for the session, so short ones (a site's images, a DNS lookup) show too.
final connectionsProvider = NotifierProvider<Connections, ConnectionsState>(Connections.new);

class Connections extends Notifier<ConnectionsState> {
  static const interval = Duration(seconds: 2);
  static const keepClosed = 400;

  HttpClient? _client;
  final _seen = <String, SeenConnection>{};

  @override
  ConnectionsState build() {
    final connected = ref.watch(connectionNotifierProvider).valueOrNull is Connected;
    final enabled = ref.watch(ConfigOptions.enableClashApi);
    final port = ref.watch(ConfigOptions.clashApiPort);
    final secret = ref.watch(ConfigOptions.clashApiSecret);
    if (!connected || !enabled) {
      _seen.clear();
      return const ConnectionsState(available: false);
    }
    // the core's API is on this machine: never through a proxy
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..findProxy = ((_) => 'DIRECT');
    _client = client;
    final url = Uri.parse('http://127.0.0.1:$port/connections');
    final timer = Timer.periodic(interval, (_) => _poll(client, url, secret));
    ref.onDispose(() {
      timer.cancel();
      client.close(force: true);
      _client = null;
    });
    unawaited(_poll(client, url, secret));
    return ConnectionsState(items: _sorted(), since: DateTime.now());
  }

  /// Forget the closed ones.
  void clearClosed() {
    _seen.removeWhere((_, c) => !c.active);
    state = ConnectionsState(items: _sorted(), since: DateTime.now());
  }

  Future<void> _poll(HttpClient client, Uri url, String secret) async {
    List<dynamic>? list;
    try {
      final request = await client.getUrl(url).timeout(const Duration(seconds: 3));
      if (secret.isNotEmpty) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
      final response = await request.close().timeout(const Duration(seconds: 3));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) list = (jsonDecode(body) as Map<String, dynamic>)['connections'] as List?;
    } catch (_) {
      list = null;
    }
    if (!identical(client, _client)) return; // disposed meanwhile
    if (list == null && _seen.isEmpty) {
      state = ConnectionsState(available: false, since: state.since);
      return;
    }
    final open = <String>{};
    for (final entry in list ?? const []) {
      if (entry is! Map<String, dynamic>) continue;
      final c = SeenConnection.fromClash(entry);
      if (c == null) continue;
      open.add(c.id);
      _seen[c.id] = c;
    }
    if (list != null) {
      for (final id in _seen.keys.toList()) {
        if (!open.contains(id) && _seen[id]!.active) _seen[id] = _seen[id]!.closed();
      }
    }
    // keep the latest closed ones only
    final closed = _seen.values.where((c) => !c.active).toList()..sort((a, b) => b.start.compareTo(a.start));
    for (final c in closed.skip(keepClosed)) {
      _seen.remove(c.id);
    }
    state = ConnectionsState(items: _sorted(), since: state.since);
  }

  List<SeenConnection> _sorted() => _seen.values.toList()..sort((a, b) => b.start.compareTo(a.start));
}

/// Apps and sites that moved less than this are hidden by default (1 MB).
const smallTraffic = 1024 * 1024;

/// Connections added up by a key (an app, or a site).
class ConnectionGroup {
  ConnectionGroup(this.key);

  final String key;
  final items = <SeenConnection>[];
  int up = 0;
  int down = 0;
  int vpn = 0;
  int direct = 0;
  int blocked = 0;
  int open = 0;

  int get total => up + down;

  void add(SeenConnection c) {
    items.add(c);
    up += c.up;
    down += c.down;
    if (c.active) open++;
    switch (c.route) {
      case ConnectionRoute.vpn:
        vpn++;
      case ConnectionRoute.direct:
        direct++;
      case ConnectionRoute.block:
        blocked++;
    }
  }

  /// the way most of its connections went
  ConnectionRoute get mainRoute => vpn >= direct && vpn >= blocked
      ? ConnectionRoute.vpn
      : (direct >= blocked ? ConnectionRoute.direct : ConnectionRoute.block);

  /// both ways
  bool get mixed => [vpn, direct, blocked].where((n) => n > 0).length > 1;

  /// the servers its VPN connections went through
  Set<String> get servers => {
    for (final c in items)
      if (c.outbound.isNotEmpty) c.outbound,
  };
}

/// [items] grouped by [keyOf], the most traffic first (then the most connections).
List<ConnectionGroup> groupConnections(Iterable<SeenConnection> items, String Function(SeenConnection) keyOf) {
  final groups = <String, ConnectionGroup>{};
  for (final c in items) {
    groups.putIfAbsent(keyOf(c), () => ConnectionGroup(keyOf(c))).add(c);
  }
  return groups.values.toList()..sort((a, b) {
    final byTraffic = b.total.compareTo(a.total);
    return byTraffic != 0 ? byTraffic : b.items.length.compareTo(a.items.length);
  });
}
