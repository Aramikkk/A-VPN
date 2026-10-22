import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:path/path.dart' as p;

/// What the profiles give the core: several subscriptions at once, and the countries of each that are left out.
///
/// The servers of the extra profiles are added to the active profile's config, so the core's groups (Auto, the sites'
/// own servers) choose among all of them. The active profile gives everything else (rules, DNS, the groups'
/// settings); an extra one only its servers. A country switched off for a profile (Settings → Profile management)
/// leaves that profile's servers out of the groups: not pinged, not used.
abstract class ProfileMerge {
  static final _logger = infraLogger('ProfileMerge');

  /// The first extra profile's servers are numbered from here, the second's from twice that: the tags keep the
  /// provider's own `§ N` ending, which the app cuts off in the lists, so the names show as they were.
  static const _step = 1000;

  static const _hideMark = ' §hide§';

  static final _ending = RegExp(r'^(.*?)\s*§\s*(\d+)\s*$');

  static const _groups = ['selector', 'urltest', 'balancer', 'direct', 'block', 'dns'];

  /// A profile's id: its config file's name.
  static String idOf(String path) => p.basenameWithoutExtension(path);

  /// The config to start with: [primary] alone when there are no [extras] and no country is left out, else a copy of
  /// it, kept next to it as `.merged-[name].json`. [extras] are config files, in the order they were added;
  /// [hidden] gives a profile's (by id) countries switched off.
  static Future<String> apply(
    String primary,
    List<String> extras, {
    required String name,
    Set<String> Function(String profileId)? hidden,
  }) async {
    final hide = hidden ?? (_) => const <String>{};
    final nothingHidden = hide(idOf(primary)).isEmpty && extras.every((path) => hide(idOf(path)).isEmpty);
    if (extras.isEmpty && nothingHidden) return primary;
    try {
      final merged = merge(
        jsonDecode(await File(primary).readAsString()) as Map<String, dynamic>,
        [
          for (final path in extras)
            if (await File(path).exists()) jsonDecode(await File(path).readAsString()) as Map<String, dynamic>,
        ],
        primaryHidden: hide(idOf(primary)),
        extrasHidden: [
          for (final path in extras)
            if (File(path).existsSync()) hide(idOf(path)),
        ],
      );
      if (merged == null) return primary;
      final out = File('$primary.merged-$name.json');
      await out.writeAsString(jsonEncode(merged));
      return out.path;
    } catch (e, st) {
      _logger.warning('could not prepare the profiles, using the active one as it is', e, st);
      return primary;
    }
  }

  /// [primary] with the servers of [extras] added, and the servers of the countries in [primaryHidden] (and, for each
  /// of the extras, in [extrasHidden]) left out; null when that changes nothing.
  static Map<String, dynamic>? merge(
    Map<String, dynamic> primary,
    List<Map<String, dynamic>> extras, {
    Set<String> primaryHidden = const {},
    List<Set<String>> extrasHidden = const [],
  }) {
    var changed = false;
    // the active profile's servers of the countries switched off: marked, as the region filter does (the core leaves
    // them out of its groups). Never all of them, though: a profile with nothing left is no profile.
    final hidden = _hiding(primary, primaryHidden);
    if (hidden.isNotEmpty) {
      for (final key in ['outbounds', 'endpoints']) {
        for (final item in _items(primary, key)) {
          for (final field in ['tag', 'detour']) {
            final value = item[field];
            if (value is String && hidden.containsKey(value)) item[field] = hidden[value];
          }
        }
      }
      changed = true;
    }
    final taken = <String>{};
    final known = <String>{};
    for (final key in ['outbounds', 'endpoints']) {
      for (final item in _items(primary, key)) {
        final tag = item['tag'];
        if (tag is String) taken.add(tag);
        if (!_isGroup(item)) known.add(_identity(item));
      }
    }
    var added = 0;
    for (final (i, extra) in extras.indexed) {
      final offset = _step * (i + 1);
      final off = i < extrasHidden.length ? _usable(extra, extrasHidden[i]) : const <String>{};
      // the servers of this profile and what they are renamed to
      final names = <String, String>{};
      var counter = 0;
      for (final key in ['outbounds', 'endpoints']) {
        for (final item in _items(extra, key)) {
          final tag = item['tag'];
          if (tag is! String || tag.contains('§hide§') || _isGroup(item) || _isPlaceholder(item)) continue;
          if (off.contains(ServerRegionFilter.serverKey(tag))) continue;
          // the same server in both subscriptions: once
          if (!known.add(_identity(item))) continue;
          final match = _ending.firstMatch(tag);
          var name = match == null
              ? '$tag § ${offset + ++counter}'
              : '${match.group(1)} § ${int.parse(match.group(2)!) + offset}';
          while (!taken.add(name)) {
            name = '$name ';
          }
          names[tag] = name;
        }
      }
      for (final key in ['outbounds', 'endpoints']) {
        final into = (primary[key] as List?) ?? <dynamic>[];
        for (final item in _items(extra, key)) {
          final tag = item['tag'];
          if (tag is! String || !names.containsKey(tag)) continue;
          final copy = Map<String, dynamic>.from(item);
          copy['tag'] = names[tag];
          // a server behind another of this profile's: follows its new name
          final detour = copy['detour'];
          if (detour is String && names.containsKey(detour)) copy['detour'] = names[detour];
          into.add(copy);
          added++;
        }
        if (into.isNotEmpty) primary[key] = into;
      }
    }
    if (added > 0) _logger.info('added $added servers of ${extras.length} more profiles');
    return added == 0 && !changed ? null : primary;
  }

