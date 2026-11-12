import 'dart:async';

import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The connection status as the screen shows it: the real one, except that "disconnected" straight after
/// "connected" (no "disconnecting" between, no failure) waits 2 seconds before it shows. The core's link restarts
/// when the app comes back and says so for a moment, and the button, the gauge and the traffic card blinked; a real
/// stop goes through "disconnecting" and shows at once.
///
/// A VPN paused by the service (a home Wi-Fi, an app on screen) is shown as off: its tunnel is closed, nothing goes through
/// it, and the screen is the empty one of a VPN that is not on (a strip on the home screen says it is a pause).
final shownConnectionProvider = NotifierProvider<ShownConnection, ConnectionStatus>(ShownConnection.new);

class ShownConnection extends Notifier<ConnectionStatus> {
  Timer? _hold;

  @override
  ConnectionStatus build() {
    ref.onDispose(() => _hold?.cancel());
    // the pause begins or ends: the screen follows at once
    ref.listen(vpnPauseProvider, (_, pause) {
      final real = ref.read(connectionNotifierProvider).valueOrNull;
      if (real == null) return;
      _hold?.cancel();
      state = _shown(real, pause.paused);
    });
    ref.listen(connectionNotifierProvider, (_, next) {
      final status = next.valueOrNull;
      if (status == null) return; // loading: what was shown stays
      final paused = ref.read(vpnPauseProvider).paused;
      if (paused) {
        _hold?.cancel();
        state = _shown(status, true);
        return;
      }
      final blink = state is Connected && status is Disconnected && status.connectionFailure == null;
      _hold?.cancel();
      if (blink) {
        _hold = Timer(const Duration(seconds: 2), () {
          state = ref.read(connectionNotifierProvider).valueOrNull ?? const Disconnected();
        });
      } else {
        state = status;
      }
    });
    return _shown(ref.read(connectionNotifierProvider).valueOrNull ?? const Disconnected(), ref.read(vpnPauseProvider).paused);
  }

  /// [status] as the screen shows it: a connected VPN that is paused is off.
  static ConnectionStatus _shown(ConnectionStatus status, bool paused) =>
      paused && status is Connected ? const Disconnected() : status;
}
