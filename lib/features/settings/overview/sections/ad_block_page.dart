import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart' show Status;
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
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
    final adsOn = ref.watch(ConfigOptions.adBlock);
    final level = ref.watch(ConfigOptions.adBlockLevel);
    final phishing = ref.watch(ConfigOptions.blockPhishing);
    final miners = ref.watch(ConfigOptions.blockMiners);
    // the exceptions are for every section
    final on = adsOn || phishing || miners;
    final allow = ref.watch(ConfigOptions.adBlockAllow);
    final ru = t.$meta.locale.languageCode == 'ru';
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
          // the extra protection (WARP, Psiphon, another profile) and the way round blocks: its own page, with the state of
          // the connection under the name
          heading(ru ? 'Доп. защита' : 'Extra protection'),
          const _ChainEntry(),
          heading(t.avpn.adBlock),
          note(t.avpn.adBlockMsg),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.block_rounded),
            title: Text(t.avpn.adBlockSwitch),
            subtitle: Text(t.avpn.adBlockAdsMsg),
            value: adsOn,
            onChanged: (value) async {
              await ref.read(ConfigOptions.adBlock.notifier).update(value);
              await apply();
            },
          ),
          if (adsOn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 1, label: Text(t.avpn.adBlockMild)),
                  ButtonSegment(value: 2, label: Text(t.avpn.adBlockNormal)),
                  ButtonSegment(value: 3, label: Text(t.avpn.adBlockStrict)),
                ],
                selected: {level.clamp(1, 3)},
                onSelectionChanged: (s) async {
                  await ref.read(ConfigOptions.adBlockLevel.notifier).update(s.first);
                  await apply();
                },
              ),
            ),
            note(switch (level) {
              1 => t.avpn.adBlockMildMsg,
              3 => t.avpn.adBlockStrictMsg,
              _ => t.avpn.adBlockNormalMsg,
            }),
          ],
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.gpp_maybe_rounded),
            title: Text(t.avpn.adBlockPhishing),
            subtitle: Text(t.avpn.adBlockPhishingMsg),
            value: phishing,
            onChanged: (value) async {
              await ref.read(ConfigOptions.blockPhishing.notifier).update(value);
              await apply();
            },
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.memory_rounded),
            title: Text(t.avpn.adBlockMiners),
            subtitle: Text(t.avpn.adBlockMinersMsg),
            value: miners,
            onChanged: (value) async {
              await ref.read(ConfigOptions.blockMiners.notifier).update(value);
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

/// The row that opens the chain page (extra protection: WARP, Psiphon or another profile, and the unblocker): what is on,
/// and while connected how the connection stands (the core says it for the server in use).
class _ChainEntry extends ConsumerWidget {
  const _ChainEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = ref.watch(translationsProvider).requireValue.$meta.locale.languageCode == 'ru';
    final chain = ref.watch(ConfigOptions.chainStatus);
    final mode = ref.watch(ConfigOptions.extraSecurityMode);
    final connected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    final status = connected ? ref.watch(activeProxyNotifierProvider).valueOrNull?.status : null;
    final what = switch (chain) {
      ChainStatus.off => ru ? 'Выключена' : 'Off',
      ChainStatus.extraSecurity => switch (mode) {
        ChainMode.warp => 'WARP',
        ChainMode.psiphon => 'Psiphon',
        ChainMode.profile => ru ? 'Другой профиль' : 'Another profile',
      },
      ChainStatus.unblocker => ru ? 'Обход блокировок' : 'Unblocker',
    };
    final state = status == null || status == Status.READY || chain == ChainStatus.off
        ? null
        : switch (status) {
            Status.CONNECTING => ru ? 'подключается…' : 'connecting…',
            Status.RECONNECTING => ru ? 'переподключается…' : 'reconnecting…',
            Status.SEARCHING => ru ? 'ищет сервер…' : 'searching…',
            Status.REGISTERING => ru ? 'регистрируется…' : 'registering…',
            Status.FAILED => ru ? 'не удалось подключиться' : 'failed',
            _ => null,
          };
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.shield_moon_outlined),
      title: Text(ru ? 'WARP, Psiphon, цепочка' : 'WARP, Psiphon, chain'),
      subtitle: Text(
        state == null ? what : '$what · $state',
        style: TextStyle(color: status == Status.FAILED ? scheme.error : null),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.pushNamed('chainOptions'),
    );
  }
}
