import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings / Sites (beta): the services the home screen times, and the apps the user chooses, each through the
/// server steadily answering it soonest; on Wi-Fi and on mobile data each as chosen, with its switch threshold.
class SitesPage extends HookConsumerWidget {
  const SitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // the groups are in the config: the next connection has them, now when connected
    Future<void> apply() async {
      if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
        await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
      }
    }

    Future<int?> pickThreshold(String title, int selected) => showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final ms in ConfigOptions.siteGroupsTolerances)
            ListTile(
              title: Text('$ms ms'),
              trailing: ms == selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
              onTap: () => Navigator.of(context).pop(ms),
            ),
        ],
      ),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );

    Widget note(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
    );

    final apps = ref.watch(ConfigOptions.siteGroupApps);
    final installed = ref.watch(installedAppsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.pingSites)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          note(t.avpn.siteGroupsMsg),
          for (final (network, enabled, tolerance) in [
            ('Wi-Fi', ConfigOptions.siteGroups, ConfigOptions.siteGroupsTolerance),
            if (!PlatformUtils.isDesktop)
              ('LTE', ConfigOptions.siteGroupsMobile, ConfigOptions.siteGroupsToleranceMobile),
          ]) ...[
            SwitchListTile.adaptive(
              secondary: Icon(network == 'LTE' ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded),
              title: Text(PlatformUtils.isDesktop ? t.avpn.siteGroups : '${t.avpn.siteGroups} · $network'),
              value: ref.watch(enabled),
              onChanged: (on) async {
                await ref.read(enabled.notifier).update(on);
                await apply();
              },
            ),
            // how much sooner another server must be before a site moves to it
            ListTile(
              leading: const Icon(Icons.compare_arrows_rounded),
              enabled: ref.watch(enabled),
              title: Text(
                PlatformUtils.isDesktop ? t.avpn.siteGroupsTolerance : '${t.avpn.siteGroupsTolerance} · $network',
              ),
              subtitle: Text('${ref.watch(tolerance)} ms · ${t.avpn.siteGroupsToleranceMsg}'),
              onTap: () async {
                final picked = await pickThreshold('${t.avpn.siteGroupsTolerance} · $network', ref.read(tolerance));
                if (picked == null || picked == ref.read(tolerance)) return;
                await ref.read(tolerance.notifier).update(picked);
                await apply();
              },
            ),
          ],
          // the apps with a server of their own (a phone's apps are known by package)
          if (PlatformUtils.isAndroid) ...[
            heading(t.avpn.siteGroupApps),
            note(t.avpn.siteGroupAppsMsg),
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: Text(t.avpn.siteGroupAppsChoose),
              subtitle: Text(apps.isEmpty ? t.avpn.siteGroupAppsNone : t.avpn.siteGroupAppsCount(n: apps.length)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go(context.namedLocation('siteApps')),
            ),
            for (final app in apps)
              ListTile(
                leading: _AppIcon(icon: installed[app]?.icon, name: installed[app]?.name ?? app),
                title: Text(installed[app]?.name ?? app, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(app, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    await ref.read(ConfigOptions.siteGroupApps.notifier).update([
                      for (final a in apps)
                        if (a != app) a,
                    ]);
                    await apply();
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.icon, required this.name});

  final Uint8List? icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: icon != null
          ? Image.memory(icon!, width: 36, height: 36, gaplessPlayback: true)
          : Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              color: scheme.surfaceContainerHighest,
              child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
            ),
    );
  }
}

/// The phone's apps to pick from: a search line and a box for each, the chosen ones first; Done keeps the choice
/// (and reconnects with it), Back leaves it as it was.
class SiteAppsPage extends HookConsumerWidget {
  const SiteAppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = useMemoized(() => ref.read(ConfigOptions.siteGroupApps));
    final chosen = useState<Set<String>>({...selected});
    final query = useState('');
    final installed = ref.watch(installedAppsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.avpn.siteGroupAppsChoose),
        actions: [
          TextButton(
            onPressed: () async {
              final picked = chosen.value.toList();
              final changed = picked.length != selected.length || !picked.every(selected.contains);
              // the container, not ref: this page is gone by the time the reconnect is under way
              final container = ProviderScope.containerOf(context, listen: false);
              if (context.canPop()) context.pop();
              if (!changed) return;
              await container.read(ConfigOptions.siteGroupApps.notifier).update(picked);
              if (container.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
                await container
                    .read(connectionNotifierProvider.notifier)
                    .reconnect(await container.read(activeProfileProvider.future));
              }
            },
            child: Text(t.avpn.siteGroupAppsDone),
          ),
        ],
      ),
      body: installed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const SizedBox.shrink(),
        data: (apps) {
          final q = query.value.trim().toLowerCase();
          final list =
              apps.entries
                  .where((e) => q.isEmpty || e.value.name.toLowerCase().contains(q) || e.key.toLowerCase().contains(q))
                  .toList()
                ..sort((a, b) {
                  // the chosen ones first, then by name
                  final ca = selected.contains(a.key) ? 0 : 1;
                  final cb = selected.contains(b.key) ? 0 : 1;
                  return ca != cb ? ca - cb : a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase());
                });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: t.avpn.siteGroupAppsSearch,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => query.value = v,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final on = chosen.value.contains(e.key);
                    return CheckboxListTile(
                      value: on,
                      secondary: _AppIcon(icon: e.value.icon, name: e.value.name),
                      title: Text(e.value.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onChanged: (v) =>
                          chosen.value = v ?? false ? {...chosen.value, e.key} : ({...chosen.value}..remove(e.key)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
