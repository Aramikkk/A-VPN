import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A site the home screen shows the delay to: its name, the letter in its circle and the page asked.
/// [get]: asked with GET (a page that answers HEAD with a redirect and a closed connection).
typedef LatencySite = ({String key, String name, String letter, String url, bool get});

/// The sites, as the user uses them most. The address is kept as http:// and asked over HTTP or HTTPS as Settings →
/// Ping says (pingUrl).
const latencySites = <LatencySite>[
  (key: 'instagram', name: 'Instagram', letter: 'I', url: 'http://www.instagram.com/', get: false),
  (key: 'whatsapp', name: 'WhatsApp', letter: 'W', url: 'http://web.whatsapp.com/', get: false),
  (key: 'telegram', name: 'Telegram', letter: 'T', url: 'http://telegram.org/', get: false),
  // chatgpt.com (Cloudflare) closes the connection on its page's redirect, so the second request opened a new one
  // (~250 ms where the others read ~80): Cloudflare's tiny trace page keeps it, asked with GET
  (key: 'chatgpt', name: 'ChatGPT', letter: 'G', url: 'http://chatgpt.com/cdn-cgi/trace', get: true),
  // YouTube's home page is built on every request (~350 ms of the server's own work): its empty answer, the same
  // the servers' ping uses, times just the way there and back
  (key: 'youtube', name: 'YouTube', letter: 'Y', url: 'http://www.youtube.com/generate_204', get: false),
  // Google Drive: its front page (it answers with a redirect, timed over the open connection as the rest)
  (key: 'gdrive', name: 'Google Диск', letter: 'G', url: 'http://drive.google.com/', get: false),
  // more to choose from in Settings → Sites (the home screen shows the ones marked there)
  (key: 'gemini', name: 'Gemini', letter: 'G', url: 'http://gemini.google.com/', get: false),
  (key: 'claude', name: 'Claude', letter: 'C', url: 'http://claude.ai/', get: false),
  (key: 'perplexity', name: 'Perplexity', letter: 'P', url: 'http://www.perplexity.ai/', get: false),
  (key: 'discord', name: 'Discord', letter: 'D', url: 'http://discord.com/', get: false),
  (key: 'twitter', name: 'X', letter: 'X', url: 'http://x.com/', get: false),
  (key: 'facebook', name: 'Facebook', letter: 'F', url: 'http://www.facebook.com/', get: false),
  (key: 'tiktok', name: 'TikTok', letter: 'T', url: 'http://www.tiktok.com/', get: false),
  (key: 'spotify', name: 'Spotify', letter: 'S', url: 'http://open.spotify.com/', get: false),
  (key: 'netflix', name: 'Netflix', letter: 'N', url: 'http://www.netflix.com/', get: false),
];

/// How many sites the home screen shows (three rows of three).
const maxHomeSites = 9;

/// A site of the user's own, as saved: "name<SOH>address".
LatencySite? customLatencySite(String saved) {
  final parts = saved.split('\u0001');
  if (parts.length != 2 || parts[0].trim().isEmpty || parts[1].trim().isEmpty) return null;
  final name = parts[0].trim();
  return (key: 'c:$name', name: name, letter: name.substring(0, 1).toUpperCase(), url: parts[1].trim(), get: false);
}

/// What was typed as an address ("example.com", "https://example.com/page") as the page asked: http:// first, as the
/// others are kept (Settings → Ping decides HTTP or HTTPS); null when it isn't an address.
String? latencyAddress(String typed) {
  var s = typed.trim();
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  s = s.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  final host = s.split(RegExp(r'[/?#]')).first;
  if (!host.contains('.') || host.startsWith('.') || host.endsWith('.')) return null;
  return 'http://${s.endsWith('/') || s.contains('/') ? s : '$s/'}';
}

/// Every site Settings → Sites lists: the catalog, then the user's own.
final latencyCatalogProvider = Provider<List<LatencySite>>((ref) {
  final custom = ref.watch(Preferences.latencyCustom);
  final all = [...latencySites, ...custom.map(customLatencySite).nonNulls];
  return orderedSites(all, ref.watch(Preferences.latencyOrder));
});

/// [sites] in the user's [order] (keys): the named ones first as named, the others after them as they were.
List<LatencySite> orderedSites(List<LatencySite> sites, List<String> order) {
  final byKey = {for (final s in sites) s.key: s};
  final named = <LatencySite>[];
  for (final key in order) {
    final site = byKey.remove(key);
    if (site != null) named.add(site);
  }
  return [...named, ...byKey.values];
}

/// [keys] with the one at [from] moved to [to], as a ReorderableListView reports it (the target counts the moved one
/// still in place, so a move down is one less).
List<String> movedKey(List<String> keys, int from, int to) {
  final list = [...keys];
  if (from < 0 || from >= list.length) return list;
  final key = list.removeAt(from);
  list.insert((to > from ? to - 1 : to).clamp(0, list.length), key);
  return list;
}

