import 'dart:io';

import 'package:hiddify/core/app_info/launch_args.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/model/startup_connection.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hiddify/utils/windows_elevation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'connection_notifier.g.dart';

@Riverpod(keepAlive: true)
class ConnectionNotifier extends _$ConnectionNotifier with AppLogger {
  @override
  Stream<ConnectionStatus> build() async* {
    if (Platform.isIOS) {
      await _connectionRepo.setup().mapLeft((l) {
        loggy.error("error setting up connection repository", l);
      }).run();
    }

    listenSelf((previous, next) async {
      if (previous == next) return;
      if (previous case AsyncData(:final value) when !value.isConnected) {
        if (next case AsyncData(value: final Connected _)) {
          if (Platform.isAndroid && !ref.read(Preferences.storeReviewedByUser)) {
            if (await InAppReview.instance.isAvailable()) {
              InAppReview.instance.requestReview();
              ref.read(Preferences.storeReviewedByUser.notifier).update(true);
            }
          }
        }
      }
    });

    ref.listen(activeProfileProvider.select((value) => value.asData?.value), (previous, next) async {
      if (previous == null) return;
      final shouldReconnect = next == null || previous.id != next.id;
      if (shouldReconnect) {
        await reconnect(next);
      }
    });
    ref.watch(coreRestartSignalProvider);

    yield* _connectionRepo.watchConnectionStatus().doOnData((event) {
      if (event case Disconnected(connectionFailure: final _?) when PlatformUtils.isDesktop) {
        Future.microtask(() => ref.read(Preferences.startedByUser.notifier).update(false));
      }
      // One call for every status buried failures at info, next to the ordinary
      // comings and goings. A failure carries the core's own panic text, which
      // is the last thing that should need hunting for.
      final status = "connection status: ${event.format()}";
      if (event case Disconnected(connectionFailure: final _?)) {
        loggy.error(status);
      } else {
        loggy.info(status);
      }
    });
  }

  ConnectionRepository get _connectionRepo => ref.read(connectionRepositoryProvider);

  Future<void> mayConnect() async {
    if (state case AsyncData(:final value)) {
      if (value case Disconnected()) return _connect();
    }
  }

  /// Restores the tunnel on desktop start when the user had it running before quitting,
  /// so a session started manually survives a reboot or an autostart login.
  Future<void> restoreConnectionOnStartup() async {
    final startedByUser = ref.read(Preferences.startedByUser);
    final activeProfile = await ref.read(activeProfileProvider.future);
    final shouldRestore = shouldRestoreConnectionOnStartup(
      isDesktop: PlatformUtils.isDesktop,
      // started by the sign-in task: A-VPN is there to connect
      startedByUser: startedByUser || LaunchArgs.atLogin,
      hasActiveProfile: activeProfile != null,
    );
    if (!shouldRestore) {
      loggy.debug("no previous connection to restore");
      return;
    }
    loggy.info("restoring previous connection on startup");
    await ref.read(Preferences.startedByUser.notifier).update(true);
    // the core may still be settling just after the app starts (or after an update): once more before a failure
    await _connect(retry: true);
  }

