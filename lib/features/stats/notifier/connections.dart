import 'package:hiddify/features/profile/widget/profile_badge.dart';
import 'package:hiddify/core/preferences/light_mode.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/utils/custom_loggers.dart';
import 'package:flutter/widgets.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/route_rules/notifier/rule_groups.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Where a connection went.
enum ConnectionRoute { vpn, direct, block }

typedef RouteUsage = Map<ConnectionRoute, Map<String, List<(int, int)>>>;

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
    this.session,
  });

  final String id;
  final int? session;

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
    session: session,
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
    session: session,
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
    if (session != null) 'session': session,
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
        session: json['session'] as int?,
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
  static SeenConnection? fromClash(Map<String, dynamic> json, {int? session}) {
    final id = json['id'];
    final meta = json['metadata'];
    if (id is! String || meta is! Map) return null;
    final chains = (json['chains'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final host = (meta['host'] as String?)?.trim() ?? '';
    final ip = (meta['destinationIP'] as String?)?.trim() ?? '';
    return SeenConnection(
      id: id,
      session: session,
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
    if (dash < 0) {
      return '$name${profileMark(profileOfTag(tag))}';
    }
    final flag = RegExp(r'^(\S+)\s').firstMatch(name)?.group(1);
    final isFlag = flag != null && flag.runes.any((r) => r >= 0x1F1E6 && r <= 0x1F1FF);
    var country = name.substring(dash + 3).trim();
    // a whitelist server ("LTE Only", "БС") keeps a mark, or it reads like the regular one of that country
    if (ServerRegionFilter.isMobileOnly(name) && !country.contains('БС')) country = '$country · БС';
    // with several subscriptions: which one it is from, as a mark nobody sees (the flag's badge shows it)
    final mark = profileMark(profileOfTag(tag));
    return isFlag ? '$flag $country$mark' : '$country$mark';
  }
}

/// What the Connections tab shows.
class ConnectionsState {
  const ConnectionsState({
    this.items = const [],
    this.sessionItems = const [],
    this.available = true,
    this.since,
    this.usage = const {},
    this.routeUsage = const {},
  });

  /// by app: the stretches of time it had a connection open (ms since the epoch, from and to, merged, oldest
  /// first); see [usageSince]
  final Map<String, List<(int, int)>> usage;

  /// by route, then app: open-connection stretches, oldest first
  final RouteUsage routeUsage;

  /// open ones and the ones closed today (the latest [Connections.keepClosed]), newest first
  final List<SeenConnection> items;
  final List<SeenConnection> sessionItems;

  /// false: the core's connection list can't be reached (not connected, or the Clash API is off)
  final bool available;

  /// when the list started: 03:00 today (the statistics day), or when it was last cleared
  final DateTime? since;
}

/// How long [app] had a connection open from [from] to [now]: its stretches in [usage], cut to that time.
Duration usageSince(Map<String, List<(int, int)>> usage, String app, DateTime from, DateTime now) {
  final a = from.millisecondsSinceEpoch;
  final b = now.millisecondsSinceEpoch;
  var ms = 0;
  for (final (start, end) in usage[app] ?? const <(int, int)>[]) {
    final s = start < a ? a : start;
    final e = end > b ? b : end;
    if (e > s) ms += e - s;
  }
  return Duration(milliseconds: ms);
}

/// How long [app] had a connection open through [route], clipped to the current session.
Duration routeAppUsageSince(RouteUsage usage, ConnectionRoute route, String app, DateTime from, DateTime now) =>
    usageSince(usage[route] ?? const {}, app, from, now);

/// The connections attributable to screen-visible apps, with each app shown on the route carrying most of its
/// traffic. This keeps background services and duplicate app rows out of the home screen's activity cards.
Map<ConnectionRoute, List<SeenConnection>> foregroundConnectionsByRoute(
  Iterable<SeenConnection> connections,
  Map<String, Duration> foregroundTime,
) {
  final totals = <String, Map<ConnectionRoute, int>>{};
  for (final connection in connections) {
    if (connection.app.isEmpty || connection.route == ConnectionRoute.block) continue;
    totals.putIfAbsent(connection.app, () => {})[connection.route] =
        (totals[connection.app]![connection.route] ?? 0) + connection.total;
  }

  final mainRoute = <String, ConnectionRoute>{};
  for (final entry in totals.entries) {
    if ((foregroundTime[entry.key]?.inMilliseconds ?? 0) <= 0) continue;
    final routes = entry.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (routes.isNotEmpty) mainRoute[entry.key] = routes.first.key;
  }

  return {
    for (final route in [ConnectionRoute.vpn, ConnectionRoute.direct])
      route: [
        for (final app in mainRoute.entries.where((entry) => entry.value == route).map((entry) => entry.key))
          ...connections.where((connection) => connection.app == app && connection.route == route),
      ],
  };
}

/// Add the open intervals for each route, counting parallel connections from one app only once per route.
void trackRouteUsage(RouteUsage usage, Iterable<SeenConnection> open, DateTime now) {
  final to = now.millisecondsSinceEpoch;
  for (final route in ConnectionRoute.values) {
    final earliestByApp = <String, int>{};
    for (final c in open.where((c) => c.route == route && c.app.isNotEmpty)) {
      final start = c.start.millisecondsSinceEpoch;
      final known = earliestByApp[c.app];
      if (known == null || start < known) earliestByApp[c.app] = start;
    }
    earliestByApp.forEach((app, start) => _extendRouteUsage(usage[route]!.putIfAbsent(app, () => []), start, to));
  }
}

void _extendRouteUsage(List<(int, int)> stretches, int start, int to) {
  if (stretches.isNotEmpty && stretches.last.$2 >= start) {
    stretches[stretches.length - 1] = (stretches.last.$1, to);
  } else {
    stretches.add((start > to ? to : start, to));
  }
}

/// The connections the core reports through its local Clash API, every 2 seconds from the app's start (main.dart
/// reads it), with the ones that have closed since kept for the whole statistics day, so short ones (a site's
/// images, a DNS lookup) show too. The list is saved to disk now and then, so it's still there when the app
/// comes back after Android closed it or the VPN reconnects; at 03:00 (or when the user clears it) it starts over.
final connectionsProvider = NotifierProvider<Connections, ConnectionsState>(Connections.new);

class Connections extends Notifier<ConnectionsState> {
  static const interval = Duration(seconds: 2);

  /// while A-VPN is in the background (or the screen is off): fewer wake-ups, the battery lasts longer; the
  /// traffic still adds up from the core's own totals
  static const backgroundInterval = Duration(seconds: 30);
  static const keepClosed = 400;
  static const saveEvery = Duration(seconds: 10);

  HttpClient? _client;
  final _seen = <String, SeenConnection>{};

  /// by app: when it had a connection open (see [ConnectionsState.usage])
  final _usage = <String, List<(int, int)>>{};

  /// by route and app: connection stretches kept separately from the all-route app total
  final RouteUsage _routeUsage = {for (final route in ConnectionRoute.values) route: {}};

  /// the statistics day the list belongs to (its 03:00), and when it starts (that, or the last clearing)
  final _dayBaselines = <String, (int, int)>{};
  DateTime? _day;
  DateTime? _since;
  DateTime _saved = DateTime.fromMillisecondsSinceEpoch(0);

  File? get _file {
    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    return dirs == null ? null : File('${dirs.baseDir.path}/connections_day.json');
  }

  @override
  ConnectionsState build() {
    ref.watch(sessionStartProvider);
    // the light background work: the polls twice as far apart, and a long way apart out of sight
    final saving = ref.watch(lightBackgroundProvider);
    // the night mode: out of sight the list is asked for six times less often (every three minutes)
    final night = ref.watch(nightModeProvider);
    _rollDay();
    final connected = ref.watch(connectionNotifierProvider).valueOrNull is Connected;
    final enabled = ref.watch(ConfigOptions.enableClashApi);
    final port = ref.watch(ConfigOptions.clashApiPort);
    final secret = ref.watch(ConfigOptions.clashApiSecret);
    // not connected (or only for a moment while the app comes back): nothing to ask, the list stays as it is
    if (!connected || !enabled) {
      return ConnectionsState(
        items: _sorted(),
        sessionItems: _sessionItems(),
        available: false,
        since: _since,
        usage: _usage,
        routeUsage: _routeUsage,
      );
    }
    // the core's API is on this machine: never through a proxy
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..findProxy = ((_) => 'DIRECT');
    _client = client;
    final url = Uri.parse('http://127.0.0.1:$port/connections');
    var foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    var disposed = false;
    Timer? timer;
    void schedule() {
      timer?.cancel();
      timer = Timer(foreground ? interval * (saving ? 2 : 1) : backgroundInterval * (saving ? 4 : (night ? 6 : 1)), () {
        if (disposed) return;
        unawaited(_poll(client, url, secret));
        schedule();
      });
    }

    final lifecycle = AppLifecycleListener(
      onResume: () {
        foreground = true;
        unawaited(_poll(client, url, secret));
        schedule();
      },
      onHide: () {
        foreground = false;
        schedule();
      },
      onPause: () {
        foreground = false;
        schedule();
      },
    );
    schedule();
    ref.onDispose(() {
      disposed = true;
      lifecycle.dispose();
      timer?.cancel();
      client.close(force: true);
      _client = null;
    });
    unawaited(_poll(client, url, secret));
    return ConnectionsState(
      items: _sorted(),
      sessionItems: _sessionItems(),
      since: _since,
      usage: _usage,
      routeUsage: _routeUsage,
    );
  }

  /// Picks up the saved list once, and starts a new one when a new statistics day has begun (03:00).
  void _rollDay([DateTime? now]) {
    final day = statsDayStart(now ?? DateTime.now());
    if (_day == null && _file != null) {
      _day = day;
      _since = day;
      _restore(day);
    }
    if (_day != null && _day != day) {
      _dayBaselines.clear();
      for (final c in _seen.values.where((c) => c.active)) {
        _dayBaselines[c.id] = (c.up, c.down);
      }
      // past 03:00: yesterday's closed connections go, the open ones carry on
      _seen.removeWhere((_, c) => !c.active && c.session != ref.read(sessionStartProvider)?.millisecondsSinceEpoch);
      _day = day;
      _since = day;
      _save();
    }
  }

  void _restore(DateTime day) {
    try {
      final file = _file;
      if (file == null || !file.existsSync()) return;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final sameDay = json['day'] == day.millisecondsSinceEpoch;
      if (sameDay) {
        (json['dayBaselines'] as Map<String, dynamic>? ?? {}).forEach((id, value) {
          final pair = value as List;
          _dayBaselines[id] = (pair[0] as int, pair[1] as int);
        });
      }
      final since = json['since'] as int?;
      if (sameDay && since != null) _since = DateTime.fromMillisecondsSinceEpoch(since);
      for (final item in (json['items'] as List).whereType<Map<String, dynamic>>()) {
        final c = SeenConnection.fromJson(item);
        if (c != null && (sameDay || c.session != null) && !isAdultHost(c.host) && !_hidden(c.app)) {
          _seen[c.id] = c;
          if (!sameDay) _dayBaselines[c.id] = (c.up, c.down);
        }
      }
      (json['usage'] as Map<String, dynamic>? ?? {}).forEach((app, list) {
        _usage[app] = [
          for (final pair in (list as List).whereType<List>())
            if (pair.length == 2) ((pair[0] as num).toInt(), (pair[1] as num).toInt()),
        ];
      });
      (json['routeUsage'] as Map<String, dynamic>? ?? {}).forEach((routeName, byApp) {
        final route = ConnectionRoute.values.where((value) => value.name == routeName).firstOrNull;
        if (route == null || byApp is! Map<String, dynamic>) return;
        byApp.forEach((app, list) {
          if (list is! List) return;
          _routeUsage[route]![app] = [
            for (final pair in list.whereType<List>())
              if (pair.length == 2) ((pair[0] as num).toInt(), (pair[1] as num).toInt()),
          ];
        });
      });
    } catch (_) {
      // an unreadable list is just not restored
    }
  }

  void _save() {
    final file = _file;
    final day = _day;
    if (file == null || day == null) return;
    _saved = DateTime.now();
    final json = jsonEncode({
      'day': day.millisecondsSinceEpoch,
      'since': _since?.millisecondsSinceEpoch,
      'items': [for (final c in _seen.values) c.toJson()],
      'dayBaselines': {
        for (final e in _dayBaselines.entries) e.key: [e.value.$1, e.value.$2],
      },
      'usage': {
        for (final e in _usage.entries)
          e.key: [
            for (final (a, b) in e.value) [a, b],
          ],
      },
      'routeUsage': {
        for (final route in ConnectionRoute.values)
          route.name: {
            for (final e in _routeUsage[route]!.entries)
              e.key: [
                for (final (a, b) in e.value) [a, b],
              ],
          },
      },
    });
    unawaited(file.writeAsString(json).then((_) {}, onError: (_) {}));
  }

  /// Forget the closed ones: the list (and the Topology tab) starts over from now.
  void clearClosed() {
    _seen.removeWhere((_, c) => !c.active);
    _since = DateTime.now();
    _dropUsageBefore(_since!);
    state = ConnectionsState(
      items: _sorted(),
      sessionItems: _sessionItems(),
      since: _since,
      usage: _usage,
      routeUsage: _routeUsage,
    );
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
    _rollDay();
    if (list == null && _seen.isEmpty) {
      state = ConnectionsState(available: false, since: _since);
      return;
    }
    final open = <String>{};
    for (final entry in list ?? const []) {
      if (entry is! Map<String, dynamic>) continue;
      final c = SeenConnection.fromClash(entry, session: ref.read(sessionStartProvider)?.millisecondsSinceEpoch);
      // adult sites go through the VPN but are never listed
      if (c == null || isAdultHost(c.host) || _hidden(c.app)) continue;
      open.add(c.id);
      _seen[c.id] = c;
    }
    if (list != null) {
      for (final id in _seen.keys.toList()) {
        if (!open.contains(id) && _seen[id]!.active) _seen[id] = _seen[id]!.closed();
      }
    }
    if (list != null) _track(open.map((id) => _seen[id]!), DateTime.now());
    _logCounts(list?.length);
    _fold();
    state = ConnectionsState(
      items: _sorted(),
      sessionItems: _sessionItems(),
      since: _since,
      usage: Map.of(_usage),
      routeUsage: _routeUsage,
    );
    if (DateTime.now().difference(_saved) > saveEvery) _save();
  }

  /// Each app with a connection open now: its stretch goes on to now, or a new one starts with the earliest of
  /// them (when that began after the last stretch ended); parallel connections don't add up twice.
  void _track(Iterable<SeenConnection> open, DateTime now) {
    final earliest = <String, int>{};
    for (final c in open) {
      final start = c.start.millisecondsSinceEpoch;
      final known = earliest[c.app];
      if (known == null || start < known) earliest[c.app] = start;
    }
    final to = now.millisecondsSinceEpoch;
    earliest.forEach((app, start) {
      _extendUsage(_usage.putIfAbsent(app, () => []), start, to);
    });
    trackRouteUsage(_routeUsage, open, now);
  }

  void _extendUsage(List<(int, int)> stretches, int start, int to) {
    if (stretches.isNotEmpty && stretches.last.$2 >= start) {
      stretches[stretches.length - 1] = (stretches.last.$1, to);
    } else {
      stretches.add((start > to ? to : start, to));
    }
  }

  void _dropUsageBefore(DateTime from) {
    final a = from.millisecondsSinceEpoch;
    for (final stretches in _usage.values) {
      stretches.removeWhere((s) => s.$2 <= a);
    }
    _usage.removeWhere((_, s) => s.isEmpty);
    for (final stretches in _routeUsage.values) {
      for (final appStretches in stretches.values) {
        appStretches.removeWhere((s) => s.$2 <= a);
      }
      stretches.removeWhere((_, appStretches) => appStretches.isEmpty);
    }
  }

  /// The latest [keepClosed] closed connections are kept one by one; older ones are added up by app, site, route,
  /// server and rule, so their traffic still counts.
  void _fold() {
    final closed =
        _seen.values
            .where((c) => !c.active && !c.id.startsWith(summaryPrefix) && !_dayBaselines.containsKey(c.id))
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    for (final c in closed.skip(keepClosed)) {
      _seen.remove(c.id);
      final key = connectionSummaryKey(c);
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

  List<SeenConnection> _sessionItems() => _seen.values.toList();

  DateTime _counted = DateTime.fromMillisecondsSinceEpoch(0);

  /// One line a minute in the log: how many connections the core listed and how many are kept, for the session and
  /// by the session's stamp (the Traffic page lists by it).
  void _logCounts(int? listed) {
    final now = DateTime.now();
    if (now.difference(_counted) < const Duration(minutes: 1)) return;
    _counted = now;
    final start = ref.read(sessionStartProvider)?.millisecondsSinceEpoch;
    final stamped = _seen.values.where((c) => c.session == start).length;
    appLogger('connections').info('listed=${listed ?? -1} kept=${_seen.length} stamped=$stamped session=$start');
  }

  List<SeenConnection> _sorted() => [
    for (final c in _seen.values)
      if (_dayBaselines.containsKey(c.id) &&
          (c.active || c.up > _dayBaselines[c.id]!.$1 || c.down > _dayBaselines[c.id]!.$2))
        dailyConnection(c, _dayBaselines[c.id]!, _since!)
      else if (c.active || _since == null || !c.start.isBefore(_since!))
        c,
  ]..sort((a, b) => b.start.compareTo(a.start));
}

/// The connections of the VPN session on screen: from its switch-on (the core's session start) to its switch-off,
/// as the totals and the time are. The VPN off: none (the last session's list isn't shown). The session's start
/// not known yet: none rather than the whole day's list. A connection counts if it carries the session's stamp or
/// began after the session did.
List<SeenConnection> sessionConnections(
  ConnectionsState state, {
  required bool connected,
  required DateTime? sessionStart,
}) => [
  if (connected && sessionStart != null)
    for (final c in state.sessionItems)
      if (c.session == sessionStart.millisecondsSinceEpoch || !c.start.isBefore(sessionStart)) c,
];

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
    // a whitelist server's flag carries the mark: 🇸🇪БС next to a plain 🇸🇪
    shown.add(isFlag ? (server.contains('БС') ? '$flagБС' : flag) : server);
  }
  return shown.join(' ');
}

/// Programs left out of the traffic lists: Google Drive for desktop syncs in the background and would fill them.
bool _hidden(String app) => app.toLowerCase().contains('googledrivefs');

/// A summary can contain one logical VPN session only. Legacy rows stay isolated by start.
String connectionSummaryKey(SeenConnection c) =>
    '${Connections.summaryPrefix}${c.session ?? c.start.millisecondsSinceEpoch}|${statsDayStart(c.start).millisecondsSinceEpoch}|${c.app}|${c.host}|${c.route.name}|${c.outbound}|${c.rule}';

/// The daily projection subtracts bytes already counted before 03:00; the session row remains intact.
SeenConnection dailyConnection(SeenConnection c, (int, int) baseline, DateTime day) => SeenConnection(
  id: c.id,
  app: c.app,
  host: c.host,
  port: c.port,
  network: c.network,
  route: c.route,
  outbound: c.outbound,
  rule: c.rule,
  start: day,
  session: c.session,
  up: (c.up - baseline.$1).clamp(0, c.up),
  down: (c.down - baseline.$2).clamp(0, c.down),
  active: c.active,
  count: c.count,
);