/// The sites marked for the home screen, in the list's order: the delay is asked to these, and they are the tiles.
final homeSitesProvider = Provider<List<LatencySite>>((ref) {
  final marked = ref.watch(Preferences.latencyHome).toSet();
  return ref.watch(latencyCatalogProvider).where((s) => marked.contains(s.key)).take(maxHomeSites).toList();
});

/// The server each site goes through when each has its own (Settings → Ping → Sites, beta): the site's key → the
/// server's tag, read from the core's site groups ("site-<key>"); empty when that's off.
final siteServersProvider = StreamProvider<Map<String, String>>((ref) {
  // on for either network: the core has the groups only on the one it's on, so the map is empty on the other
  final on = ref.watch(ConfigOptions.siteGroups) || ref.watch(ConfigOptions.siteGroupsMobile);
  if (!on || !ref.watch(serviceRunningProvider)) return Stream.value(const {});
  return ref
      .watch(proxyRepositoryProvider)
      .watchActiveProxies()
      .map((event) => event.getOrElse((_) => const []))
      .map(
        (groups) => {
          for (final group in groups)
            if (group.tag.startsWith('site-') && group.selected.isNotEmpty) group.tag.substring(5): group.selected,
        },
      );
});

/// The last round: each site's delay in ms (null: no answer in time), when it ran, and whether one runs now.
/// [done]: the sites answered (or given up) in the round running now.
typedef SiteLatencyState = ({Map<String, int?> ms, DateTime? at, bool testing, int done});

final siteLatencyProvider = NotifierProvider<SiteLatency, SiteLatencyState>(SiteLatency.new);

/// The delay to the sites the user uses most, through the VPN as their apps go: a request to each through A-VPN's
/// proxy port, timed to the answer. Asked when the VPN comes up (the app opened, a reconnect), with every ping of
/// the servers (the button, the minute's quiet one, the ping on opening) and after Auto changed its server.
class SiteLatency extends Notifier<SiteLatencyState> {
  static const timeout = Duration(seconds: 5);

  String? _pick;
  bool _connected = false;

  @override
  SiteLatencyState build() {
    final connected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    if (connected && !_connected) Future.microtask(test);
    _connected = connected;
    // Auto moved to another server: the sites again
    ref.listen(proxiesOverviewNotifierProvider, (_, next) {
      final pick = _autoPick(next.valueOrNull);
      if (pick == null) return;
      final changed = _pick != null && pick != _pick;
      _pick = pick;
      if (changed) unawaited(test());
    });
    return stateOrNull ?? (ms: const {}, at: null, testing: false, done: 0);
  }

  /// The server Auto (or the chosen server) uses now.
  static String? mainServer(OutboundGroup? group) => _autoPick(group);

  static String? _autoPick(OutboundGroup? group) {
    if (group == null) return null;
    final selected = group.items.where((i) => i.tag == group.selected).firstOrNull;
    if (selected == null) return null;
    return selected.isGroup ? selected.groupSelectedTag : selected.tag;
  }

  /// One round over every site, unless one runs or one ran a moment ago.
  Future<void> test() async {
    if (state.testing) return;
    if (state.at != null && DateTime.now().difference(state.at!) < const Duration(seconds: 3)) return;
    if (!(ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false)) return;
    if (!ref.read(ConfigOptions.enableMixedPort)) return;
    state = (ms: state.ms, at: state.at, testing: true, done: 0);
    final port = ref.read(ConfigOptions.mixedPort);
    final https = ref.read(ConfigOptions.pingHttps);
    // a client of its own each round, so a round starts from fresh connections
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
    final results = <String, int?>{};
    final shown = ref.read(homeSitesProvider);
    try {
      await Future.wait([
        for (final site in shown)
          () async {
            final url = Uri.parse(pingUrl(site.url, https));
            // a request that came back from the site (not the proxy's own error), timed
            Future<int?> once() async {
              final watch = Stopwatch()..start();
              final request = await (site.get ? client.getUrl(url) : client.headUrl(url)).timeout(timeout);
              request.followRedirects = false;
              request.persistentConnection = true;
              final response = await request.close().timeout(timeout);
              await response.drain<void>();
              return response.statusCode >= 500 ? null : watch.elapsedMilliseconds;
            }

            try {
              // the first opens the connection to the site through the VPN (its handshakes, the server finding the
              // site); the second goes over it, so it times just the way there and back, as a ping does
              final first = await once();
              if (first == null) {
                results[site.key] = null;
                return;
              }
              int? second;
              try {
                second = await once();
              } catch (_) {
                second = null;
              }
              results[site.key] = second ?? first;
            } catch (_) {
              results[site.key] = null;
            }
            state = (ms: state.ms, at: state.at, testing: true, done: results.length);
          }(),
      ]);
    } finally {
      client.close(force: true);
    }
    state = (ms: results, at: DateTime.now(), testing: false, done: shown.length);
  }
}
