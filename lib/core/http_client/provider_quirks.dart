import 'package:shared_preferences/shared_preferences.dart';

/// Special handling of one subscription provider (Sigma Gate): its "Доступ" servers shown as "Sigma", and its panel
/// asked as the "clash.meta" client, which is the only one that gets the real "LTE Only" servers. It is off by default:
/// for any other provider the app behaves like a plain client. Settings → General switches it.
abstract class ProviderQuirks {
  static const prefsKey = 'provider_sigma';

  /// Mirrors the setting for the plain functions (names, headers) that have no `ref`.
  static bool sigma = false;

  /// Reads the saved setting at start.
  static Future<void> load() async {
    try {
      sigma = (await SharedPreferences.getInstance()).getBool(prefsKey) ?? false;
    } catch (_) {
      sigma = false;
    }
  }
}
