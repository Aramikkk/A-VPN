import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Device headers for subscription panels with a per-device limit (e.g. Remnawave HWID).
/// The id is random, created once per install, and sent only with subscription requests.
abstract class DeviceHeaders {
  /// The provider's panel answers in Clash format to this client name, its listed "Clash Meta" client.
  /// That answer carries the real "LTE Only" servers; the one for Hiddify's name has decoys in their place.
  static const subscriptionUserAgent = 'clash.meta';

  /// Other client names to try when the provider answers the first one with decoys (it doesn't know that client): the
  /// popular ones, in the order they are most often accepted.
  static const otherAgents = ['Happ/2.4.5', 'v2rayNG/1.9.30', 'Hiddify/2.5.7', 'sing-box/1.11.0', 'Streisand/1.7.0'];

  static const _agentsKey = 'subscription_agents';

  /// The client names to ask a provider ([host]) with, in order: the one that was accepted last time, then [first],
  /// then the others.
  static Future<List<String>> agentsFor(String host, String first) async {
    String? known;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_agentsKey);
      if (saved != null) known = (jsonDecode(saved) as Map<String, dynamic>)[host] as String?;
    } catch (_) {
      /* nothing remembered */
    }
    return [
      if (known != null) known,
      if (known != first) first,
      for (final agent in otherAgents)
        if (agent != known && agent != first) agent,
    ];
  }

  /// Keeps the client name a provider ([host]) accepted, to start with it next time.
  static Future<void> remember(String host, String agent) async {
    if (host.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> saved = {};
    try {
      saved = Map<String, dynamic>.from(jsonDecode(prefs.getString(_agentsKey) ?? '{}') as Map);
    } catch (_) {
      /* start again */
    }
    saved[host] = agent;
    await prefs.setString(_agentsKey, jsonEncode(saved));
  }

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
    return _cached = {'x-hwid': hwid, 'x-device-os': _osName(), 'x-device-model': 'A-VPN'};
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
