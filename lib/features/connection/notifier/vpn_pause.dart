import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The VPN paused by the phone's service: the tunnel is closed (the home Wi-Fi's router already has a VPN, or an app the
/// user chose is on screen) while the service stays up and the core still says "started". The app has to know: there is
/// nothing to ask the core for then, and the home screen says "paused", not a lost connection.
typedef VpnPause = ({bool paused, bool home, String app});

const noVpnPause = (paused: false, home: false, app: '');

/// Whether the VPN is paused now, for the places that draw without watching [vpnPauseProvider] (the home screen
/// rebuilds when it changes, and they read this): the pings of a paused VPN are dashes, they do not change.
bool vpnPausedNow = false;

/// What the service says: "" (not paused), "home", or "app:" and the app's name.
VpnPause parseVpnPause(String? raw) {
  if (raw == null || raw.isEmpty) return noVpnPause;
  if (raw == 'home') return (paused: true, home: true, app: '');
  if (raw.startsWith('app:')) return (paused: true, home: false, app: raw.substring(4));
  return (paused: true, home: false, app: '');
}

/// Whether the tunnel is really open: connected and not paused. What reads the core (the servers, the pings, the
/// connections) goes by this, not by "connected" alone.
bool tunnelUp({required bool connected, required VpnPause pause}) => connected && !pause.paused;

/// The pause as the service has it now, asked every few seconds while the app runs (Android only).
final vpnPauseProvider = NotifierProvider<VpnPauseNotifier, VpnPause>(VpnPauseNotifier.new);

class VpnPauseNotifier extends Notifier<VpnPause> {
  static const _channel = MethodChannel('com.aravpn.app/tools');

  @override
  VpnPause build() {
    if (!Platform.isAndroid) return noVpnPause;
    final timer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(refresh()));
    ref.onDispose(timer.cancel);
    unawaited(refresh());
    return noVpnPause;
  }

  Future<void> refresh() async {
    try {
      final next = parseVpnPause(await _channel.invokeMethod<String>('pauseState'));
      vpnPausedNow = next.paused;
      if (next != state) state = next;
    } catch (_) {
      // an older service without the answer: never paused, as before
    }
  }
}

/// See [tunnelUp].
final tunnelUpProvider = Provider<bool>(
  (ref) => tunnelUp(
    connected: ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false,
    pause: ref.watch(vpnPauseProvider),
  ),
);

/// What the home screen says where the servers would be, when there are none to show: the pause and why, or (as always)
/// to connect.
String noServersText(TranslationsEn t, VpnPause pause) {
  if (!pause.paused) return t.avpn.connectToSeeServers;
  if (pause.home) return t.avpn.vpnPausedHome;
  if (pause.app.isNotEmpty) return t.avpn.vpnPausedApp(name: pause.app);
  return t.avpn.vpnPausedOther;
}
