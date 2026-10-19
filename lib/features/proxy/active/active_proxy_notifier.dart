import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/utils/throttler.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/data/proxy_repository.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/proxy/model/ip_info_entity.dart' as oldipinfo;
import 'package:hiddify/features/proxy/model/proxy_failure.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

import 'package:hiddify/utils/riverpod_utils.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'active_proxy_notifier.g.dart';

@riverpod
class IpInfoNotifier extends _$IpInfoNotifier with AppLogger {
  @override
  Future<oldipinfo.IpInfo> build() async {
    ref.disposeDelay(const Duration(seconds: 20));
    final cancelToken = CancelToken();
    Timer? timer;
    ref.onDispose(() {
      loggy.debug("disposing");
      cancelToken.cancel();
      timer?.cancel();
    });

    ref.listen(serviceRunningProvider, (_, next) => _idle = false);

    final autoCheck = ref.watch(Preferences.autoCheckIp);
    final serviceRunning = ref.watch(serviceRunningProvider);
    // loggy.debug(
    //   "idle? [$_idle], forced? [$_forceCheck], connected? [$serviceRunning]",
    // );
    if (!_forceCheck && !serviceRunning) {
      throw const ServiceNotRunning();
    } else if ((_idle && !_forceCheck) || (!_forceCheck && serviceRunning && !autoCheck)) {
      throw const UnknownIp();
    }

    _forceCheck = false;
    final info = await ref.watch(proxyRepositoryProvider).getCurrentIpInfo(cancelToken).getOrElse((err) {
      loggy.warning("error getting proxy ip info", err, StackTrace.current);
      // throw err; //hiddify: remove exception to be logged
      throw const UnknownIp();
    }).run();

    timer = Timer(const Duration(seconds: 10), () {
      loggy.debug("entering idle mode");
      _idle = true;
      ref.invalidateSelf();
    });

    return info;
  }

  bool _idle = false;
  bool _forceCheck = false;