  /// The countries of [config]'s servers: the ISO code and how many servers each has, the most first.
  static List<(String, int)> countries(Map<String, dynamic> config) {
    final counts = <String, int>{};
    for (final key in ['outbounds', 'endpoints']) {
      for (final item in _items(config, key)) {
        final tag = item['tag'];
        if (tag is! String || tag.contains('§hide§') || _isGroup(item) || _isPlaceholder(item)) continue;
        final code = ServerRegionFilter.serverKey(tag);
        if (code != null) counts[code] = (counts[code] ?? 0) + 1;
      }
    }
    return counts.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// The countries of a profile's config file.
  static Future<List<(String, int)>> countriesOf(String path) async {
    try {
      return countries(jsonDecode(await File(path).readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const [];
    }
  }

  /// Whether a list key is for a country's whitelist servers ("SE:bs").
  static bool isWhitelist(String key) => key.endsWith(':bs');

  /// The country code of a list key ("SE:bs" → "SE").
  static String codeOf(String key) => key.split(':').first;

  /// Russian name of a country by its code or list key, for the lists ("SE" → "Швеция"); the code itself when it is
  /// not known.
  static String countryName(String key) {
    final code = codeOf(key);
    for (final entry in ServerRegionFilter.countryNames.entries) {
      if (entry.value == code && RegExp('[а-я]').hasMatch(entry.key)) {
        return entry.key[0].toUpperCase() + entry.key.substring(1);
      }
    }
    return code;
  }

  /// The flag emoji of a country code (or of a list key).
  static String flag(String key) => String.fromCharCodes([for (final c in codeOf(key).codeUnits) 0x1F1E6 + c - 0x41]);

  /// Which of [off] to really leave out of [config]: all of them, unless that would be every server (then none).
  static Set<String> _usable(Map<String, dynamic> config, Set<String> off) {
    if (off.isEmpty) return off;
    final all = {for (final (code, _) in countries(config)) code};
    return all.difference(off).isEmpty ? const {} : off;
  }

  /// The tags of [config]'s servers in the countries [off] (as far as that leaves some), and what to rename them to.
  static Map<String, String> _hiding(Map<String, dynamic> config, Set<String> off) {
    final use = _usable(config, off);
    if (use.isEmpty) return const {};
    final renamed = <String, String>{};
    for (final key in ['outbounds', 'endpoints']) {
      for (final item in _items(config, key)) {
        final tag = item['tag'];
        if (tag is! String || tag.contains('§hide§') || _isGroup(item) || _isPlaceholder(item)) continue;
        if (use.contains(ServerRegionFilter.serverKey(tag))) renamed[tag] = '$tag$_hideMark';
      }
    }
    return renamed;
  }

  static Iterable<Map<String, dynamic>> _items(Map<String, dynamic> config, String key) =>
      ((config[key] as List?) ?? const []).whereType<Map<String, dynamic>>();

  static bool _isGroup(Map<String, dynamic> outbound) => _groups.contains(outbound['type']);

  /// The provider answers an unrecognised client with dummy servers (0.0.0.0:1, a parked domain): not worth adding.
  static bool _isPlaceholder(Map<String, dynamic> outbound) {
    final server = outbound['server'];
    final port = outbound['server_port'];
    return server == '0.0.0.0' || server == 'siski.com' || (port is int && port < 2);
  }

  /// What makes a server the same one in two subscriptions: its kind, address, port and key.
  static String _identity(Map<String, dynamic> outbound) =>
      '${outbound['type']}|${outbound['server']}|${outbound['server_port']}|'
      '${outbound['uuid'] ?? outbound['password'] ?? outbound['private_key'] ?? ''}';
}
