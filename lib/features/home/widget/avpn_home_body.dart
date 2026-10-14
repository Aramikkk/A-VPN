import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/widget/traffic_strips.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/connection/notifier/shown_connection.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/proxy/data/home_network.dart';
import 'package:hiddify/features/proxy/data/lan_sharing.dart';
import 'package:hiddify/features/proxy/data/hidden_servers.dart';
import 'package:hiddify/features/proxy/data/ping_targets.dart';
import 'package:hiddify/features/proxy/data/pre_ping.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/proxy/model/ping_style.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'styled_home.dart';

/// Home screen: the provider card with the server list inside, a "check" row, and the connection card.
class AraHomeBody extends HookConsumerWidget {
  const AraHomeBody({super.key, this.traffic = true});

  /// the traffic strips under the servers; the unfolded phone shows them in the right half instead
  final bool traffic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    // set while a ping of every server runs, so the list can show spinners
    final testing = useState(false);

    Future<void> pingAll() async {
      if (testing.value) return;
      testing.value = true;
      try {
        await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest("select");
        await Future<void>.delayed(const Duration(seconds: 4));
      } catch (_) {
        // not connected: nothing to ping
      } finally {
        if (context.mounted) testing.value = false;
      }
    }

    // the servers' pings kept fresh: once a minute while connected and on screen, quietly (the list just updates,
    // no spinners); back from the background after longer, at once
    final connected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    useEffect(() {
      if (!connected) return null;
      var last = DateTime.now();
      Future<void> refresh() async {
        if (testing.value) return;
        last = DateTime.now();
        try {
          await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest("select", quiet: true);
        } catch (_) {
          // the core went away meanwhile: next time
        }
      }

      final timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) unawaited(refresh());
      });
      // no server answering yet (just connected, or the network came back): every 3 seconds until one does; a minute
      // with none (the address may be what's down), the next known ping address and a reconnect, if that's on
      var retrying = false;
      var lastAnswer = DateTime.now();
      final retry = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (retrying || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
        final items = ref.read(proxiesOverviewNotifierProvider).valueOrNull?.items ?? const <OutboundInfo>[];
        final answering = items.any((i) => !i.isGroup && i.urlTestDelay > 0 && i.urlTestDelay < 65000);
        if (answering) {
          lastAnswer = DateTime.now();
          return;
        }
        retrying = true;
        if (ref.read(Preferences.pingAutoSwitch) &&
            DateTime.now().difference(lastAnswer) >= const Duration(minutes: 1)) {
          lastAnswer = DateTime.now();
          final next = nextPingTarget(ref.read(ConfigOptions.connectionTestUrl));
          await ref.read(ConfigOptions.connectionTestUrl.notifier).update(next.url);
          ref.read(inAppNotificationControllerProvider).showInfoToast(t.avpn.pingSwitched(name: next.name));
          try {
            await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
          } catch (_) {
            // the next round tries again
          }
        } else {
          await refresh();
        }
        retrying = false;
      });
      final lifecycle = AppLifecycleListener(
        onResume: () {
          if (DateTime.now().difference(last) >= const Duration(minutes: 1)) unawaited(refresh());
        },
      );
      return () {
        timer.cancel();
        retry.cancel();
        lifecycle.dispose();
      };
    }, [connected]);

    final style = Theme.of(context).araLook.style;
    if (style != AraStyle.classic) {
      return _StyledHome(testing: testing.value, onCheck: pingAll, traffic: traffic);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Text(
              t.avpn.provider.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2),
            ),
          ),
          Expanded(
            child: profile == null
                ? _EmptyCard(text: t.avpn.noProfile)
                : _ProviderCard(profile: profile, testing: testing.value),
          ),
          const Gap(10),
          _CheckRow(onCheck: pingAll, testing: testing.value),
          const Gap(10),
          const _ConnectionCard(),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _EmptyCard extends ConsumerWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Center(
        child: TextButton.icon(
          onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
          icon: const Icon(Icons.add_rounded),
          label: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _ProviderCard extends HookConsumerWidget {
  const _ProviderCard({required this.profile, required this.testing});

  final ProfileEntity profile;
  final bool testing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final group = proxies.valueOrNull;
    final servers = [
      for (final item in group?.items ?? <OutboundInfo>[])
        if (item.isVisible && item.tag != 'balance') item,
    ];
    // the server the auto choice uses right now (the core starts on "balance", which picks the same way)
    final autoGroup = group?.items
        .where((i) => i.tag == (group.selected == 'balance' ? 'balance' : 'lowest'))
        .firstOrNull;
    final autoNow = autoGroup == null ? null : autoPick(autoGroup, group!.items);
    final remote = profile is RemoteProfileEntity ? profile as RemoteProfileEntity : null;
    final sub = remote?.subInfo;
    final updating = remote != null && ref.watch(updateProfileNotifierProvider(profile.id)).isLoading;

    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _InitialBadge(name: sigmaName(profile.name)),
              const Gap(12),
              Expanded(
                child: Text(
                  sigmaName(profile.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary),
                ),
              ),
              if (remote != null)
                _RoundButton(
                  icon: Icons.refresh_rounded,
                  busy: updating,
                  onTap: () => ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(remote),
                ),
            ],
          ),
          if (sub != null) ...[
            const Gap(12),
            Row(
              children: [
                Text(
                  sub.isExpired ? t.avpn.expired : t.avpn.daysLeft(days: sub.remaining.inDays),
                  style: theme.textTheme.bodySmall,
                ),
                const Gap(10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sub.total > 0 ? sub.ratio : 0,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const Gap(10),
                Text(
                  '${_gb(sub.consumption)} / ${sub.total > 0 ? _gb(sub.total) : '∞'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
          const Gap(10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              [
                _dateTime(profile.lastUpdate),
                if (servers.isNotEmpty) t.avpn.serverCount(count: servers.where((s) => !s.isGroup).length),
              ].join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const Gap(6),
          Expanded(
            child: servers.isEmpty
                ? Center(
                    child: Text(
                      t.avpn.connectToSeeServers,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: servers.length,
                    itemBuilder: (context, i) => _ServerTile(
                      server: servers[i],
                      // the core starts on its balancer, which also picks the lowest ping: show it as "auto"
                      selected:
                          servers[i].tag == group?.selected ||
                          (servers[i].tag == 'lowest' && group?.selected == 'balance'),
                      testing: testing,
                      autoNow: servers[i].tag == 'lowest' ? autoNow : null,
                      onTap: () =>
                          ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy("select", servers[i].tag),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServerTile extends ConsumerWidget {
  const _ServerTile({
    required this.server,
    required this.selected,
    required this.testing,
    required this.onTap,
    this.autoNow,
  });

  final OutboundInfo server;

  /// for the auto row: the server it uses right now
  final OutboundInfo? autoNow;
  final bool selected;
  final bool testing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = serverName(server);
    final (title, subtitle) = switch (server.tag) {
      'lowest' => (
        autoNow == null ? t.avpn.autoBest : '${t.avpn.auto}: ${_withFlag(serverName(autoNow!))}',
        t.avpn.autoBestHint,
      ),
      _ => (name.title, server.type.toUpperCase()),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.primaryContainer.withValues(alpha: .35) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: server.isGroup
                      ? Icon(Icons.bolt_rounded, size: 18, color: scheme.primary)
                      : Text(name.flag ?? '🌐', style: const TextStyle(fontSize: 16)),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontSize: PlatformUtils.isDesktop ? 11.5 : 10,
                          fontWeight: PlatformUtils.isDesktop ? FontWeight.w600 : null,
                          letterSpacing: PlatformUtils.isDesktop ? .2 : .4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                _Delay(delay: server.urlTestDelay, testing: testing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Delay extends ConsumerWidget {
  const _Delay({required this.delay, required this.testing});

  final int delay;
  final bool testing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (testing) {
      return SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary));
    }
    // the desktop gets a slightly larger, bolder ping: tiny thin text renders soft on Windows
    final style = PlatformUtils.isDesktop
        ? Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)
        // the phone: bold, the numbers read at a glance on the glass
        : Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .2);
    if (delay <= 0) return Text('—', style: style?.copyWith(color: scheme.onSurfaceVariant));
    if (delay > 65000) return Icon(Icons.close_rounded, size: 14, color: scheme.error);
    // yellow and orange need darker shades to read on the light theme's white
    final color = switch (delay) {
      // the theme's own scale (red, orange, amber, yellow in the red theme), grey when slow
      <= 500 => Theme.of(context).araLook.pingColor(delay, scheme.onSurfaceVariant),
      _ => scheme.onSurfaceVariant,
    };
    final number = Text('$delay ms', style: style?.copyWith(color: color));
    final bars = _Bars(
      lit: switch (delay) {
        <= 100 => 4,
        <= 150 => 3,
        <= 250 => 2,
        <= 500 => 1,
        _ => 0,
      },
      color: color,
      off: scheme.outlineVariant,
    );
    return switch (ref.watch(Preferences.pingStyle)) {
      PingStyle.numbers => number,
      PingStyle.bars => bars,
      PingStyle.barsAndNumbers => Row(mainAxisSize: MainAxisSize.min, children: [bars, const Gap(6), number]),
      PingStyle.dots => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    };
  }
}

/// Four signal bars, [lit] of them in [color].
class _Bars extends StatelessWidget {
  const _Bars({required this.lit, required this.color, required this.off});

  final int lit;
  final Color color;
  final Color off;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 3,
            height: 5.0 + i * 3,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
            decoration: BoxDecoration(color: i < lit ? color : off, borderRadius: BorderRadius.circular(1)),
          ),
      ],
    );
  }
}

class _CheckRow extends HookConsumerWidget {
  const _CheckRow({required this.onCheck, required this.testing, this.showCheck = true});

  final VoidCallback onCheck;
  final bool testing;

  /// the "check" button (the styled homes have it over the list instead)
  final bool showCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final configPath = profile == null ? null : ref.watch(profilePathResolverProvider).file(profile.id).path;
    // the button shows only once a WireGuard profile (the user's own server) is added next to the active one
    // the last answer is kept while the profile reloads (a reconnect): the button doesn't drop out for a moment
    // and the row of toggles doesn't jump
    final lastAvailable = useRef(false);
    final checked = useFuture(
      useMemoized(() => configPath == null ? null : HomeNetwork.available(configPath), [configPath]),
    ).data;
    if (checked != null) lastAvailable.value = checked;
    final serverAvailable = lastAvailable.value;
    final serverOn = ref.watch(ConfigOptions.homeNetwork);
    final sharingOn = ref.watch(ConfigOptions.allowConnectionFromLan);

    Future<void> reconnectIfConnected() async {
      if (ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) {
        await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
      }
    }

    // Server and Global each decide every connection, so one turns the other off
    Future<void> toggleServer(bool on) async {
      if (on) await ref.read(ConfigOptions.globalMode.notifier).update(false);
      await ref.read(ConfigOptions.homeNetwork.notifier).update(on);
      await reconnectIfConnected();
    }

    Future<void> toggleGlobal(bool on) async {
      if (on) await ref.read(ConfigOptions.homeNetwork.notifier).update(false);
      await ref.read(ConfigOptions.globalMode.notifier).update(on);
      await reconnectIfConnected();
    }

    Future<void> toggleSharing(bool on) async {
      await ref.read(ConfigOptions.allowConnectionFromLan.notifier).update(on);
      await reconnectIfConnected();
      if (on && context.mounted) await showDialog<void>(context: context, builder: (_) => const _SharingDialog());
    }

    // Glass: the toggles in one pane the width of the connect panel, each an equal part of it; Contrast: outlined
    // pills on its black panel, the ones on filled
    final glass = Theme.of(context).araLook.glass;
    if (Theme.of(context).araLook.style == AraStyle.contrast) {
      final scheme = Theme.of(context).colorScheme;
      Widget pill(IconData icon, String label, bool on, Future<void> Function(bool) toggle, VoidCallback? hold) =>
          Expanded(
            child: GestureDetector(
              onLongPress: hold,
              child: Material(
                color: on ? scheme.onSurface : Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(color: on ? scheme.onSurface : scheme.outlineVariant, width: 1.3),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => toggle(!on),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 16, color: on ? scheme.surface : scheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: on ? scheme.surface : scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      return Row(
        spacing: 6,
        children: [
          pill(
            Icons.wifi_tethering_rounded,
            t.avpn.sharing,
            sharingOn,
            toggleSharing,
            () => showDialog<void>(context: context, builder: (_) => const _SharingDialog()),
          ),
          pill(Icons.public_rounded, t.avpn.global, ref.watch(ConfigOptions.globalMode), toggleGlobal, null),
          if (serverAvailable) pill(Icons.home_rounded, t.avpn.server, serverOn, toggleServer, null),
        ],
      );
    }
    if (glass != null) {
      return _GlassToggles(
        look: glass,
        items: [
          (
            icon: Icons.wifi_tethering_rounded,
            label: t.avpn.sharing,
            on: sharingOn,
            toggle: toggleSharing,
            // how to use sharing, on a long press
            hold: () => showDialog<void>(context: context, builder: (_) => const _SharingDialog()),
          ),
          (
            icon: Icons.public_rounded,
            label: t.avpn.global,
            on: ref.watch(ConfigOptions.globalMode),
            toggle: toggleGlobal,
            hold: null,
          ),
          if (serverAvailable)
            (icon: Icons.home_rounded, label: t.avpn.server, on: serverOn, toggle: toggleServer, hold: null),
        ],
      );
    }

    // the toggles in the middle, the ping check (classic) on the right
    return Row(
      children: [
        // one line in the middle; a very narrow screen shrinks it a little rather than cut it
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              spacing: 6,
              children: [
                // how to use sharing on a long press (no extra button in the row: it would shift the others)
                GestureDetector(
                  onLongPress: () => showDialog<void>(context: context, builder: (_) => const _SharingDialog()),
                  child: _ToggleChip(
                    icon: Icons.wifi_tethering_rounded,
                    label: t.avpn.sharing,
                    selected: sharingOn,
                    onSelected: toggleSharing,
                  ),
                ),
                _ToggleChip(
                  icon: Icons.public_rounded,
                  label: t.avpn.global,
                  selected: ref.watch(ConfigOptions.globalMode),
                  onSelected: toggleGlobal,
                ),
                if (serverAvailable) ...[
                  _ToggleChip(
                    icon: Icons.home_rounded,
                    label: t.avpn.server,
                    selected: serverOn,
                    onSelected: toggleServer,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showCheck)
          TextButton.icon(
            onPressed: connected && !testing ? onCheck : null,
            icon: const Icon(Icons.network_ping_rounded),
            label: Text(t.avpn.check),
          ),
      ],
    );
  }
}

typedef _GlassToggle = ({IconData icon, String label, bool on, Future<void> Function(bool) toggle, VoidCallback? hold});

/// Glass's toggles: one see-through pane split into equal parts, the ones on filled with the scheme's colour.
class _GlassToggles extends StatelessWidget {
  const _GlassToggles({required this.look, required this.items});

  final GlassLook look;
  final List<_GlassToggle> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: look.panel,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: look.edge, width: 1.2),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                onLongPress: item.hold,
                child: Material(
                  // off: a barely-there plate, so each toggle reads as a button
                  color: item.on
                      ? look.tint(scheme.onSurface, look.dark ? .3 : .75)
                      : scheme.onSurface.withValues(alpha: look.dark ? .06 : .045),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => item.toggle(!item.on),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, size: 17, color: item.on ? scheme.onSurface : scheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: item.on ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.icon, required this.label, required this.selected, required this.onSelected});

  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      labelPadding: const EdgeInsetsDirectional.only(start: 4, end: 6),
      // the icon right next to its word, without the chip's wide avatar box
      avatarBoxConstraints: const BoxConstraints.tightFor(width: 20, height: 20),
      avatar: Icon(icon, size: 16, color: selected ? scheme.onPrimary : null),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: scheme.primary,
      labelStyle: TextStyle(fontSize: 13, color: selected ? scheme.onPrimary : null),
      // the styled looks shape their chips themselves
      shape: Theme.of(context).araLook.style == AraStyle.classic
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          : null,
      onSelected: onSelected,
    );
  }
}

/// How another device uses the phone's VPN: connect to its hotspot, set this address as the Wi-Fi's proxy.
class _SharingDialog extends HookConsumerWidget {
  const _SharingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final port = ref.watch(ConfigOptions.mixedPort);
    final addresses = useFuture(useMemoized(LanSharing.addresses)).data;
    final hotspot = addresses?.where((a) => a.hotspot).toList() ?? const [];
    final shown = hotspot.isNotEmpty ? hotspot : (addresses ?? const []);

    return AlertDialog(
      title: Text(t.avpn.sharingTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (addresses != null && hotspot.isEmpty) ...[
              Text(
                t.avpn.sharingNoHotspot,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
              const Gap(12),
            ],
            Text(t.avpn.sharingHowTo),
            const Gap(12),
            for (final a in shown)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: SelectableText('${a.address}:$port', style: theme.textTheme.titleMedium),
                  subtitle: Text('${t.avpn.sharingHost}: ${a.address}   ${t.avpn.sharingPort}: $port'),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => Clipboard.setData(ClipboardData(text: '${a.address}:$port')),
                  ),
                ),
              ),
            const Gap(4),
            Text(
              t.avpn.sharingNote,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
    );
  }
}

class _ConnectionCard extends HookConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(connectionNotifierProvider).valueOrNull ?? const Disconnected();
    final connected = status.isConnected;
    final stats = ref.watch(statsNotifierProvider).valueOrNull;
    final group = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;

    // how long the tunnel has been up, ticking every second while connected: from the core's session start, so
    // reopening the app doesn't restart the count (the local start is only the fallback for an older core)
    final since = useState<DateTime?>(null);
    final now = useState(DateTime.now());
    useEffect(() {
      if (!connected) {
        since.value = null;
        return null;
      }
      since.value ??= DateTime.now();
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => now.value = DateTime.now());
      return timer.cancel;
    }, [connected]);

    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    // on auto, the country it uses right now
    final picked = current != null && current.isGroup ? autoPick(current, group!.items) : null;
    final currentName = switch (current?.tag) {
      'lowest' ||
      'balance' => picked == null ? t.avpn.autoBest : '${t.avpn.auto}: ${_withFlag(serverName(picked))}',
      null => null,
      _ => serverName(current!).title,
    };
    final serverMode = ref.watch(ConfigOptions.homeNetwork);
    final title = switch (status) {
      Connected() when serverMode => '🏠 ${t.avpn.server}',
      Connected() => currentName ?? t.avpn.autoBest,
      Connecting() => t.avpn.connecting,
      Disconnecting() => t.avpn.disconnecting,
      Disconnected() => t.avpn.notConnected,
    };

    Future<void> toggle() async {
      if (ref.read(activeProfileProvider).valueOrNull == null) {
        await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
        ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
        return;
      }
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    }

    final gradient = theme.araLook.gradient;
    final units = t.avpn.bytesUnits.split(',');
    String speed(int bytes) => '${formatBytes(bytes, units)}${t.avpn.perSecond}';
    final card = _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.25,
            child: Switch(
              value: connected || status is Connecting,
              onChanged: status.isSwitching ? null : (_) => toggle(),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (connected && !serverMode && current != null && !current.isGroup) serverName(current).flag,
                    title,
                  ].whereType<String>().join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const Gap(4),
                if (connected)
                  Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, size: 14, color: scheme.primary),
                      Text(' ${speed(stats?.uplink.toInt() ?? 0)}', style: theme.textTheme.bodySmall),
                      const Spacer(),
                      Icon(Icons.arrow_downward_rounded, size: 14, color: scheme.primary),
                      Text(' ${speed(stats?.downlink.toInt() ?? 0)}', style: theme.textTheme.bodySmall),
                      const Spacer(),
                      Icon(Icons.schedule_rounded, size: 14, color: scheme.onSurfaceVariant),
                      Text(
                        ' ${_duration(now.value.difference(stats?.sessionStartedAt ?? since.value ?? now.value))}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (gradient == null || !connected) return card;
    // desktop, connected: the card gets a thin outline in the accent gradient
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: theme.araLook.border == null ? gradient : null,
        color: theme.araLook.border,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: card),
    );
  }
}

