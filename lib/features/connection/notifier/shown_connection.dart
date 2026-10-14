import 'dart:async';

import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The connection status as the screen shows it: the real one, except that "disconnected" straight after
/// "connected" (no "disconnecting" between, no failure) waits 2 seconds before it shows. The core's link restarts
/// when the app comes back and says so for a moment, and the button, the gauge and the traffic card blinked; a real
/// stop goes through "disconnecting" and shows at once.
final shownConnectionProvider = NotifierProvider<ShownConnection, ConnectionStatus>(ShownConnection.new);

class ShownConnection extends Notifier<ConnectionStatus> {
  Timer? _hold;

  @override
  ConnectionStatus build() {
    ref.onDispose(() => _hold?.cancel());
    ref.listen(connectionNotifierProvider, (_, next) {
      final status = next.valueOrNull;
      if (status == null) return; // loading: what was shown stays
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
    return ref.read(connectionNotifierProvider).valueOrNull ?? const Disconnected();
  }
}
