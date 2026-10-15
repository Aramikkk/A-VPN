import 'dart:io';

/// Whether the app runs with the administrator's rights on Windows, where the VPN mode (a TUN adapter) needs them;
/// true elsewhere. Read once when the app starts.
abstract class WindowsElevation {
  static bool elevated = true;

  static Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      // the high mandatory level is the elevated token's
      final result = await Process.run('whoami', ['/groups']);
      elevated = result.exitCode != 0 || (result.stdout as String).contains('S-1-16-12288');
    } catch (_) {
      elevated = true;
    }
  }

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
