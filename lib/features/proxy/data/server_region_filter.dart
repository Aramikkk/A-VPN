import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

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

  /// The CIS and its neighbours without Russia and Belarus: Armenia, Azerbaijan, Georgia, Kazakhstan,
  /// Kyrgyzstan, Moldova, Tajikistan, Turkmenistan, Uzbekistan.
  static const cis = {'AM', 'AZ', 'GE', 'KZ', 'KG', 'MD', 'TJ', 'TM', 'UZ'};

  /// Whether a server stays in CIS only: one of [cis]; a mobile-only (whitelist) one from anywhere but Russia
  /// and Belarus, so a mobile network still switches to the whitelist servers.
  static bool keepCis(String tag) {
    final code = countryCode(tag);
    return isMobileOnly(tag) ? code != 'RU' && code != 'BY' : cis.contains(code);
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

  static final _logger = infraLogger('ServerRegionFilter');

  /// Whether a server stays. A server whose country can't be told stays too, so the filter never
  /// leaves the list empty because of a naming it doesn't know.
  static bool keep(String tag) {
    final code = countryCode(tag);
    return code == null || europe.contains(code);
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
  static bool isMobileOnly(String tag) => tag.toLowerCase().contains('lte only') || tag.contains('БС');

  static const _networkChannel = MethodChannel('com.aravpn.app/network');

  /// The network the running config was filtered for; the app re-filters when the phone's network differs.
  static NetworkKind lastApplied = NetworkKind.unknown;

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
  }) async {
    lastApplied = network;
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
        shown = narrow(shown, keepCis, 'CIS');
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
      final out = File('$path.filtered.json');
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
