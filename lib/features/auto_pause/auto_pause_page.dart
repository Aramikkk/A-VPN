import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';

/// Auto-pause (Android): the VPN closes while one of the chosen apps (Gosuslugi, banks) is on screen and
/// opens again when it leaves. The VPN service does the watching; this page picks the apps and gets the
/// "usage access" permission it needs to know which app is on screen.
class AutoPausePage extends HookConsumerWidget {
  const AutoPausePage({super.key});

  static const _channel = MethodChannel('com.aravpn.app/autopause');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = ref.watch(Preferences.autoPauseEnabled);
    final selected = ref.watch(Preferences.autoPauseApps);

    final hasAccess = useState<bool?>(null);
    Future<void> checkAccess() async {
      try {
        hasAccess.value = await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
      } catch (_) {
        hasAccess.value = false;
      }
    }

    // the permission is granted in the phone's settings: look again when the user comes back
    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.resumed) checkAccess();
    });
    useEffect(() {
      checkAccess();
      return null;
    }, const []);

    final showSystem = useState(false);
    final query = useState('');
    final apps = useFuture(useMemoized(() => InstalledApps.getInstalledApps(false, true), const []));
    // the user's own apps (the list hides system ones unless asked)
    final userApps = useFuture(
      useMemoized(() async => (await InstalledApps.getInstalledApps()).map((a) => a.packageName).toSet(), const []),
    );

    Future<void> toggle(String pkg) async {
      final next = {...selected};
      if (!next.remove(pkg)) next.add(pkg);
      await ref.read(Preferences.autoPauseApps.notifier).update(next);
    }

    final list =
        (apps.data ?? const [])
            .where((a) => a.packageName != 'com.aravpn.app')
            .where(
              (a) =>
                  showSystem.value ||
                  (userApps.data?.contains(a.packageName) ?? true) ||
                  selected.contains(a.packageName),
            )
            .where((a) => query.value.isEmpty || a.name.toLowerCase().contains(query.value.toLowerCase()))
            .toList()
          // chosen apps first, then by name
          ..sort((a, b) {
            final sa = selected.contains(a.packageName) ? 0 : 1;
            final sb = selected.contains(b.packageName) ? 0 : 1;
            return sa != sb ? sa - sb : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.autoPause)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                t.avpn.autoPauseMsg,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          if (hasAccess.value == false)
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.avpn.autoPauseNeedAccess, style: TextStyle(color: scheme.onErrorContainer)),
                      const Gap(10),
                      FilledButton.icon(
                        onPressed: () => _channel.invokeMethod<void>('openUsageAccessSettings'),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(t.avpn.autoPauseGrant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SwitchListTile.adaptive(
              title: Text(t.avpn.autoPause),
              subtitle: Text(t.avpn.autoPauseCount(n: selected.length)),
              secondary: const Icon(Icons.pause_circle_outline_rounded),
              value: enabled,
              onChanged: ref.read(Preferences.autoPauseEnabled.notifier).update,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: t.avpn.autoPauseSearch,
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  isDense: true,
                ),
                onChanged: (v) => query.value = v,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: CheckboxListTile(
              dense: true,
              title: Text(t.avpn.autoPauseShowSystem),
              value: showSystem.value,
              onChanged: (v) => showSystem.value = v ?? false,
            ),
          ),
          if (apps.connectionState != ConnectionState.done || userApps.connectionState != ConnectionState.done)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final app = list[i];
                final icon = app.icon;
                return CheckboxListTile(
                  value: selected.contains(app.packageName),
                  onChanged: (_) => toggle(app.packageName),
                  secondary: icon == null || icon.isEmpty
                      ? const Icon(Icons.android_rounded)
                      : Image.memory(icon, width: 36, height: 36, cacheWidth: 108, gaplessPlayback: true),
                  title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          const SliverToBoxAdapter(child: Gap(24)),
        ],
      ),
    );
  }
}
