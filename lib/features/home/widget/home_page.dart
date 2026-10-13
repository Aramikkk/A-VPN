import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/widget/app_logo.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/stats/widget/traffic_panel.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;

    // Graphite: a soft glow in the accent colour from the top, behind the app bar and both columns of an unfolded
    // phone
    final graphite = theme.araLook.style == AraStyle.graphite;
    final scaffold = Scaffold(
      backgroundColor: graphite ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: graphite ? Colors.transparent : null,
        // leading: (RootScaffold.stateKey.currentState?.hasDrawer ?? false) && showDrawerButton(context)
        //     ? DrawerButton(
        //         onPressed: () {
        //           RootScaffold.stateKey.currentState?.openDrawer();
        //         },
        //       )
        //     : null,
        title: Row(
          children: [
            const AppLogo(size: 24),
            const Gap(8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: t.common.appTitle),
                  const TextSpan(text: " "),
                  const WidgetSpan(child: AppVersionLabel(), alignment: PlaceholderAlignment.middle),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // IconButton(
          //     onPressed: () => const QuickSettingsRoute().push(context),
          //     icon: const Icon(FluentIcons.options_24_filled),
          //     material: (context, platform) => MaterialIconButtonData(
          //           tooltip: t.config.quickSettings,
          //         )),
          // IconButton(
          //     onPressed: () => const AddProfileRoute().push(context),
          //     icon: const Icon(FluentIcons.add_circle_24_filled),
          //     material: (context, platform) => MaterialIconButtonData(
          //           tooltip: t.profile.add.buttonText,
          //         )),
          Semantics(
            key: const ValueKey("profile_add_button"),
            label: t.pages.profiles.add,
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
              onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // an unfolded phone (a Fold is ~750 dp wide) or a tablet: the servers on the left, the statistics on the right
          if (!PlatformUtils.isDesktop && constraints.maxWidth >= 700) {
            // the right column mirrors the left one: a heading like "Current provider", the same outer margin, and
            // the panel stretched to end level with the connection card (when the screen is tall enough for it)
            final heading = Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                t.avpn.trafficThisSession.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2),
              ),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // the servers on the left, the whole list; where the traffic goes on the right (the speed and the
                // ping are on the Statistics tab)
                const Expanded(flex: 11, child: AraHomeBody(traffic: false)),
                Expanded(
                  flex: 9,
                  child: Padding(
                    // level with the left column: its top on the session line's, its foot on the connect panel's
                    padding: const EdgeInsets.fromLTRB(0, 2, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading,
                        const Expanded(child: TrafficPanel()),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // the phone layout's width on a tablet; a computer window uses the room it has
                maxWidth: PlatformUtils.isDesktop ? 1000 : 600,
              ),
              child: const AraHomeBody(),
            ),
          );
        },
      ),
    );
    // no glow on a true black (or white) OLED screen
    final pure = theme.scaffoldBackgroundColor == Colors.black || theme.scaffoldBackgroundColor == Colors.white;
    if (!graphite || pure) {
      return scaffold;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        gradient: RadialGradient(
          center: const Alignment(0, -1.25),
          radius: 1.25,
          colors: [
            Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: theme.brightness == Brightness.dark ? .2 : .1),
              theme.scaffoldBackgroundColor,
            ),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: scaffold,
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