  Future<void> refresh() async {
    if (state.isLoading) return;
    loggy.debug("refreshing");
    state = const AsyncLoading();
    await ref.read(hapticServiceProvider.notifier).lightImpact();
    _forceCheck = true;
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class ActiveProxyNotifier extends _$ActiveProxyNotifier with AppLogger {
  @override
  Stream<OutboundInfo> build() {
    // ref.disposeDelay(const Duration(seconds: 20));
    final serviceRunning = ref.watch(serviceRunningProvider);
    _wasConnectionValid = false;
    if (!serviceRunning) {
      return Stream.error(const ServiceNotRunning());
    }
    // Ping every server right after connecting so the auto group can pick the fastest one now,
    // instead of waiting for the first periodic url-test.
    final initialPing = Timer(const Duration(seconds: 2), () => _proxyRepo.urlTest("select").run());
    ref.onDispose(initialPing.cancel);
    // When the phone moves between Wi-Fi and mobile data, reload the config: the server filter keeps only the
    // "LTE Only" servers on mobile data and only the others on Wi-Fi. A ping can't tell this on its own:
    // with whitelists the other servers still answer a tiny test, then drop real traffic.
    // Re-filter when the phone's network no longer matches the one the running config was made for. Checked
    // a few seconds after a change event (a new network takes a moment to come up and be validated) and
    // every 15 seconds as a safety net, since the events don't always show the switch to mobile data.
    var switching = false;
    var uiNetwork = ServerRegionFilter.lastApplied;
    Future<void> refilterIfNetworkChanged() async {
      // the config follows the network when it picks servers by network, or when "only blocked through the VPN"
      // (Wi-Fi only on a phone) is on
      final follows =
          !PlatformUtils.isDesktop ||
          ref.read(ConfigOptions.serversByNetwork) ||
          (!PlatformUtils.isDesktop &&
              ref.read(ConfigOptions.blockedOnlyViaVpn) &&
              !ref.read(ConfigOptions.homeNetwork));
      if (switching || !follows) return;
      // the phone's VPN service switches the config itself when it was left the two variants. Refresh the
      // proxy list and pings after that switch so the foreground screen follows the config the service applied.
      final serviceNetwork = await ServerRegionFilter.serviceApplied();
      if (serviceNetwork != null) {
        if (serviceNetwork != uiNetwork) {
          uiNetwork = serviceNetwork;
          await _proxyRepo.urlTest("select").run();
          ref.invalidate(proxiesOverviewNotifierProvider);
        }
        return;
      }
      final network = await ServerRegionFilter.currentNetwork();
      if (network == NetworkKind.unknown) return;
      // the app was closed and opened again while the VPN ran on: the network its config was made for, as saved
      final applied = await ServerRegionFilter.restoreLastApplied();
      if (applied == NetworkKind.unknown) {
        // nothing saved (an update from before this was kept): take the network as it is rather than reconnect
        ServerRegionFilter.lastApplied = network;
        return;
      }
      if (network == applied) return;
      switching = true;
      try {
        loggy.info("network is now ${network.name}, was ${ServerRegionFilter.lastApplied.name}: reloading servers");
        final profile = await ref.read(activeProfileProvider.future);
        // a reload that hangs must not block every later network change
        await ref
            .read(connectionNotifierProvider.notifier)
            .reconnect(profile)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => loggy.warning("reload after the network change timed out, carrying on"),
            );
        await _proxyRepo.urlTest("select").run();
        uiNetwork = network;
        ref.invalidate(proxiesOverviewNotifierProvider);
      } finally {
        switching = false;
      }
    }

    final checks = <Timer>[];
    final networkChanges = ServerRegionFilter.networkChanges.skip(1).listen((_) {
      for (final timer in checks) {
        timer.cancel();
      }
      checks
        ..clear()
        ..add(Timer(const Duration(seconds: 3), refilterIfNetworkChanged))
        ..add(Timer(const Duration(seconds: 10), refilterIfNetworkChanged));
    });
    final safetyNet = Timer.periodic(const Duration(seconds: 15), (_) => refilterIfNetworkChanged());
    ref.onDispose(() {
      for (final timer in checks) {
        timer.cancel();
      }
      safetyNet.cancel();
      networkChanges.cancel();
    });
    return _proxyRepo
        .watchActiveProxies()
        .map((event) => event.getOrElse((l) => List<OutboundGroup>.empty()))
        .map((event) => event.firstOrNull?.items.first ?? OutboundInfo())
        .doOnData((info) => _handleConnectionHaptic(info.urlTestDelay));
  }

  ProxyRepository get _proxyRepo => ref.read(proxyRepositoryProvider);

  /// Whether the tunnel currently has a valid ping. Tracked so haptics fire only
  /// on real transitions (connect / timeout / recover), not on every ping update.
  bool _wasConnectionValid = false;

  void _handleConnectionHaptic(int urlTestDelay) {
    final isValid = ConnectionConst.isValidDelay(urlTestDelay);
    if (isValid == _wasConnectionValid) return;
    _wasConnectionValid = isValid;
    final haptic = ref.read(hapticServiceProvider.notifier);
    if (isValid) {
      // connected successfully, or recovered after a timeout
      haptic.heavyImpact();
    } else {
      // still connected but the ping timed out → medium then heavy
      haptic.mediumImpact();
      Future.delayed(const Duration(milliseconds: 150), haptic.heavyImpact);
    }
  }

  final _urlTestThrottler = Throttler(const Duration(seconds: 1));

  Future<void> urlTest(String? groupTag_) async {
    final groupTag = groupTag_ ?? "";
    _urlTestThrottler(() async {
      if (state case AsyncData()) {
        await ref.read(hapticServiceProvider.notifier).lightImpact();
        await ref.read(proxyRepositoryProvider).urlTest(groupTag).getOrElse((err) {
          loggy.warning("error testing group", err);
          throw err;
        }).run();
      }
    });
  }
}
