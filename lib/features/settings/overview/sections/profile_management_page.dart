import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/country_ping.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_merge.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
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
          if (profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.avpn.profileManagementNone)),
            ),
          for (final profile in profiles) _ProfileCountries(profile: profile, onChanged: () => changed.value = true),
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
  const _ProfileCountries({required this.profile, required this.onChanged});

  final ProfileEntity profile;
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
      final left = off[network]?.where(counts.containsKey).length ?? 0;
      if (servers.value == null) return off[network]?.isEmpty ?? true ? t.avpn.profileCountriesAll : '…';
      return left == 0 ? t.avpn.profileCountriesAll : '${codes.length - left}/${codes.length}';
    }

    Widget section(String title, String network) => Column(
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
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final code in codes)
              FilterChip(
                selected: !(off[network]?.contains(code) ?? false),
                showCheckmark: false,
                onSelected: (on) => toggle(network, code, on),
                label: Text.rich(
                  TextSpan(
                    children: [
                      // the flag in its own run: the emoji font is its fallback only, the name keeps the theme's fonts
                      TextSpan(
                        text: ProfileMerge.flag(code),
                        style: const TextStyle(fontFamilyFallback: ['Emoji']),
                      ),
                      TextSpan(text: ' ${ProfileMerge.countryName(code)} '),
                      TextSpan(
                        text: pings.value.containsKey(code)
                            ? (pings.value[code] == null ? '—' : '${pings.value[code]} ms')
                            : '…',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: !pings.value.containsKey(code)
                              ? scheme.onSurfaceVariant
                              : pings.value[code] == null
                              ? _bad
                              : pings.value[code]! < 150
                              ? _good
                              : pings.value[code]! < 300
                              ? _slow
                              : _bad,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );

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
          profile.active ? '${profile.name}  ·  ${t.avpn.profileManagementActive}' : profile.name,
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
            section('Wi‑Fi', 'wifi'),
            section('LTE', 'mobile'),
          ],
        ],
      ),
    );
  }
}
