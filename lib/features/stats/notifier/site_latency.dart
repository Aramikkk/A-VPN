import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';
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
  // the AI chats: their apps are timed when marked for the home screen
  (key: 'gemini', name: 'Gemini', letter: 'G', url: 'http://gemini.google.com/', get: false),
  (key: 'claude', name: 'Claude', letter: 'C', url: 'http://claude.ai/', get: false),
  (key: 'perplexity', name: 'Perplexity', letter: 'P', url: 'http://www.perplexity.ai/', get: false),
  (key: 'deepseek', name: 'DeepSeek', letter: 'D', url: 'http://chat.deepseek.com/', get: false),
];

/// The services the home screen shows until the user marks other apps (Settings → Sites).
const defaultHomeServices = ['instagram', 'whatsapp', 'telegram', 'chatgpt', 'youtube', 'gdrive'];

/// How many tiles the home screen has (three rows of three).
const maxHomeSites = 9;

/// A service's key by the package of its phone app (the apps of Settings → Sites that are known services).
const appServices = {
  'com.instagram.android': 'instagram',
  'com.instagram.lite': 'instagram',
  'com.whatsapp': 'whatsapp',
  'com.whatsapp.w4b': 'whatsapp',
  'org.telegram.messenger': 'telegram',
  'org.telegram.messenger.web': 'telegram',
  'org.telegram.plus': 'telegram',
  'org.thunderdog.challegram': 'telegram',
  'com.openai.chatgpt': 'chatgpt',
  'com.google.android.youtube': 'youtube',
  'app.revanced.android.youtube': 'youtube',
  'com.google.android.apps.docs': 'gdrive',
  'com.google.android.apps.bard': 'gemini',
  'com.anthropic.claude': 'claude',
  'ai.perplexity.app.android': 'perplexity',
  'com.deepseek.chat': 'deepseek',
};

/// Whether the app [package] is marked for the home screen: in the saved list, or (until the list was ever saved,
/// "*") one of the six services' apps.
bool homeMarked(List<String> saved, String package) {
  if (saved.length == 1 && saved.first == '*') return defaultHomeServices.contains(appServices[package]);
  return saved.contains(package);
}

/// The tiles: on the phone the apps of Settings → Sites marked for the home screen, in the list's order (a service's
/// app is timed against its service, any other app against the test address); on a computer the six services.
List<LatencySite> homeSitesFor({
  required bool android,
  required List<String> apps,
  required List<String> saved,
  required String testUrl,
}) {
  if (!android) return [for (final key in defaultHomeServices) latencySites.firstWhere((s) => s.key == key)];
  final sites = <LatencySite>[];
  final seen = <String>{};
  for (final package in apps) {
    if (package.isEmpty || !homeMarked(saved, package)) continue;
    final service = appServices[package];
    final site = service != null
        ? latencySites.firstWhere((s) => s.key == service)
        : (
            key: 'app:$package',
            name: _appName(package),
            letter: _appName(package).substring(0, 1).toUpperCase(),
            url: testUrl,
            get: false,
          );
    if (seen.add(site.key)) sites.add(site);
  }
  return sites.take(maxHomeSites).toList();
}

/// A package's last part as a name ("ru.sberbankmobile" -> "sberbankmobile"), until the app's own name is read.
String _appName(String package) {
  final last = package.split('.').last;
  return last.isEmpty ? package : last;
}

