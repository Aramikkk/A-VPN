import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings / Ad blocking (beta): ads, trackers and malware domains refused at the VPN's level for every app and
/// site (the lists are downloaded and cached by the core), and the user's own exceptions: a domain here (with its
/// subdomains) is never blocked.
class AdBlockPage extends HookConsumerWidget {
  const AdBlockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = ref.watch(ConfigOptions.adBlock);
    final allow = ref.watch(ConfigOptions.adBlockAllow);
    final field = useTextEditingController();

    // the lists are in the config: the next connection has them, now when connected
    Future<void> apply() async {
      if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
        await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
      }
    }

    // what was typed ("https://www.Site.com/page", "*.site.com") as a domain, or null
    String? domainOf(String text) {
      var s = text.trim().toLowerCase();
      final scheme = s.indexOf('://');
      if (scheme >= 0) s = s.substring(scheme + 3);
      final cut = s.indexOf(RegExp(r'[/?#]'));
      if (cut >= 0) s = s.substring(0, cut);
      if (s.startsWith('*.')) s = s.substring(2);
      s = s.replaceAll(RegExp(r'^\.+|\.+$'), '');
      return s.contains('.') && !s.contains(RegExp(r'[\s,;]')) ? s : null;
    }

    Future<void> add() async {
      final domain = domainOf(field.text);
      if (domain == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.avpn.adBlockBadDomain)));
        return;
      }
      field.clear();
      if (allow.contains(domain)) return;
      await ref.read(ConfigOptions.adBlockAllow.notifier).update([...allow, domain]);
      await apply();
    }

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

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.adBlock)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          note(t.avpn.adBlockMsg),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.block_rounded),
            title: Text(t.avpn.adBlockSwitch),
            value: on,
            onChanged: (value) async {
              await ref.read(ConfigOptions.adBlock.notifier).update(value);
              await apply();
            },
          ),
          heading(t.avpn.adBlockAllow),
          note(t.avpn.adBlockAllowMsg),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: field,
              enabled: on,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.public_rounded),
                hintText: t.avpn.adBlockAllowHint,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), onPressed: on ? add : null),
              ),
              onSubmitted: (_) => add(),
            ),
          ),
          for (final domain in allow)
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: Text(domain, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  await ref.read(ConfigOptions.adBlockAllow.notifier).update([
                    for (final d in allow)
                      if (d != domain) d,
                  ]);
                  await apply();
                },
              ),
            ),
        ],
      ),
    );
  }
}