class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.primary,
        gradient: Theme.of(context).araLook.gradient,
        border: Theme.of(context).araLook.border == null ? null : Border.all(color: Theme.of(context).araLook.border!),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Theme.of(context).araLook.gradient != null ? Theme.of(context).araLook.onGradient : scheme.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 19,
          letterSpacing: -.5,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.busy = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                  )
                : Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}

/// The server an auto group ("lowest", "balance") uses right now, if the core has said.
OutboundInfo? autoPick(OutboundInfo group, List<OutboundInfo> items) {
  if (!group.hasGroupSelectedTag() || group.groupSelectedTag.isEmpty) return null;
  return items.where((i) => i.tag == group.groupSelectedTag).firstOrNull;
}

/// "🇱🇹 Литва" from "Sigma - Литва": the flag and the country, without the provider's prefix.
String _withFlag(({String? flag, String title}) name) {
  final dash = name.title.indexOf(' - ');
  final country = dash < 0 ? name.title : name.title.substring(dash + 3).trim();
  return [name.flag, _marked(country, name.title)].whereType<String>().join(' ');
}

/// [text] with "· БС" after it when [name] is a whitelist server (the provider's "LTE Only" or "БС" ones, for
/// mobile data with operator whitelists), so a bare country never hides which kind it is.
String _marked(String text, String name) =>
    ServerRegionFilter.isMobileOnly(name) && !text.contains('БС') ? '$text · $whitelistMark' : text;

