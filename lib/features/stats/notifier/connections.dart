import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
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
    this.count = 1,
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

  /// how many connections this is: more than one for older closed ones added up by app, site, route and rule, so
  /// a long session keeps all of its traffic without keeping every connection
  final int count;

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
    count: count,
  );

  /// [other] added to this one, kept under [id]
  SeenConnection plus(SeenConnection other, String id) => SeenConnection(
    id: id,
    app: app,
    host: host,
    port: port == other.port ? port : 0,
    network: network == other.network ? network : '',
    route: route,
    outbound: outbound,
    rule: rule,
    start: start.isAfter(other.start) ? start : other.start,
    up: up + other.up,
    down: down + other.down,
    active: false,
    count: count + other.count,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'app': app,
    'host': host,
    'port': port,
    'network': network,
    'route': route.name,
    'outbound': outbound,
    'rule': rule,
    'start': start.millisecondsSinceEpoch,
    'up': up,
    'down': down,
    if (count != 1) 'count': count,
  };

  /// A saved one: closed, since the app was away when it was saved.
  static SeenConnection? fromJson(Map<String, dynamic> json) {
    try {
      return SeenConnection(
        id: json['id'] as String,
        app: json['app'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        network: json['network'] as String,
        route: ConnectionRoute.values.byName(json['route'] as String),
        outbound: json['outbound'] as String,
        rule: json['rule'] as String,
        start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int),
        up: json['up'] as int,
        down: json['down'] as int,
        active: false,
        count: json['count'] as int? ?? 1,
      );
    } catch (_) {
      return null;
    }
  }

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
    final name = tag
        .replaceAll('§hide§', '')
        .replaceAll(RegExp(r'\s*§\s*\d+\s*$'), '')
        .replaceAll(RegExp('Доступ', caseSensitive: false), 'Sigma')
        .trim();
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

/// The connections the core reports through its local Clash API, every 2 seconds from the app's start (main.dart
/// reads it), with the ones that have closed since kept for the whole VPN session, so short ones (a site's images,
/// a DNS lookup) show too. The list is saved to disk now and then, so it's still there when the app comes back
/// after Android closed it; a new session (the core's start time changes) starts it over.
final connectionsProvider = NotifierProvider<Connections, ConnectionsState>(Connections.new);

class Connections extends Notifier<ConnectionsState> {
  static const interval = Duration(seconds: 2);
  static const keepClosed = 400;
  static const saveEvery = Duration(seconds: 10);

  HttpClient? _client;
  final _seen = <String, SeenConnection>{};

  /// the VPN session the list belongs to (the core's start time)
  DateTime? _session;
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);

  File? get _file {
    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    return dirs == null ? null : File('${dirs.baseDir.path}/connections_session.json');
  }

  @override
  ConnectionsState build() {
    ref.listen(statsNotifierProvider, (_, next) {
      final session = next.valueOrNull?.sessionStartedAt;
      if (session == null || session == _session) return;
      final first = _session == null;
      _session = session;
      if (first && _seen.isEmpty) {
        _restore(session);
      } else {
        // a new VPN session: a new list
        _seen.clear();
      }
      state = ConnectionsState(items: _sorted(), available: state.available, since: session);
    });
    final connected = ref.watch(connectionNotifierProvider).valueOrNull is Connected;
    final enabled = ref.watch(ConfigOptions.enableClashApi);
    final port = ref.watch(ConfigOptions.clashApiPort);
    final secret = ref.watch(ConfigOptions.clashApiSecret);
    // not connected (or only for a moment while the app comes back): nothing to ask, the list stays as it is
    if (!connected || !enabled) return ConnectionsState(items: _sorted(), available: false, since: _session);
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
    return ConnectionsState(items: _sorted(), since: _session);
  }

  void _restore(DateTime session) {
    try {
      final file = _file;
      if (file == null || !file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (json['session'] != session.millisecondsSinceEpoch) return;
      for (final item in (json['items'] as List).whereType<Map<String, dynamic>>()) {
        final c = SeenConnection.fromJson(item);
        if (c != null) _seen[c.id] = c;
      }
    } catch (_) {
      // an unreadable list is just not restored
    }
  }

  void _save() {
    final file = _file;
    final session = _session;
    if (file == null || session == null) return;
    _saved = DateTime.now();
    final json = jsonEncode({
      'session': session.millisecondsSinceEpoch,
      'items': [for (final c in _seen.values) c.toJson()],
    });
    unawaited(file.writeAsString(json).then((_) {}, onError: (_) {}));
  }

  /// Forget the closed ones.
  void clearClosed() {
    _seen.removeWhere((_, c) => !c.active);
    state = ConnectionsState(items: _sorted(), since: _session);
    _save();
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
      state = ConnectionsState(available: false, since: _session);
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
    _fold();
    state = ConnectionsState(items: _sorted(), since: _session);
    if (DateTime.now().difference(_saved) > saveEvery) _save();
  }

  /// The latest [keepClosed] closed connections are kept one by one; older ones are added up by app, site, route,
  /// server and rule, so their traffic still counts.
  void _fold() {
    final closed = _seen.values.where((c) => !c.active && !c.id.startsWith(summaryPrefix)).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    for (final c in closed.skip(keepClosed)) {
      _seen.remove(c.id);
      final key = '$summaryPrefix${c.app}|${c.host}|${c.route.name}|${c.outbound}|${c.rule}';
      final summary = _seen[key];
      _seen[key] = summary == null ? c.plus(_none, key) : summary.plus(c, key);
    }
  }

  static const summaryPrefix = 'sum:';
  static final _none = SeenConnection(
    id: '',
    app: '',
    host: '',
    port: 0,
    network: '',
    route: ConnectionRoute.direct,
    outbound: '',
    rule: '',
    start: DateTime.fromMillisecondsSinceEpoch(0),
    up: 0,
    down: 0,
    active: false,
    count: 0,
  );

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

  /// connections in it (an added-up entry counts as all of its connections)
  int count = 0;

  int get total => up + down;

  void add(SeenConnection c) {
    items.add(c);
    count += c.count;
    up += c.up;
    down += c.down;
    if (c.active) open++;
    switch (c.route) {
      case ConnectionRoute.vpn:
        vpn += c.count;
      case ConnectionRoute.direct:
        direct += c.count;
      case ConnectionRoute.block:
        blocked += c.count;
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
    return byTraffic != 0 ? byTraffic : b.count.compareTo(a.count);
  });
}

/// Servers in short: one keeps its name ("🇸🇪 Швеция 3"); several show just their flags, each country once
/// ("🇸🇪 🇫🇮 🇵🇱"), a server without a flag by name.
String serverFlags(Iterable<String> servers) {
  final list = servers.toList();
  if (list.length <= 1) return list.join();
  final shown = <String>{};
  for (final server in list) {
    final flag = RegExp(r'^(\S+)\s').firstMatch(server)?.group(1);
    final isFlag = flag != null && flag.runes.any((r) => r >= 0x1F1E6 && r <= 0x1F1FF);
    shown.add(isFlag ? flag : server);
  }
  return shown.join(' ');
}
