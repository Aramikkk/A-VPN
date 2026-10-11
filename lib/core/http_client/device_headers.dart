import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Device headers for subscription panels with a per-device limit (e.g. Remnawave HWID).
/// The id is random, created once per install, and sent only with subscription requests.
abstract class DeviceHeaders {
  /// The provider's panel answers in Clash format to this client name, its listed "Clash Meta" client.
  /// That answer carries the real "LTE Only" servers; the one for Hiddify's name has decoys in their place.
  static const subscriptionUserAgent = 'clash.meta';

  static const _prefsKey = 'subscription_hwid';
  static Map<String, String>? _cached;

  static Future<Map<String, String>> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var hwid = prefs.getString(_prefsKey);
    if (hwid == null || hwid.isEmpty) {
      hwid = const Uuid().v4().replaceAll('-', '');
      await prefs.setString(_prefsKey, hwid);
    }
    return _cached = {
      'x-hwid': hwid,
      'x-device-os': _osName(),
      'x-device-model': 'A-VPN',
    };
  }

  static String _osName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }
}
