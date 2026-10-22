import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/country_scan.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show sigmaName;
import 'package:hiddify/features/profile/data/country_ping.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_merge.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings / Profile management: for each profile the countries its servers are in, each with its ping, and which of
/// them are open to the pings and to use: separately on Wi-Fi and on mobile data. A country left out has its servers
/// out of the auto groups. The countries are asked as the profile is opened.
class ProfileManagementPage extends HookConsumerWidget {
  const ProfileManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final profiles = ref.watch(profilesNotifierProvider).valueOrNull ?? const <ProfileEntity>[];
    final changed = useState(false);
    // Wi-Fi and LTE are two lists: one is shown, the other is a tap away
    final network = useState('wifi');
    final connected = ref.watch(connectionNotifierProvider).valueOrNull is Connected;

    Future<void> apply() async {
      changed.value = false;
      final active = await ref.read(activeProfileProvider.future);
      if (active != null) await ref.read(connectionNotifierProvider.notifier).reconnect(active);
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.profileManagement)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              t.avpn.profileManagementHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'wifi', icon: Icon(Icons.wifi_rounded), label: Text('Wi‑Fi')),
                ButtonSegment(value: 'mobile', icon: Icon(Icons.signal_cellular_alt_rounded), label: Text('LTE')),
              ],
              selected: {network.value},
              onSelectionChanged: (value) => network.value = value.first,
            ),
          ),
          const Gap(12),
          if (profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.avpn.profileManagementNone)),
            ),
          for (final profile in profiles)
            _ProfileCountries(profile: profile, network: network.value, onChanged: () => changed.value = true),
          if (changed.value && connected) ...[
            const Gap(8),
            FilledButton.icon(
              onPressed: apply,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.avpn.profileManagementApply),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCountries extends HookConsumerWidget {
  const _ProfileCountries({required this.profile, required this.network, required this.onChanged});

  final ProfileEntity profile;

  /// the list shown: 'wifi' or 'mobile'
  final String network;
  final VoidCallback onChanged;

  static const _good = Color(0xFF7CC43A);
  static const _slow = Color(0xFFF0B429);
  static const _bad = Color(0xFFE5483B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final off = ref.watch(Preferences.profileCountriesOff)[profile.id] ?? const {};
    // the countries outside the region filter that were switched on by hand
    final handOn = ref.watch(Preferences.profileCountriesOn)[profile.id] ?? const {};
    // the countries of the profile (with the number of servers) and what the ping says so far
    final servers = useState<List<({String code, String host, int port})>?>(null);
    final pings = useState<Map<String, int?>>(const {});
    final started = useRef(false);

    Future<void> load() async {
      if (started.value) return;
      started.value = true;
      final found = await CountryPing.serversOfFile(ref.read(profilePathResolverProvider).file(profile.id).path);
      if (!context.mounted) return;
      servers.value = found;
      // what is there now: the next update is compared with it
      final seen = ref.read(Preferences.profileCountriesSeen);
      if (!seen.containsKey(profile.id) && found.isNotEmpty) {
        await ref.read(Preferences.profileCountriesSeen.notifier).update({
          ...seen,
          profile.id: {for (final server in found) server.code}.toList(),
        });
      }
      CountryPing.measure(found).listen((result) {
        if (context.mounted) pings.value = {...pings.value, result.$1: result.$2};
      });
    }

    // the active profile is open at once, and asked at once; the others when opened
    useEffect(() {
      if (profile.active) unawaited(load());
      return null;
    }, const []);

    final counts = <String, int>{};
    for (final server in servers.value ?? <({String code, String host, int port})>[]) {
      counts[server.code] = (counts[server.code] ?? 0) + 1;
    }
    final codes = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    // the region filter (Servers → Europe only, World and CIS) works on top: a country outside it is never used
    final cisOnly = ref.watch(ConfigOptions.cisOnlyServers);
    final europeOnly = !cisOnly && ref.watch(ConfigOptions.europeOnlyServers);
    bool inFilter(String key) =>
        CountryScan.allowedByFilter(ProfileMerge.codeOf(key), europeOnly: europeOnly, cisOnly: cisOnly);

    // a country outside the filter: switched on by hand (the choice wins over the filter) or off again
    Future<void> toggleOutside(String network, String code, bool on) async {
      final all = {...ref.read(Preferences.profileCountriesOn)};
      final mine = {
        for (final e in (all[profile.id] ?? const <String, List<String>>{}).entries) e.key: [...e.value],
      };
      final list = {...?mine[network]};
      if (on) {
        list.add(code);
      } else {
        list.remove(code);
      }
      if (list.isEmpty) {
        mine.remove(network);
      } else {
        mine[network] = list.toList();
      }
      if (mine.isEmpty) {
        all.remove(profile.id);
      } else {
        all[profile.id] = mine;
      }
      await ref.read(Preferences.profileCountriesOn.notifier).update(all);
      onChanged();
    }

    Future<void> toggle(String network, String code, bool on) async {
      final all = {...ref.read(Preferences.profileCountriesOff)};
      final mine = {
        for (final e in (all[profile.id] ?? const <String, List<String>>{}).entries) e.key: [...e.value],
      };
      final list = {...?mine[network]};
      if (on) {
        list.remove(code);
      } else {
        list.add(code);
      }
      if (list.isEmpty) {
        mine.remove(network);
      } else {
        mine[network] = list.toList();
      }
      if (mine.isEmpty) {
        all.remove(profile.id);
      } else {
        all[profile.id] = mine;
      }
      await ref.read(Preferences.profileCountriesOff.notifier).update(all);
      onChanged();
    }

    String summary(String network) {
      if (servers.value == null) return off[network]?.isEmpty ?? true ? t.avpn.profileCountriesAll : '…';
      final shown = codes.where((key) => network == 'mobile' || !ProfileMerge.isWhitelist(key)).toList();
      bool open(String key) =>
          inFilter(key) ? !(off[network]?.contains(key) ?? false) : (handOn[network]?.contains(key) ?? false);
      final count = shown.where(open).length;
      return count == shown.length ? t.avpn.profileCountriesAll : '$count/${shown.length}';
    }

    // a cell of a column: the whole width of the cell, the label centred in it (a chip would be as wide as its text and
    // the edges of the cells would not line up)
    Widget chip(String network, String code) {
      // in the filter: on unless switched off; outside it: off unless switched on by hand
      final selected = inFilter(code)
          ? !(off[network]?.contains(code) ?? false)
          : (handOn[network]?.contains(code) ?? false);
      final ping = pings.value[code];
      final known = pings.value.containsKey(code);
      return Opacity(
        // outside the region filter: dim until it is switched on by hand
        opacity: selected || inFilter(code) ? 1 : .5,
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : scheme.outlineVariant)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => inFilter(code) ? toggle(network, code, !selected) : toggleOutside(network, code, !selected),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
                      ),
                      children: [
                        // the flag in its own run: the emoji font is its fallback only, the name keeps the theme's fonts
                        TextSpan(
                          text: ProfileMerge.flag(code),
                          style: const TextStyle(fontFamilyFallback: ['Emoji']),
                        ),
                        TextSpan(
                          text: ' ${ProfileMerge.countryName(code)}${ProfileMerge.isWhitelist(code) ? ' БС' : ''} ',
                        ),
                        TextSpan(
                          text: known ? (ping == null ? '—' : '$ping ms') : '…',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: !known || (ping == null && ProfileMerge.isWhitelist(code))
                                ? scheme.onSurfaceVariant
                                : ping == null
                                ? _bad
                                : ping < 150
                                ? _good
                                : ping < 300
                                ? _slow
                                : _bad,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget group(String title, String network, List<String> keys) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        // two even columns: every cell is half the width
        LayoutBuilder(
          builder: (context, box) {
            final cell = (box.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [for (final key in keys) SizedBox(width: cell, child: chip(network, key))],
            );
          },
        ),
      ],
    );

    // the whitelist servers (LTE Only, БС) and the ordinary ones are two lists of countries: on Wi-Fi only the ordinary
    // ones work; on mobile data the whitelist ones do, the ordinary ones are what is left when none of them is open
    final whitelist = [
      for (final key in codes)
        if (ProfileMerge.isWhitelist(key)) key,
    ];
    final ordinary = [
      for (final key in codes)
        if (!ProfileMerge.isWhitelist(key)) key,
    ];
    List<Widget> lists(String network) => network == 'wifi'
        ? [if (ordinary.isNotEmpty) group(t.avpn.profileManagementOrdinary, network, ordinary)]
        : [
            if (whitelist.isNotEmpty) group(t.avpn.profileManagementWhitelist, network, whitelist),
            if (ordinary.isNotEmpty) group(t.avpn.profileManagementOrdinaryReserve, network, ordinary),
          ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: profile.active,
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (open) {
          if (open) unawaited(load());
        },
        title: Text(
          profile.active
              ? '${sigmaName(profile.name)}  ·  ${t.avpn.profileManagementActive}'
              : sigmaName(profile.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          'Wi‑Fi: ${summary('wifi')}  ·  LTE: ${summary('mobile')}',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (servers.value == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (codes.isEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text(t.avpn.profileManagementNoCountries))
          else ...[
            ...lists(network),
          ],
        ],
      ),
    );
  }
}
