import 'dart:async';

import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/site_latency.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One refresh for everything the home screen shows, started together so none of it is older than the rest: the ping
/// (a probe through the tunnel at once, not at its next turn), the delays to the sites, and the servers' pings (the
/// list and the count of the ones answering). [read] is a `ref.read` (of a widget, or of a notifier).
Future<void> refreshHomeIndicators({required T Function<T>(ProviderListenable<T> provider) read, bool quiet = false}) async {
  read(connectionQualityProvider.notifier).probeNow();
  // (the super light mode has no site tiles: the notifier does nothing there)
  unawaited(read(siteLatencyProvider.notifier).test(quiet: quiet));
  await read(proxiesOverviewNotifierProvider.notifier).urlTest("select", quiet: quiet);
}
