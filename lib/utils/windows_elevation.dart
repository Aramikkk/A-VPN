import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Windows refused the VPN mode's adapter in this run ("Access is denied": no administrator's rights, where its
/// driver wants them): the system proxy instead until the app is closed. Some computers let the adapter up without
/// the rights, so it's tried first rather than guessed from the rights.
final tunDeniedProvider = StateProvider<bool>((ref) => false);

/// The core's error for an adapter Windows wouldn't set up.
bool isTunDenied(Object error) {
  final text = error.toString().toLowerCase();
  return Platform.isWindows &&
      text.contains('tun') &&
      (text.contains('access is denied') || text.contains('отказано в доступе'));
}

abstract class WindowsElevation {
  /// Starts the app again with the administrator's rights (Windows asks) once this one has closed: a second copy
  /// started while it runs would only bring this one's window up. Then the caller closes the app.
  static Future<bool> relaunchElevated() async {
    try {
      final exe = Platform.resolvedExecutable.replaceAll("'", "''");
      await Process.start('powershell', [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-Command',
        "Wait-Process -Id $pid -ErrorAction SilentlyContinue; Start-Process -FilePath '$exe' -Verb RunAs",
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }
}