/// How a whitelist server is marked wherever only its country shows.
const whitelistMark = 'БС';

/// The provider calls its regular servers and its profile "Доступ"; A-VPN shows them as Sigma (Sigma Gate).
String sigmaName(String name) =>
    name.replaceAll(RegExp('Доступ', caseSensitive: false), 'Sigma').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

/// A server's flag emoji (if its name has one) and its name without the flag and the core's " § N" suffix.
({String? flag, String title}) serverName(OutboundInfo server) {
  var name = server.tagDisplay.isNotEmpty ? server.tagDisplay : server.tag;
  name = name.replaceAll('§hide§', '').replaceAll(RegExp(r'\s*§\s*\d+\s*$'), '').trim();
  name = sigmaName(name);
  final runes = name.runes.toList();
  for (var i = 0; i + 1 < runes.length; i++) {
    final a = runes[i] - 0x1F1E6;
    final b = runes[i + 1] - 0x1F1E6;
    if (a >= 0 && a < 26 && b >= 0 && b < 26) {
      final flag = String.fromCharCodes([runes[i], runes[i + 1]]);
      return (flag: flag, title: name.replaceFirst(flag, '').trim());
    }
  }
  return (flag: null, title: name);
}

String _gb(int bytes) => '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';

String _duration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0
      ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

String _dateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${two(l.day)}.${two(l.month)}.${l.year % 100}, ${two(l.hour)}:${two(l.minute)}';
}