/// [items] in the user's [order]: the named ones first as named, the others after them as they were.
List<String> orderedKeys(List<String> items, List<String> order) {
  final rest = [...items];
  final named = <String>[];
  for (final key in order) {
    if (rest.remove(key)) named.add(key);
  }
  return [...named, ...rest];
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

/// The tiles of the home screen's delay block: the delay is asked to these.
final homeSitesProvider = Provider<List<LatencySite>>(
  (ref) => homeSitesFor(
    android: PlatformUtils.isAndroid,
    apps: orderedKeys(ref.watch(ConfigOptions.siteGroupApps), ref.watch(Preferences.appsOrder)),
    saved: ref.watch(Preferences.homeApps),
    testUrl: ref.watch(ConfigOptions.connectionTestUrl),
  ),
);

/// The server each site goes through when each has its own (Settings → Ping → Sites, beta): the site's key → the
/// server's tag, read from the core's site groups ("site-<key>"); empty when that's off.
final siteServersProvider = StreamProvider<Map<String, String>>((ref) {
  // on for either network: the core has the groups only on the one it's on, so the map is empty on the other
  final on =
      ref.watch(ConfigOptions.siteGroups) ||
      ref.watch(ConfigOptions.siteGroupsMobile) ||
      ref.watch(ConfigOptions.aiGroupWifi) ||
      ref.watch(ConfigOptions.aiGroupMobile);
  if (!on || !ref.watch(serviceRunningProvider)) return Stream.value(const {});
  return ref
      .watch(proxyRepositoryProvider)
      .watchActiveProxies()
      .map((event) => event.getOrElse((_) => const []))
      .map(siteServersOf);
});

/// The AI services that go through the core's AI group ("ai") instead of a group each.
const aiServiceKeys = ['chatgpt', 'claude', 'gemini', 'perplexity', 'deepseek'];

/// Each site's server from the core's groups: the service groups ("site-<key>") and, for the AI services, the AI group.
Map<String, String> siteServersOf(Iterable<OutboundGroup> groups) => {
  for (final group in groups)
    if (group.selected.isNotEmpty) ...{
      if (group.tag.startsWith('site-')) group.tag.substring(5): group.selected,
      if (group.tag == 'ai') for (final key in aiServiceKeys) key: group.selected,
    },
};

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
    final connected = ref.watch(tunnelUpProvider);
    if (connected && !_connected && !ref.watch(superLightProvider)) Future.microtask(test);
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

  bool _running = false;

  /// One round over every site, unless one runs or one ran a moment ago. [quiet]: a round nobody asked for (the timer's,
  /// the minute's refresh): the delay button doesn't light up and fill its ring, only the figures change.
  Future<void> test({bool quiet = false}) async {
    if (_running || state.testing || ref.read(superLightProvider)) return;
    if (state.at != null && DateTime.now().difference(state.at!) < const Duration(seconds: 3)) return;
    if (!ref.read(tunnelUpProvider)) return;
    if (!ref.read(ConfigOptions.enableMixedPort)) return;
    _running = true;
    if (!quiet) state = (ms: state.ms, at: state.at, testing: true, done: 0);
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
            if (!quiet) state = (ms: state.ms, at: state.at, testing: true, done: results.length);
          }(),
      ]);
    } finally {
      client.close(force: true);
      _running = false;
    }
    state = (ms: results, at: DateTime.now(), testing: false, done: shown.length);
  }
}

/// Each site's last delays, one per finished round (null: no answer), oldest first: what the sites' tiles draw as their
/// pulse. Kept while the app runs.
final siteHistoryProvider = NotifierProvider<SiteHistory, Map<String, List<int?>>>(SiteHistory.new);

class SiteHistory extends Notifier<Map<String, List<int?>>> {
  /// how many rounds are kept
  static const length = 30;

  DateTime? _last;

  @override
  Map<String, List<int?>> build() {
    ref.listen(siteLatencyProvider, (_, next) {
      // a round that has just finished
      if (next.testing || next.at == null || next.at == _last) return;
      _last = next.at;
      final grown = {for (final e in state.entries) e.key: List<int?>.of(e.value)};
      for (final e in next.ms.entries) {
        final list = grown.putIfAbsent(e.key, () => <int?>[]);
        list.add(e.value);
        if (list.length > length) list.removeAt(0);
      }
      state = grown;
    });
    return const {};
  }
}
