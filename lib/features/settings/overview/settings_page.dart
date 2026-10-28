import 'package:flutter/material.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
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
      // the sections in one outlined block, so the list reads as a whole; its rows share the screen's height, so it
      // fills it exactly (on a short screen they keep their usual height and the list scrolls)
      body: LayoutBuilder(
        builder: (context, box) {
          final rows = 11 + (PlatformUtils.isIOS ? 1 : 0);
          final row = ((box.maxHeight - 14) / rows).clamp(44.0, 72.0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              _Frame(
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      // TipCard(message: t.settings.experimentalMsg),
                      SettingsSection(
                        height: row,
                        title: t.pages.profiles.title,
                        icon: Icons.view_list_rounded,
                        namedLocation: context.namedLocation('profiles'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.avpn.profileManagement,
                        icon: Icons.tune_rounded,
                        namedLocation: context.namedLocation('profileManagement'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.pages.settings.general.title,
                        icon: Icons.layers_rounded,
                        namedLocation: context.namedLocation('general'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.avpn.settingsConnection,
                        icon: Icons.power_settings_new_rounded,
                        namedLocation: context.namedLocation('connectionOptions'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.avpn.themes,
                        icon: Icons.palette_rounded,
                        namedLocation: context.namedLocation('themes'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.pages.settings.routing.title,
                        icon: Icons.route_rounded,
                        namedLocation: context.namedLocation('routingOptions'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.avpn.settingsServers,
                        icon: Icons.dns_outlined,
                        namedLocation: context.namedLocation('serversOptions'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.avpn.pingSettings,
                        icon: Icons.network_ping_rounded,
                        namedLocation: context.namedLocation('pingOptions'),
                      ),
                      // each site and chosen app through its own server (beta); DNS is under Inbound now
                      SettingsSection(
                        height: row,
                        title: t.avpn.pingSites,
                        icon: Icons.alt_route_rounded,
                        namedLocation: context.namedLocation('sitesOptions'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.avpn.adBlock,
                        icon: Icons.block_rounded,
                        namedLocation: context.namedLocation('adBlockOptions'),
                      ),
                      SettingsSection(
                        height: row,
                        title: t.pages.settings.inbound.title,
                        icon: Icons.input_rounded,
                        namedLocation: context.namedLocation('inboundOptions'),
                      ),
                      if (PlatformUtils.isIOS)
                        Material(
                          child: ListTile(
                            title: Text(t.pages.settings.resetTunnel),
                            leading: const Icon(Icons.autorenew_rounded),
                            onTap: () async {
                              await ref.read(resetTunnelNotifierProvider.notifier).run();
                            },
                          ),
                        ),
                      // the logs and About are in General now
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
