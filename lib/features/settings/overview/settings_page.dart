import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show homeLookNow;
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/adaptive_layout/branch_swiper.dart' show branchChangeByBack;
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/app_update/auto_update.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        // the phone: the way back to Home, the same as the system's back (a computer has its menu)
        leading: PlatformUtils.isDesktop
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  branchChangeByBack = true;
                  // the phone's branches: Connections, Statistics, Home, Topology, Settings
                  StatefulNavigationShell.of(context).goBranch(2);
                },
              ),
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      // the sections as squares in one block: a sign, the name and a line of what is in it
      body: LayoutBuilder(
        builder: (context, page) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            _Frame(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _SectionGrid(
                  // what is left of the page for the tiles: the frame's padding, the update line, the bottom gap
                  fitHeight: page.maxHeight - 12 - 20 - (PlatformUtils.isAndroid ? 64 : 0),
                  items: [
                    (
                      Icons.view_list_rounded,
                      t.pages.profiles.title,
                      t.avpn.settingsCapProfiles,
                      context.namedLocation('profiles'),
                    ),
                    (
                      Icons.tune_rounded,
                      t.avpn.profileManagement,
                      t.avpn.settingsCapManagement,
                      context.namedLocation('profileManagement'),
                    ),
                    (
                      Icons.layers_rounded,
                      t.pages.settings.general.title,
                      t.avpn.settingsCapGeneral,
                      context.namedLocation('general'),
                    ),
                    (
                      Icons.power_settings_new_rounded,
                      t.avpn.settingsConnection,
                      t.avpn.settingsCapConnection,
                      context.namedLocation('connectionOptions'),
                    ),
                    (
                      Icons.palette_rounded,
                      t.avpn.themes,
                      t.avpn.settingsCapThemes,
                      context.namedLocation('themes'),
                    ),
                    (
                      Icons.route_rounded,
                      t.pages.settings.routing.title,
                      t.avpn.settingsCapRouting,
                      context.namedLocation('routingOptions'),
                    ),
                    (
                      Icons.dns_outlined,
                      t.avpn.settingsServers,
                      t.avpn.settingsCapServers,
                      context.namedLocation('serversOptions'),
                    ),
                    (
                      Icons.network_ping_rounded,
                      t.avpn.pingSettings,
                      t.avpn.settingsCapPing,
                      context.namedLocation('pingOptions'),
                    ),
                    // each site and chosen app through its own server (beta); DNS is under Inbound now
                    (
                      Icons.alt_route_rounded,
                      t.avpn.pingSites,
                      t.avpn.settingsCapSites,
                      context.namedLocation('sitesOptions'),
                    ),
                    (
                      Icons.block_rounded,
                      t.avpn.adBlock,
                      t.avpn.settingsCapAdBlock,
                      context.namedLocation('adBlockOptions'),
                    ),
                    (
                      Icons.description_rounded,
                      t.pages.logs.title,
                      t.avpn.settingsCapLogs,
                      context.namedLocation('logs'),
                    ),
                    // About is a section of its own again (the inbound ports and DNS went into General)
                    (
                      Icons.info_rounded,
                      t.pages.about.title,
                      t.avpn.settingsCapAbout,
                      context.namedLocation('about'),
                    ),
                  ],
                ),
              ),
            ),
            // the program's own update, looked for now (Android)
            if (PlatformUtils.isAndroid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Frame(
                  child: ListTile(
                    leading: const Icon(Icons.system_update_rounded),
                    title: Text(t.$meta.locale.languageCode == 'ru' ? 'Проверить обновления' : 'Check for updates'),
                    onTap: () => unawaited(
                      updateNow(
                        ref,
                        ru: t.$meta.locale.languageCode == 'ru',
                        tell: (message) => ref.read(inAppNotificationControllerProvider).showInfoToast(message),
                      ),
                    ),
                  ),
                ),
              ),
            if (PlatformUtils.isIOS)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  child: ListTile(
                    title: Text(t.pages.settings.resetTunnel),
                    leading: const Icon(Icons.autorenew_rounded),
                    onTap: () async {
                      await ref.read(resetTunnelNotifierProvider.notifier).run();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How the settings' tiles lie on a screen [width] points across: the columns and how much larger than on a phone each tile
/// and what is in it is. A phone has two columns at the usual size; a tablet or a car's wide screen (a BYD Han, a
/// computer in landscape) more columns and everything bigger, so it is not a few small squares in a sea of room.
({int columns, double scale}) settingsGridLayout(double width, {double gap = 8}) {
  final columns = width < 560 ? 2 : (width < 900 ? 3 : (width < 1300 ? 4 : 6));
  final tile = (width - gap * (columns - 1)) / columns;
  return (columns: columns, scale: (tile / 190).clamp(1.0, 2.2));
}

/// The sections as squares, in as many columns as the screen takes (two on a phone), each as large as the room gives: the
/// last one, when alone in its row in two columns, stretches across it.
class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.items, this.fitHeight});

  /// The height the tiles should fit into on a phone (two columns): they are made lower, down to a limit, so the
  /// whole page shows without scrolling.
  final double? fitHeight;

  /// (sign, name, what is in it, where it goes)
  final List<(IconData, String, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final layout = settingsGridLayout(box.maxWidth, gap: gap);
        final k = layout.scale;
        final side = (box.maxWidth - gap * (layout.columns - 1)) / layout.columns;
        final rows = (items.length / layout.columns).ceil();
        final fit = layout.columns == 2 && fitHeight != null ? (fitHeight! - gap * (rows - 1)) / rows : null;
        final usual = math.max(side * .7, 128.0 * k);
        final tileHeight = fit == null ? usual : fit.clamp(82.0, usual);
        // lower tiles: the sign beside the name, the caption under them
        final compact = tileHeight < 112 * k;
        Widget tile(int i, double width) {
          final (icon, title, caption, where) = items[i];
          final sign = Container(
            width: (compact ? 28 : 34) * k,
            height: (compact ? 28 : 34) * k,
            // Dots: an inked square with the sign on the paper's colour
            decoration: homeLookNow == HomeLayout.dots
                ? BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(4))
                : BoxDecoration(shape: BoxShape.circle, color: accent),
            child: Icon(
              icon,
              size: (compact ? 16 : 19) * k,
              color: homeLookNow == HomeLayout.dots
                  ? (dark ? const Color(0xFF151515) : const Color(0xFFEAE9E5))
                  : ContrastPalette.ink,
            ),
          );
          final name = Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
              fontSize: (theme.textTheme.titleSmall?.fontSize ?? 14) * k,
            ),
          );
          final note = Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) * k,
              height: 1.1,
            ),
          );
          return SizedBox(
            width: width,
            // enough for the sign, two lines of the name and two of the caption on a narrow screen
            height: tileHeight,
            child: Material(
              // Bento: a solid tile; Dots: the paper with an inked edge
              color: switch (homeLookNow) {
                HomeLayout.bento => dark ? const Color(0xFF3A3A40) : const Color(0xFFF0F0F2),
                HomeLayout.dots => dark ? const Color(0xFF151515) : const Color(0xFFEAE9E5),
                _ => scheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(switch (homeLookNow) {
                  HomeLayout.bento => 22,
                  HomeLayout.dots => 6,
                  _ => 20,
                }),
                side: switch (homeLookNow) {
                  HomeLayout.bento => BorderSide.none,
                  HomeLayout.dots => BorderSide(color: scheme.onSurface.withValues(alpha: .5)),
                  _ => BorderSide(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
                },
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go(where),
                child: Padding(
                  padding: EdgeInsets.all((compact ? 9 : 12) * k),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                sign,
                                Gap(8 * k),
                                Expanded(child: name),
                              ],
                            ),
                            const Spacer(),
                            note,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [sign, const Spacer(), name, Gap(2 * k), note],
                        ),
                ),
              ),
            ),
          );
        }

        final tiles = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final alone = layout.columns == 2 && i == items.length - 1 && items.length.isOdd;
          tiles.add(tile(i, alone ? box.maxWidth : side));
        }
        return Wrap(spacing: gap, runSpacing: gap, children: tiles);
      },
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
    this.height,
  });

  /// the row's height: the list's share of the screen
  final double? height;

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      // dense: the whole list on one screen, over the panel
      dense: true,
      visualDensity: VisualDensity.compact,
      minTileHeight: height,
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}

/// The settings' block: Contrast's frosted glass (as the home screen's blocks), otherwise an outlined card.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContrastFrost(radius: 20, padding: EdgeInsets.zero, solo: true, child: child);
  }
}
