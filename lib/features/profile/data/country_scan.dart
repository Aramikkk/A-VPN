import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_merge.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Looks at the countries of a profile each time its subscription is updated: a country that has come in and fits the
/// region filter (Europe, or World and CIS) is open at once, on both networks, and the user is told.
abstract class CountryScan {
  /// Whether the region filter lets a country of [code] in: Europe only, World and CIS (everything but Russia and
  /// Belarus), or no filter.
  static bool allowedByFilter(String code, {required bool europeOnly, required bool cisOnly}) {
    if (cisOnly) return code != 'RU' && code != 'BY';
    if (europeOnly) return ServerRegionFilter.europe.contains(code);
    return true;
  }

  /// The profile's countries now, against the ones seen at the last look. Returns the ones that came in and fit the
  /// filter (already open: they are taken out of the lists of the countries switched off). The first look just
  /// remembers what is there.
  static Future<List<String>> afterUpdate(Ref ref, String profileId) async {
    final found = await ProfileMerge.countriesOf(ref.read(profilePathResolverProvider).file(profileId).path);
    final codes = [for (final (code, _) in found) code];
    if (codes.isEmpty) return const [];
    final seenAll = {...ref.read(Preferences.profileCountriesSeen)};
    final seen = seenAll[profileId];
    seenAll[profileId] = codes;
    await ref.read(Preferences.profileCountriesSeen.notifier).update(seenAll);
    if (seen == null) return const [];

    final cis = ref.read(ConfigOptions.cisOnlyServers);
    final europe = !cis && ref.read(ConfigOptions.europeOnlyServers);
    final fresh = [
      for (final key in codes)
        if (!seen.contains(key) && allowedByFilter(ProfileMerge.codeOf(key), europeOnly: europe, cisOnly: cis)) key,
    ];
    if (fresh.isEmpty) return const [];

    // open on both networks, even when the country was switched off before it went away
    final offAll = {...ref.read(Preferences.profileCountriesOff)};
    final mine = offAll[profileId];
    if (mine != null) {
      final updated = {
        for (final entry in mine.entries) entry.key: [...entry.value.where((code) => !fresh.contains(code))],
      }..removeWhere((_, list) => list.isEmpty);
      if (updated.isEmpty) {
        offAll.remove(profileId);
      } else {
        offAll[profileId] = updated;
      }
      await ref.read(Preferences.profileCountriesOff.notifier).update(offAll);
    }
    return fresh;
  }

  /// "🇯🇵 Япония, 🇨🇦 Канада" for the message to the user.
  static String describe(List<String> keys) => keys
      .map(
        (key) =>
            '${ProfileMerge.flag(key)} ${ProfileMerge.countryName(key)}${ProfileMerge.isWhitelist(key) ? ' БС' : ''}',
      )
      .join(', ');
}