  /// Connects when the app opens if the user asked for it and nothing is running yet (the VPN may already be
  /// up, started at boot or from the quick-settings tile).
  Future<void> connectOnAppStart() async {
    if (!ref.read(Preferences.connectOnAppStart)) return;
    if (await ref.read(activeProfileProvider.future) == null) return;
    // The first status at start is always "disconnected", until the core answers a moment later. A VPN left
    // running while Android unloaded the app shows up then; connecting on that first status restarted it (the
    // VPN off for ~20 s on opening the app). So: the phone's own word first, then up to 2 s for the core's.
    if (await ServerRegionFilter.vpnActive()) {
      loggy.info("the VPN is already up: not connecting on app start");
      return;
    }
    for (var i = 0; i < 20; i++) {
      final status = state.valueOrNull;
      if (status is Connected || status is Connecting) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (await future case Disconnected()) {
      loggy.info("connecting on app start");
      await ref.read(Preferences.startedByUser.notifier).update(true);
      await _connect();
    }
  }

  Future<void> toggleConnection() async {
    final haptic = ref.read(hapticServiceProvider.notifier);
    if (state case AsyncError()) {
      await haptic.lightImpact();
      await _connect();
    } else if (state case AsyncData(:final value)) {
      switch (value) {
        case Disconnected():
          await haptic.lightImpact();
          await ref.read(Preferences.startedByUser.notifier).update(true);
          await _connect();
        case Connected():
          // default:
          await haptic.mediumImpact();
          await ref.read(Preferences.startedByUser.notifier).update(false);
          manualStopCount++;
          await _disconnect();
        default:
          loggy.warning("switching status, debounce");
      }
    }
  }

  /// [restart]: restart the core rather than hot reload it (LAN sharing switched: the proxy port changes, and the
  /// hot reload left the VPN dead once sharing was turned off)
  Future<void> reconnect(ProfileEntity? profile, {bool restart = false}) async {
    if (state case AsyncData(:final value) when value == const Connected()) {
      if (profile == null) {
        loggy.info("no active profile, disconnecting");
        return _disconnect();
      }
      loggy.info("active profile changed, reconnecting");
      await ref.read(Preferences.startedByUser.notifier).update(true);
      final result = await _connectionRepo
          .reconnect(profile, ref.read(Preferences.disableMemoryLimit), restart: restart)
          .run();
      await result.match<Future<void>>((err) async {
        loggy.warning("error reconnecting", err);
        state = AsyncError(err, StackTrace.current);
        await ref
            .read(dialogNotifierProvider.notifier)
            .showCustomAlertFromErr(err.present(ref.read(translationsProvider).requireValue));
      }, (_) async {});
    }
  }

  Future<void> abortConnection() async {
    if (state case AsyncData(:final value)) {
      switch (value) {
        case Connected() || Connecting():
          loggy.debug("aborting connection");
          await _disconnect();
        default:
      }
    }
  }

  final _singleStart = SingleCall();

  Future<void> _connect({bool retry = false}) async {
    await _singleStart.run(
      () async {
        await _connectThrottled(retry: retry);
      },
      onIgnored: () {
        loggy.debug("connect called while another connect/disconnect is still running, ignoring");
      },
    );
  }

  Future<void> _connectThrottled({bool retry = false}) async {
    final activeProfile = await ref.read(activeProfileProvider.future);
    if (activeProfile == null) {
      loggy.info("no active profile, not connecting");
      return;
    }
    final result = await _connectionRepo.connect(activeProfile, ref.read(Preferences.disableMemoryLimit)).run();
    await result.match<Future<void>>((ConnectionFailure err) async {
      // Windows wouldn't set the VPN mode's adapter up (no administrator's rights): once more on the system proxy
      if (!ref.read(tunDeniedProvider) && isTunDenied(err)) {
        loggy.warning("the VPN mode was refused (no administrator's rights): the system proxy instead", err);
        ref.read(tunDeniedProvider.notifier).state = true;
        await ref.read(Preferences.startedByUser.notifier).update(true);
        await _connectThrottled();
        return;
      }
      if (retry) {
        loggy.warning("error connecting, once more in 3 s: $err");
        await Future<void>.delayed(const Duration(seconds: 3));
        await _connectThrottled();
        return;
      }
      loggy.warning("error connecting: $err");
      //Go err is not normal object to see the go errors are string and need to be dumped
      await ref
          .read(dialogNotifierProvider.notifier)
          .showCustomAlertFromErr(err.present(ref.read(translationsProvider).requireValue));
      loggy.warning(err);
      if (err.toString().contains("panic")) {
        await Sentry.captureException(Exception(err.toString()));
      }
      await ref.read(Preferences.startedByUser.notifier).update(false);
      state = AsyncError(err, StackTrace.current);
    }, (_) async {});
  }

  Future<void> _disconnect() async {
    await _connectionRepo.disconnect().mapLeft((err) {
      loggy.warning("error disconnecting", err);
      ref
          .read(dialogNotifierProvider.notifier)
          .showCustomAlertFromErr(err.present(ref.read(translationsProvider).requireValue));
      state = AsyncError(err, StackTrace.current);
    }).run();
  }
}

@Riverpod(keepAlive: true)
bool serviceRunning(Ref ref) {
  // ref.watch(coreRestartSignalProvider);
  return ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
}

class SingleCall {
  bool _running = false;

  Future<T> run<T>(Future<T> Function() task, {required T onIgnored}) async {
    if (_running) return onIgnored;

    _running = true;
    try {
      return await task();
    } finally {
      _running = false;
    }
  }
}

/// Whether the core is hot reloading; only the connection button shows it.
final hotReloadingProvider = StreamProvider<bool>((ref) => ref.watch(connectionRepositoryProvider).watchHotReloading());
