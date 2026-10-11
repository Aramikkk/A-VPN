/// What the app was started with, read once in main().
abstract class LaunchArgs {
  /// Started by the sign-in task (desktop): stay in the tray and connect.
  static bool atLogin = false;

  static void parse(List<String> args) {
    atLogin = args.contains('--autostart');
  }
}
