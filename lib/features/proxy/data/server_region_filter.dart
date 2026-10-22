import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hiddify/utils/custom_loggers.dart';

/// Keeps only European servers in the server list and in the core's auto groups ("lowest", "balance").
///
/// The core leaves every outbound whose tag contains "§hide§" out of its groups and the selector, so the
/// filter writes a copy of the parsed config with that mark on every other server. The provider's
/// "LTE Only" servers are filtered the same way.
abstract class ServerRegionFilter {
  static const _hideMark = ' §hide§';

  /// ISO 3166 codes treated as Europe. Russia, Belarus, Turkey and the Caucasus are not in it.
  static const europe = {
    'AD', 'AL', 'AT', 'BA', 'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'GR', //
    'HR', 'HU', 'IE', 'IS', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MD', 'ME', 'MK', 'MT', 'NL', 'NO', 'PL', //
    'PT', 'RO', 'RS', 'SE', 'SI', 'SK', 'SM', 'UA', 'VA', 'XK',
  };

  /// "World and CIS": every country of the subscription but Russia and Belarus, the regular servers and the
  /// whitelist ones alike (a mobile network still switches to the whitelist servers). A server whose country
  /// can't be told stays.
  static bool keepCis(String tag) {
    final code = countryCode(tag);
    return code != 'RU' && code != 'BY';
  }

  /// For names without a flag: country name (lower case, Russian or English) to ISO code.
  static const _names = {
    'россия': 'RU',
    'russia': 'RU',
    'беларусь': 'BY',
    'belarus': 'BY',
    'казахстан': 'KZ',
    'kazakhstan': 'KZ',
    'узбекистан': 'UZ',
    'uzbekistan': 'UZ',
    'армения': 'AM',
    'armenia': 'AM',
    'грузия': 'GE',
    'georgia': 'GE',
    'турция': 'TR',
    'turkey': 'TR',
    'израиль': 'IL',
    'israel': 'IL',
    'сша': 'US',
    'usa': 'US',
    'сингапур': 'SG',
    'singapore': 'SG',
    'корея': 'KR',
    'korea': 'KR',
    'гонконг': 'HK',
    'hong kong': 'HK',
    'япония': 'JP',
    'japan': 'JP',
    'канада': 'CA',
    'canada': 'CA',
    'оаэ': 'AE',
    'uae': 'AE',
    'германия': 'DE',
    'germany': 'DE',
    'нидерланды': 'NL',
    'netherlands': 'NL',
    'финляндия': 'FI',
    'finland': 'FI',
    'швеция': 'SE',
    'sweden': 'SE',
    'польша': 'PL',
    'poland': 'PL',
    'франция': 'FR',
    'france': 'FR',
    'великобритания': 'GB',
    'united kingdom': 'GB',
    'латвия': 'LV',
    'latvia': 'LV',
    'литва': 'LT',
    'lithuania': 'LT',
    'эстония': 'EE',
    'estonia': 'EE',
    'чехия': 'CZ',
    'czech': 'CZ',
    'австрия': 'AT',
    'austria': 'AT',
    'швейцария': 'CH',
    'switzerland': 'CH',
    'норвегия': 'NO',
    'norway': 'NO',
    'дания': 'DK',
    'denmark': 'DK',
    'бельгия': 'BE',
    'belgium': 'BE',
    'италия': 'IT',
    'italy': 'IT',
    'испания': 'ES',
    'spain': 'ES',
    'португалия': 'PT',
    'portugal': 'PT',
    'румыния': 'RO',
    'romania': 'RO',
    'болгария': 'BG',
    'bulgaria': 'BG',
    'венгрия': 'HU',
    'hungary': 'HU',
    'словакия': 'SK',
    'slovakia': 'SK',
    'сербия': 'RS',
    'serbia': 'RS',
    'хорватия': 'HR',
    'croatia': 'HR',
    'греция': 'GR',
    'greece': 'GR',
    'македония': 'MK',
    'macedonia': 'MK',
    'молдова': 'MD',
    'азербайджан': 'AZ',
    'azerbaijan': 'AZ',
    'киргизия': 'KG',
    'кыргызстан': 'KG',
    'kyrgyzstan': 'KG',
    'таджикистан': 'TJ',
    'tajikistan': 'TJ',
    'туркменистан': 'TM',
    'turkmenistan': 'TM',
    'moldova': 'MD',
    'украина': 'UA',
    'ukraine': 'UA',
    'ирландия': 'IE',
    'ireland': 'IE',
    'исландия': 'IS',
    'iceland': 'IS',
  };

  /// The country names the filter knows (lower case, Russian and English) and their ISO codes.
  static Map<String, String> get countryNames => _names;

  static final _logger = infraLogger('ServerRegionFilter');

