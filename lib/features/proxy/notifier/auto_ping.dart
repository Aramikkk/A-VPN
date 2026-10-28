import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/notifier/home_refresh.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Pings every server when the app is opened (or comes back to the screen) and the last such ping was at least
/// [every] ago, so the list shows fresh pings without pressing "Ping". Settings → Launch and connection.
final autoPingProvider = Provider<AutoPing>((ref) {
  final auto = AutoPing(ref);
  ref.onDispose(auto.dispose);
  return auto;
});

class AutoPing {
  AutoPing(this._ref) {
    _lifecycle = AppLifecycleListener(onResume: _check);
    // the first opening: as soon as the VPN is up
    _ref.listen(connectionNotifierProvider, (_, next) {
      if (next.valueOrNull is Connected) _check();
    });
    _check();
    // the super light mode: the one check that is left, every half hour (the app opened or not)
    _timer = Timer.periodic(every, (_) => _periodic());
  }

  static const every = Duration(minutes: 30);

  final Ref _ref;
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  DateTime? _last;

  void _periodic() {
    if (!_ref.read(superLightProvider)) return;
    if (_ref.read(connectionNotifierProvider).valueOrNull is! Connected) return;
    _last = DateTime.now();
    unawaited(_ref.read(Preferences.lastAutoPing.notifier).update(_last!.millisecondsSinceEpoch));
    unawaited(() async {
      try {
        await refreshHomeIndicators(read: _ref.read, quiet: true);
      } catch (_) {
        // the list isn't there: the next half hour tries again
      }
    }());
  }

  void _check() {
    if (!_ref.read(Preferences.autoPingOnOpen)) return;
    if (_ref.read(connectionNotifierProvider).valueOrNull is! Connected) return;
    final now = DateTime.now();
    final last = _last ?? DateTime.fromMillisecondsSinceEpoch(_ref.read(Preferences.lastAutoPing));
    if (now.difference(last) < every) return;
    _last = now;
    unawaited(_ref.read(Preferences.lastAutoPing.notifier).update(now.millisecondsSinceEpoch));
    // a moment for the core's server list after connecting
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        await refreshHomeIndicators(read: _ref.read, quiet: true);
      } catch (_) {
        // the list isn't there yet: the next opening tries again
        _last = null;
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
  }
}
