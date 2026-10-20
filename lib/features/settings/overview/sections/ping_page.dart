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
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Settings / Ping: where the servers' pings go (a few known addresses, or one of the user's own, each measurable
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
    final https = ref.watch(ConfigOptions.pingHttps);
    final targets = pingTargetsFor(https);
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
          for (final p in [...targets.map((p) => p.url), if (pingTargetName(target) == null) target])
            () async {
              int? ms;
              final watch = Stopwatch()..start();
              try {
                final request = await client
                    .headUrl(Uri.parse(pingUrl(p, ref.read(ConfigOptions.pingHttps))))
                    .timeout(const Duration(seconds: 3));
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
          // HTTP or HTTPS: how the servers' pings go
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(t.avpn.pingMethod),
            subtitle: Text(t.avpn.pingMethodMsg),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('HTTP')),
                ButtonSegment(value: true, label: Text('HTTPS')),
              ],
              selected: {https},
              showSelectedIcon: false,
              onSelectionChanged: (value) async {
                final on = value.first;
                await ref.read(ConfigOptions.pingHttps.notifier).update(on);
                measured.value = {};
                // a target without HTTPS: the first one with it instead
                final current = ref.read(ConfigOptions.connectionTestUrl);
                if (on && !pingTargetHasHttps(current)) {
                  await ref.read(ConfigOptions.connectionTestUrl.notifier).update(pingTargetsFor(true).first.url);
                }
                if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
                  await ref
                      .read(connectionNotifierProvider.notifier)
                      .reconnect(await ref.read(activeProfileProvider.future));
                }
              },
            ),
          ),
          RadioGroup<String>(
            groupValue: target,
            onChanged: (url) => url == null ? null : choose(url),
            child: Column(
              children: [
                for (final p in targets)
                  RadioListTile<String>(
                    value: p.url,
                    title: Text(p.name),
                    subtitle: Text(pingUrl(p.url, https), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          heading(t.avpn.pingSites),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              t.avpn.siteGroupsMsg,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          // each service the home screen times through the server answering it soonest (the core's site groups), on
          // Wi-Fi and on mobile data each as chosen
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
                // the groups are in the config: the next connection has them, now when connected
                if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
                  await ref
                      .read(connectionNotifierProvider.notifier)
                      .reconnect(await ref.read(activeProfileProvider.future));
                }
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
                final picked = await pick(
                  '${t.avpn.siteGroupsTolerance} · $network',
                  ConfigOptions.siteGroupsTolerances,
                  ref.read(tolerance),
                  (ms) => '$ms ms',
                );
                if (picked == null || picked == ref.read(tolerance)) return;
                await ref.read(tolerance.notifier).update(picked);
                if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
                  await ref
                      .read(connectionNotifierProvider.notifier)
                      .reconnect(await ref.read(activeProfileProvider.future));
                }
              },
            ),
          ],
          heading(t.avpn.pingChecks),
          for (final entry in [
            ('Wi-Fi', ConfigOptions.urlTestTimeoutWifi),
            if (!PlatformUtils.isDesktop) ('LTE', ConfigOptions.urlTestTimeoutMobile),
          ])
            ListTile(
              leading: const Icon(Icons.hourglass_bottom_rounded),
              title: Text('${t.avpn.pingTimeout} · ${entry.$1}'),
              subtitle: Text('${t.avpn.seconds(n: ref.watch(entry.$2).inSeconds)} · ${t.avpn.pingTimeoutMsg}'),
              onTap: () async {
                final picked = await pick(
                  '${t.avpn.pingTimeout} · ${entry.$1}',
                  List.generate(30, (i) => i + 1),
                  ref.read(entry.$2).inSeconds,
                  (n) => t.avpn.seconds(n: n),
                );
                if (picked == null) return;
                await ref.read(entry.$2.notifier).update(Duration(seconds: picked));
                if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
                  await ref
                      .read(connectionNotifierProvider.notifier)
                      .reconnect(await ref.read(activeProfileProvider.future));
                }
              },
            ),
          for (final entry in [
            ('Wi-Fi', ConfigOptions.balancerToleranceWifi),
            if (!PlatformUtils.isDesktop) ('LTE', ConfigOptions.balancerToleranceMobile),
          ])
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text('Порог переключения · ${entry.$1}'),
              subtitle: Text('${ref.watch(entry.$2)} мс'),
              onTap: () async {
                final picked = await pick(
                  'Порог переключения · ${entry.$1}',
                  [0, 25, 50, 75, 100, 150, 200, 300],
                  ref.read(entry.$2),
                  (n) => '$n мс',
                );
                if (picked == null) return;
                await ref.read(entry.$2.notifier).update(picked);
                if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
                  await ref
                      .read(connectionNotifierProvider.notifier)
                      .reconnect(await ref.read(activeProfileProvider.future));
                }
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