  /// Whether a server stays. A server whose country can't be told stays too, so the filter never
  /// leaves the list empty because of a naming it doesn't know.
  static bool keep(String tag) {
    final code = countryCode(tag);
    return code == null || europe.contains(code);
  }

  /// What a server is chosen by in a profile's country lists: its country ("SE"), and for a whitelist server (LTE
  /// Only, БС, ...) the same with ":bs" ("SE:bs"), so the two kinds of a country are two choices. Null when the
  /// country can't be told.
  static String? serverKey(String tag) {
    final code = countryCode(tag);
    // Antarctica is the provider's flag for its "Автовыбор" entries: not a country with servers
    if (code == null || code == 'AQ') return null;
    return isMobileOnly(tag) ? '$code:bs' : code;
  }

  /// The country of a server from its flag emoji, else from a country name in it.
  static String? countryCode(String tag) {
    final runes = tag.runes.toList();
    for (var i = 0; i + 1 < runes.length; i++) {
      final a = runes[i] - 0x1F1E6;
      final b = runes[i + 1] - 0x1F1E6;
      if (a >= 0 && a < 26 && b >= 0 && b < 26) {
        return String.fromCharCodes([0x41 + a, 0x41 + b]);
      }
    }
    final lower = tag.toLowerCase();
    for (final entry in _names.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Servers the provider runs for mobile networks with whitelists ("LTE Only", "БС"). They answer only
  /// through a mobile operator, while the other servers pass a ping there yet drop real traffic.
  static bool isMobileOnly(String tag) => tag.contains('БС') || _mobileOnly.hasMatch(tag);

  /// What providers call such servers: "LTE", "LTE Only", "БС", "Белые списки", "Антиглушилка", "whitelist".
  static final _mobileOnly = RegExp(
    r'(^|[^\p{L}\d])(lte|бс)($|[^\p{L}\d])|белые\s+списки|белый\s+список|антиглушилк|white\s?list',
    caseSensitive: false,
    unicode: true,
  );

  static const _networkChannel = MethodChannel('com.aravpn.app/network');
  static const _networkEvents = EventChannel('com.aravpn.app/network/events');
  static final Stream<NetworkKind> _networkChanges = _networkEvents.receiveBroadcastStream().map((event) {
    return switch (event) {
      'wifi' => NetworkKind.wifi,
      'mobile' => NetworkKind.mobile,
      _ => NetworkKind.unknown,
    };
  });

  /// Emits the physical network beneath the VPN, independent of whether the app is foregrounded.
  static Stream<NetworkKind> get networkChanges => _networkChanges;

  /// The network the running config was filtered for; the app re-filters when the phone's network differs.
  /// Kept across the app's restarts: the VPN outlives the app, and an app opened again took "unknown" for a
  /// change and reconnected, dropping every connection (ChatGPT's answers cut off) each time it was opened.
  static NetworkKind get lastApplied => _lastApplied;
  static set lastApplied(NetworkKind value) {
    _lastApplied = value;
    SharedPreferences.getInstance().then((p) => p.setString(_lastKey, value.name)).ignore();
  }

  static NetworkKind _lastApplied = NetworkKind.unknown;
  static const _lastKey = 'aravpn-last-applied-network';

  /// The network the phone's service switched the running config to by itself (null: it doesn't switch, the app
  /// does). It does that with the app closed too, from the two variants the app leaves it; the app then only
  /// reads where it stands.
  static Future<NetworkKind?> serviceApplied() async {
    if (!Platform.isAndroid) return null;
    try {
      final kind = await _networkChannel.invokeMethod<String>('serviceAppliedNetwork');
      if (kind == null) return null;
      final applied = NetworkKind.values.firstWhere((k) => k.name == kind, orElse: () => NetworkKind.unknown);
      _lastApplied = applied;
      return applied;
    } catch (_) {
      return null;
    }
  }

  /// Whether a VPN is up on the phone now (Android; false elsewhere): A-VPN's own left running while Android
  /// unloaded the app, as a rule.
  static Future<bool> vpnActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _networkChannel.invokeMethod<bool>('vpnActive') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The configs for Wi-Fi and for mobile data, for the phone's service to switch between when the network
  /// changes (with the app closed too); empty paths: it leaves the switching to the app.
  static Future<void> leaveVariants({String wifi = '', String mobile = ''}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aravpn-net-config-wifi', wifi);
      await prefs.setString('aravpn-net-config-mobile', mobile);
    } catch (e) {
      _logger.warning('could not leave the network variants', e);
    }
  }

  /// The network the running config was made for, as the app saved it before it was closed.
  static Future<NetworkKind> restoreLastApplied() async {
    if (_lastApplied != NetworkKind.unknown) return _lastApplied;
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_lastKey);
      _lastApplied = NetworkKind.values.firstWhere((k) => k.name == saved, orElse: () => NetworkKind.unknown);
    } catch (_) {
      // nothing saved: unknown
    }
    return _lastApplied;
  }

  /// The kind of network the phone uses right now, under the VPN.
  ///
  /// On Android this asks the platform about every non-VPN network: while the VPN runs, the active network
  /// is the VPN itself, and leaving Wi-Fi often shows up as just "VPN" with no mobile network under it.
  static Future<NetworkKind> currentNetwork() async {
    if (Platform.isAndroid) {
      try {
        final kind = await _networkChannel.invokeMethod<String>('underlyingNetwork');
        if (kind == 'wifi') return NetworkKind.wifi;
        if (kind == 'mobile') return NetworkKind.mobile;
      } catch (e) {
        _logger.warning('could not ask the platform for the network type', e);
      }
    }
    // a computer is on Wi-Fi or a cable: the "LTE Only" servers are for a phone's own mobile data
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return NetworkKind.wifi;
    try {
      final kinds = await Connectivity().checkConnectivity();
      if (kinds.contains(ConnectivityResult.wifi) || kinds.contains(ConnectivityResult.ethernet)) {
        return NetworkKind.wifi;
      }
      if (kinds.contains(ConnectivityResult.mobile)) return NetworkKind.mobile;
    } catch (e) {
      _logger.warning('could not tell the network type', e);
    }
    return NetworkKind.unknown;
  }

  /// Writes the filtered config next to [path] and returns its path, or [path] itself when nothing is hidden.
  ///
  /// Placeholders always go. With [europeOnly], servers outside Europe go; with [cisOnly], the ones [keepCis]
  /// doesn't keep. Then
  /// on a mobile [network] only the mobile-only servers stay, and on Wi-Fi they go. A step that would leave no
  /// server is skipped, so a connection always starts with something.
  static Future<String> apply(
    String path, {
    bool europeOnly = true,
    bool cisOnly = false,
    NetworkKind network = NetworkKind.unknown,
    // a variant made ahead for the other network (the phone switches to it by itself): not the one running
    bool remember = true,
  }) async {
    if (remember) lastApplied = network;
    try {
      final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final servers = <String, Map<String, dynamic>>{};
      for (final key in ['outbounds', 'endpoints']) {
        for (final item in (config[key] as List?) ?? const []) {
          if (item is! Map<String, dynamic>) continue;
          final tag = item['tag'];
          if (tag is! String || tag.contains('§hide§') || _isGroup(item)) continue;
          servers[tag] = item;
        }
      }
      var shown = servers.keys.where((tag) => !_isPlaceholder(servers[tag]!)).toList();
      List<String> narrow(List<String> current, bool Function(String) stays, String what) {
        final left = current.where(stays).toList();
        if (left.isEmpty) {
          _logger.warning('no $what server in the profile, skipping that filter');
          return current;
        }
        return left;
      }

      if (cisOnly) {
        shown = narrow(shown, keepCis, 'World and CIS');
      } else if (europeOnly) {
        shown = narrow(shown, keep, 'European');
      }
      if (network == NetworkKind.mobile) shown = narrow(shown, isMobileOnly, 'mobile-only');
      if (network == NetworkKind.wifi) shown = narrow(shown, (tag) => !isMobileOnly(tag), 'Wi-Fi');

      final kept = shown.toSet();
      final renamed = {
        for (final tag in servers.keys)
          if (!kept.contains(tag)) tag: '$tag$_hideMark',
      };
      if (renamed.isEmpty) return path;
      for (final key in ['outbounds', 'endpoints']) {
        for (final item in (config[key] as List?) ?? const []) {
          if (item is! Map<String, dynamic>) continue;
          for (final field in ['tag', 'detour']) {
            final value = item[field];
            if (value is String && renamed.containsKey(value)) item[field] = renamed[value];
          }
        }
      }
      final out = File(remember ? '$path.filtered.json' : '$path.filtered-${network.name}.json');
      await out.writeAsString(jsonEncode(config));
      _logger.info('network ${network.name}: hid ${renamed.length} servers, kept ${kept.length}');
      return out.path;
    } catch (e, st) {
      _logger.warning('could not filter servers, using every server', e, st);
      return path;
    }
  }

  /// Hosts the provider hands to clients it doesn't support in place of real servers (a parked domain).
  static const _decoyHosts = {'siski.com'};

  /// The provider answers an unrecognised client with dummy servers: "App not supported" at 0.0.0.0:1,
  /// or "БС" ones at a parked domain. Balancing onto them only produces errors.
  static bool _isPlaceholder(Map<String, dynamic> outbound) {
    final server = outbound['server'];
    final port = outbound['server_port'];
    return server == '0.0.0.0' || _decoyHosts.contains(server) || (port is int && port < 2);
  }

  static bool _isGroup(Map<String, dynamic> outbound) =>
      const ['selector', 'urltest', 'balancer', 'direct', 'block', 'dns'].contains(outbound['type']);
}

enum NetworkKind { wifi, mobile, unknown }
