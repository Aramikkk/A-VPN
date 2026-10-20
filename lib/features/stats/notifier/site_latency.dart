import 'dart:async';
import 'dart:io';

import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
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
  // Yandex goes direct by the routing rules: the plain internet's delay, beside the VPN's to the others
  (key: 'yandex', name: 'Яндекс', letter: 'Я', url: 'http://ya.ru/', get: false),
];

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
    try {
      await Future.wait([
        for (final site in latencySites)
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
    state = (ms: results, at: DateTime.now(), testing: false, done: latencySites.length);
  }
}
