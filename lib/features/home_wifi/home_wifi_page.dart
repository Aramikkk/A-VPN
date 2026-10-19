import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A home whose router runs a VPN of its own: its address on the Wi-Fi and the ports its VPN panel answers on.
typedef HomeRouter = ({String name, String gateway, List<int> ports});

List<HomeRouter> parseHomeRouters(String json) {
  try {
    return [
      for (final item in (jsonDecode(json) as List).whereType<Map<String, dynamic>>())
        (
          name: '${item['name'] ?? ''}',
          gateway: '${item['gateway'] ?? ''}',
          ports: [for (final p in (item['ports'] as List? ?? const [])) (p as num).toInt()],
        ),
    ];
  } catch (_) {
    return const [];
  }
}

String encodeHomeRouters(List<HomeRouter> homes) => jsonEncode([
  for (final h in homes) {'name': h.name, 'gateway': h.gateway, 'ports': h.ports},
]);

/// Settings → Launch and connection → Home Wi-Fi (Android): the VPN pauses on a home Wi-Fi whose router already
/// runs a VPN and comes back when the phone leaves it. A home is told by its router (no location permission):
/// this page saves the router of the Wi-Fi the phone is on; the VPN service does the watching.
class HomeWifiPage extends HookConsumerWidget {
  const HomeWifiPage({super.key});

  static const _channel = MethodChannel('com.aravpn.app/network');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = ref.watch(Preferences.homeWifiEnabled);
    final homes = parseHomeRouters(ref.watch(Preferences.homeWifiList));
    final adding = useState(false);

    Future<void> save(List<HomeRouter> list) =>
        ref.read(Preferences.homeWifiList.notifier).update(encodeHomeRouters(list));

    void say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

    Future<void> addCurrent() async {
      if (adding.value) return;
      adding.value = true;
      try {
        final answer = await _channel.invokeMapMethod<String, dynamic>('homeWifiCapture');
        if (!context.mounted) return;
        if (answer == null) return say(t.avpn.homeWifiNotOnWifi);
        final gateway = '${answer['gateway']}';
        final ports = [for (final p in (answer['ports'] as List? ?? const [])) (p as num).toInt()];
        // no VPN panel on the router: it can't be told from another router with the same address
        if (ports.isEmpty) return say(t.avpn.homeWifiNoPanel(gateway: gateway));
        if (homes.any((h) => h.gateway == gateway && h.ports.join(',') == ports.join(','))) {
          return say(t.avpn.homeWifiAlready);
        }
        final name = t.avpn.homeWifiName(n: homes.length + 1);
        await save([...homes, (name: name, gateway: gateway, ports: ports)]);
        if (!enabled) await ref.read(Preferences.homeWifiEnabled.notifier).update(true);
        say(t.avpn.homeWifiAdded(name: name));
      } catch (_) {
        if (context.mounted) say(t.avpn.homeWifiNotOnWifi);
      } finally {
        if (context.mounted) adding.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.homeWifi)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.home_work_outlined),
            title: Text(t.avpn.homeWifiPause),
            subtitle: Text(t.avpn.homeWifiPauseMsg),
            value: enabled,
            onChanged: homes.isEmpty ? null : ref.read(Preferences.homeWifiEnabled.notifier).update,
          ),
          const Divider(height: 24),
          for (final (i, home) in homes.indexed)
            ListTile(
              leading: Icon(Icons.router_outlined, color: scheme.primary),
              title: Text(home.name),
              subtitle: Text(
                t.avpn.homeWifiRouter(gateway: home.gateway, ports: home.ports.join(', ')),
              ),
              trailing: IconButton(
                tooltip: t.avpn.homeWifiRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final rest = [...homes]..removeAt(i);
                  await save(rest);
                  if (rest.isEmpty) await ref.read(Preferences.homeWifiEnabled.notifier).update(false);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FilledButton.tonalIcon(
              onPressed: adding.value ? null : addCurrent,
              icon: adding.value
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_home_outlined),
              label: Text(t.avpn.homeWifiAdd),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              t.avpn.homeWifiHow,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
