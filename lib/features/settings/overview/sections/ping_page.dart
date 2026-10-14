import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';
import 'package:hiddify/features/proxy/model/ping_style.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Settings → Ping: where the servers' pings go (a few known addresses, or one of the user's own, each measurable
/// through the VPN here), switching to the next one when no server has answered for a minute, how long a ping may
/// take, how often the servers are pinged by themselves, and how the pings look in the list.
class PingPage extends HookConsumerWidget {
  const PingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = ref.watch(ConfigOptions.connectionTestUrl);
    final connected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    // each address's answer through the VPN, measured on request: ms, or null when it didn't answer
    final measured = useState<Map<String, int?>>({});
    final measuring = useState(false);

    Future<void> choose(String url) async {
      if (url == ref.read(ConfigOptions.connectionTestUrl)) return;
      await ref.read(ConfigOptions.connectionTestUrl.notifier).update(url);
      // the servers' pings go there from the next connection: now, when connected
      if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
        await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
      }
    }

    Future<void> measureAll() async {
      if (measuring.value) return;
      measuring.value = true;
      measured.value = {};
      final port = ref.read(ConfigOptions.mixedPort);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
      try {
        await Future.wait([
          for (final p in [...pingTargets.map((p) => p.url), if (pingTargetName(target) == null) target])
            () async {
              int? ms;
              final watch = Stopwatch()..start();
              try {
                final request = await client.headUrl(Uri.parse(p)).timeout(const Duration(seconds: 3));
                final response = await request.close().timeout(const Duration(seconds: 3));
                await response.drain<void>();
                ms = watch.elapsedMilliseconds;
              } catch (_) {
                ms = null;
              }
              if (context.mounted) measured.value = {...measured.value, p: ms};
            }(),
        ]);
      } finally {
        client.close(force: true);
        if (context.mounted) measuring.value = false;
      }
    }

    Widget result(String url) {
      if (!measured.value.containsKey(url)) return const SizedBox.shrink();
      final ms = measured.value[url];
      return Text(
        ms == null ? t.avpn.pingNoAnswer : '$ms ms',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: ms == null ? scheme.error : scheme.primary,
        ),
      );
    }

    String pingStyleName(PingStyle style) => switch (style) {
      PingStyle.numbers => t.avpn.pingNumbers,
      PingStyle.bars => t.avpn.pingBars,
      PingStyle.barsAndNumbers => t.avpn.pingBarsAndNumbers,
      PingStyle.dots => t.avpn.pingDots,
    };

    Future<T?> pick<T>(String title, List<T> values, T selected, String Function(T) label) => showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final value in values)
            ListTile(
              title: Text(label(value)),
              trailing: value == selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
              onTap: () => Navigator.of(context).pop(value),
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

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.pingSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          heading(t.avpn.pingTarget),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              t.avpn.pingTargetMsg,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          RadioGroup<String>(
            groupValue: target,
            onChanged: (url) => url == null ? null : choose(url),
            child: Column(
              children: [
                for (final p in pingTargets)
                  RadioListTile<String>(
                    value: p.url,
                    title: Text(p.name),
                    subtitle: Text(p.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    secondary: result(p.url),
                  ),
              ],
            ),
          ),
          ValuePreferenceWidget(
            value: target,
            preferences: ref.watch(ConfigOptions.connectionTestUrl.notifier),
            title: t.avpn.pingTargetCustom,
            presentValue: (url) => pingTargetName(url) == null ? url : t.avpn.pingTargetCustomHint,
            icon: Icons.edit_rounded,
          ),
          ListTile(
            leading: measuring.value
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Icon(Icons.speed_rounded),
            title: Text(t.avpn.pingTestTargets),
            subtitle: Text(connected ? t.avpn.pingTestTargetsMsg : t.avpn.pingNeedVpn),
            enabled: connected && !measuring.value,
            onTap: measureAll,
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: Text(t.avpn.pingAutoSwitch),
            subtitle: Text(t.avpn.pingAutoSwitchMsg),
            value: ref.watch(Preferences.pingAutoSwitch),
            onChanged: ref.read(Preferences.pingAutoSwitch.notifier).update,
          ),
          heading(t.avpn.pingChecks),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom_rounded),
            title: Text(t.avpn.pingTimeout),
            subtitle: Text(
              '${t.avpn.seconds(n: ref.watch(ConfigOptions.urlTestTimeout).inSeconds)} · ${t.avpn.pingTimeoutMsg}',
            ),
            onTap: () async {
              final picked = await pick(
                t.avpn.pingTimeout,
                const [2, 3, 5, 7, 10],
                ref.read(ConfigOptions.urlTestTimeout).inSeconds,
                (n) => t.avpn.seconds(n: n),
              );
              if (picked != null)
                await ref.read(ConfigOptions.urlTestTimeout.notifier).update(Duration(seconds: picked));
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: Text(t.pages.settings.general.urlTestInterval),
            subtitle: Text(t.avpn.pingEveryMinutes(n: ref.watch(ConfigOptions.urlTestInterval).inMinutes)),
            onTap: () async {
              final picked = await pick(
                t.pages.settings.general.urlTestInterval,
                const [1, 3, 5, 10, 30, 60],
                ref.read(ConfigOptions.urlTestInterval).inMinutes,
                (n) => t.avpn.pingEveryMinutes(n: n),
              );
              if (picked != null)
                await ref.read(ConfigOptions.urlTestInterval.notifier).update(Duration(minutes: picked));
            },
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.network_ping_rounded),
            title: Text(t.avpn.autoPingOnOpen),
            subtitle: Text(t.avpn.autoPingOnOpenMsg),
            value: ref.watch(Preferences.autoPingOnOpen),
            onChanged: ref.read(Preferences.autoPingOnOpen.notifier).update,
          ),
          heading(t.avpn.pingLook),
          ListTile(
            leading: const Icon(Icons.signal_cellular_alt_rounded),
            title: Text(t.avpn.pingStyle),
            subtitle: Text(pingStyleName(ref.watch(Preferences.pingStyle))),
            onTap: () async {
              final picked = await pick(
                t.avpn.pingStyle,
                PingStyle.values,
                ref.read(Preferences.pingStyle),
                pingStyleName,
              );
              if (picked != null) await ref.read(Preferences.pingStyle.notifier).update(picked);
            },
          ),
        ],
      ),
    );
  }
}
