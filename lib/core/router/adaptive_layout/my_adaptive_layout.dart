import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/adaptive_layout/nav_icons.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/routing_config_notifier.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/home/widget/freeze_frame.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
    required this.showProfilesAction,
  });
  // managed by go router(Shell Route)
  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;
  final bool showProfilesAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // keeps a minute of speed samples, so the Speed tab's graph is full when it opens
    ref.listen(speedHistoryProvider, (_, _) {});
    // and adds up the session's traffic across the core's reloads, also while the panel isn't shown
    ref.listen(sessionTotalsProvider, (_, _) {});
    // focus switch management
    final primaryFocusHash = useState<int?>(null);
    final navScopeNode = useFocusScopeNode();
    useEffect(() {
      bool handler(KeyEvent event) {
        // a computer: Esc goes back (a page opened over a tab, else Home), Ctrl+1..5 open the menu's pages
        if (PlatformUtils.isDesktop && event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape)
            return _back(context, isMobileBreakpoint, showProfilesAction);
          if (HardwareKeyboard.instance.isControlPressed) {
            const digits = [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
              LogicalKeyboardKey.digit5,
            ];
            final index = digits.indexOf(event.logicalKey);
            if (index >= 0 && index < _actions(t, showProfilesAction, isMobileBreakpoint).length) {
              _onTap(context, index);
              return true;
            }
          }
        }
        final arrows = isMobileBreakpoint ? KeyboardConst.verticalArrows : KeyboardConst.horizontalArrows;
        if (!arrows.contains(event.logicalKey)) return false;
        if (event is KeyDownEvent) {
          primaryFocusHash.value = FocusManager.instance.primaryFocus.hashCode;
        } else {
          // focus node does not change => true.
          if (primaryFocusHash.value == FocusManager.instance.primaryFocus.hashCode) {
            if (branchesScope.values.any((node) => node.hasFocus)) {
              navScopeNode.requestFocus();
            } else if (navScopeNode.hasFocus) {
              branchesScope[getNameOfBranch(isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex)]
                  ?.requestFocus();
            }
          }
        }
        return true;
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () {
        HardwareKeyboard.instance.removeHandler(handler);
      };
    }, [isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex]);
    // Owns the system back press for the whole shell.
    //
    // It has to sit here, on the visible shell, and nowhere else. A PopScope
    // inside a branch stays mounted after the user leaves that branch, and go
    // router then lets it answer presses meant for another branch, which locks
    // the back button for good (flutter/flutter#193098).
    //
    // canPop is always false so the platform always routes the press to us.
    // Otherwise Android closes the app without calling into Flutter at all, and
    // no callback of ours ever runs. A press that a branch can handle is popped
    // by go router before it reaches here, so this only sees presses at the
    // root of a branch.
    final glass = Theme.of(context).glassLook;
    final contrastPhone = isMobileBreakpoint;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rail = FocusScope(
      node: navScopeNode,
      child: NavigationRail(
        extended: Breakpoint(context).isDesktop(),
        destinations: _navRailDests(_actions(t, showProfilesAction, isMobileBreakpoint)),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        trailing: Breakpoint(context).isDesktop()
            ? const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  // scrolls when the window is too short for the whole panel
                  child: SingleChildScrollView(
                    // 15% wider than it was (248)
                    child: SizedBox(width: 285, child: SideBarStatsOverview()),
                  ),
                ),
              )
            : null,
      ),
    );
    // the page is held as a picture while a popup opens and closes over it (see [FreezeFrame])
    return FreezeFrame(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final homeIndex = getIndexOfBranch(isMobileBreakpoint, showProfilesAction, 'home');
          if (navigationShell.currentIndex != homeIndex) {
            // on another branch: go home instead of closing the app
            navigationShell.goBranch(homeIndex);
          } else {
            // already home: this is the way out of the app
            SystemNavigator.pop();
          }
        },
        // Keeps the claim above alive on the platform side.
        //
        // Every branch navigator broadcasts whether it can handle a back press,
        // and the last broadcast wins. Popping a page inside a branch leaves it
        // reporting "cannot handle", which reaches Android and makes it close the
        // app on the next press without ever calling Flutter. The PopScope above
        // always handles the press, so that report is wrong: replace it.
        child: NotificationListener<NavigationNotification>(
          onNotification: (notification) {
            if (notification.canHandlePop) return false;
            const NavigationNotification(canHandlePop: true).dispatch(context);
            return true;
          },
          child: Material(
            type: glass != null ? MaterialType.transparency : MaterialType.canvas,
            child: Scaffold(
              // Contrast: the panel's colour under everything, so the system's gesture strip under the menu is of a
              // piece with it (it showed the page's grey there)
              // (the home screen's look sets the panel's colour: Bento's and Dots' own)
              backgroundColor: contrastPhone
                  ? (ref.watch(Preferences.homeLayout).index >= 0 ? contrastPanelColor(dark) : null)
                  : null,
              body: contrastPhone
                  ? Listener(
                      // a computer: the mouse's back button goes back
                      onPointerDown: (event) {
                        if (PlatformUtils.isDesktop && event.buttons & kBackMouseButton != 0) {
                          _back(context, isMobileBreakpoint, showProfilesAction);
                        }
                      },
                      child: ContrastGlow(
                        child: Flex(
                          direction: ContrastShellDock.sideways(context) ? Axis.horizontal : Axis.vertical,
                          children: [
                            Expanded(
                              child: Theme(
                                data: contrastPageTheme(Theme.of(context), ref.watch(Preferences.contrastClarity)),
                                child: navigationShell,
                              ),
                            ),
                            ContrastShellDock(side: ContrastShellDock.sideways(context)),
                          ],
                        ),
                      ),
                    )
                  : isMobileBreakpoint
                  ? navigationShell
                  : Row(
                      children: [
                        // Glass: the menu and the stats on a pane of glass, floating over the backdrop
                        if (glass != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                            child: GlassPane(look: glass, radius: 26, child: rail),
                          )
                        else
                          rail,
                        Expanded(child: navigationShell),
                      ],
                    ),
              // Glass: the menu floats under the page as a pane of glass, the backdrop round it
              // the super light mode: only the home screen, so no menu
              bottomNavigationBar: ref.watch(superLightProvider)
                  ? null
                  : isMobileBreakpoint && glass != null
                  ? FocusScope(
                      node: navScopeNode,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: GlassPane(
                            look: glass,
                            radius: 34,
                            // room inside the pane's ends, so the first and the last tab's pill sit as far from its
                            // edge as the pills are from each other
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            // icons only, the chosen tab on a pill of the scheme's colour, as in the preview; its icon in the
                            // text's colour, readable on the pill
                            child: NavigationBarTheme(
                              data: NavigationBarTheme.of(context).copyWith(
                                iconTheme: WidgetStateProperty.resolveWith(
                                  (s) => IconThemeData(
                                    color: s.contains(WidgetState.selected)
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              child: NavigationBar(
                                height: 64,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                                indicatorColor: glass.tint(
                                  Theme.of(context).colorScheme.onSurface,
                                  glass.dark ? .28 : .75,
                                ),
                                indicatorShape: const StadiumBorder(),
                                selectedIndex: navigationShell.currentIndex <= 4 ? navigationShell.currentIndex : 2,
                                destinations: _navDests(_actions(t, showProfilesAction, isMobileBreakpoint)),
                                onDestinationSelected: (index) => _onTap(context, index),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : isMobileBreakpoint
                  ? FocusScope(
                      node: navScopeNode,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(),
                        // Contrast: three tabs, Statistics, Home and Topology (the branches 1 to 3); Connections come up
                        // with a long swipe up on the home screen, Settings down with one down (or the cog by the "+")
                        child: NavigationBar(
                          // a lower menu, of a piece with the panel over it (white by day, black by night); flat
                          height: 62,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: contrastPanelColor(dark),
                          // the phone: Connections and Settings (reached by swipes, not in the menu) keep Home lit; a
                          // computer has no swipes, so every page is in its menu, where it can be seen
                          selectedIndex: PlatformUtils.isDesktop
                              ? navigationShell.currentIndex
                              : switch (navigationShell.currentIndex) {
                                  1 => 0,
                                  3 => 2,
                                  _ => 1,
                                },
                          destinations: _navDests(
                            PlatformUtils.isDesktop
                                ? _actions(t, showProfilesAction, isMobileBreakpoint)
                                : _actions(t, showProfilesAction, isMobileBreakpoint).sublist(1, 4),
                          ),
                          onDestinationSelected: (index) =>
                              _onTap(context, PlatformUtils.isDesktop ? index : index + 1),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Back on a computer (Esc, the mouse's back button): the page opened over a tab, else to Home.
  bool _back(BuildContext context, bool isMobileBreakpoint, bool showProfilesAction) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return true;
    }
    final home = getIndexOfBranch(isMobileBreakpoint, showProfilesAction, 'home');
    if (navigationShell.currentIndex == home) return false;
    navigationShell.goBranch(home);
    return true;
  }

  // shell route action onTap
  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  // in the branches' order: the phone's Connections, Statistics, Home, Topology, Settings; the desktop's Home,
  // Connections, Topology, Profiles, Settings
  List<ShellRouteAction> _actions(Translations t, bool showProfilesAction, bool isMobileBreakpoint) => [
    if (isMobileBreakpoint) ...[
      ShellRouteAction(Icons.list_alt_rounded, t.avpn.connectionsTab, svg: NavIcons.connections),
      ShellRouteAction(Icons.speed_rounded, t.avpn.speedTab, svg: NavIcons.stats),
    ],
    ShellRouteAction(Icons.power_settings_new_rounded, t.pages.home.title, svg: NavIcons.home),
    if (!isMobileBreakpoint)
      ShellRouteAction(Icons.list_alt_rounded, t.avpn.connectionsTab, svg: NavIcons.connections),
    ShellRouteAction(Icons.hub_rounded, t.avpn.topologyTab, svg: NavIcons.topology),
    if (showProfilesAction && !isMobileBreakpoint)
      ShellRouteAction(Icons.view_list_rounded, t.pages.profiles.title, svg: NavIcons.profiles),
    ShellRouteAction(Icons.settings_rounded, t.pages.settings.title, svg: NavIcons.settings),
  ];

  Widget _icon(ShellRouteAction e, {bool selected = false}) =>
      e.svg == null ? Icon(e.icon) : NavIcon(e.svg!, selected: selected);

  List<NavigationDestination> _navDests(List<ShellRouteAction> actions) => actions
      .map((e) => NavigationDestination(icon: _icon(e), selectedIcon: _icon(e, selected: true), label: e.title))
      .toList();
  List<NavigationRailDestination> _navRailDests(List<ShellRouteAction> actions) => actions
      .map(
        (e) => NavigationRailDestination(icon: _icon(e), selectedIcon: _icon(e, selected: true), label: Text(e.title)),
      )
      .toList();
}

/// The pages over Contrast's suns: see-through, their cards and blocks frosted panes the light shows through; the
/// dialogs, sheets and menus they open stay solid.
ThemeData contrastPageTheme(ThemeData theme, [ContrastClarity clarity = ContrastClarity.medium]) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  // the cards as see-through as the blocks, as chosen in Settings → Themes (a level above or below them for the
  // lighter and the deeper containers)
  // a single card as see-through as the home screen's block with its tiles together (about three quarters of
  // the chosen clarity): the same look on every page
  Color pane(double level) => dark
      ? ContrastColours.active.pane(true).withValues(alpha: (clarity.night * .72 * level).clamp(0, .97))
      : Colors.white.withValues(alpha: (clarity.day * .72 * level).clamp(0, .97));
  return theme.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    cardTheme: theme.cardTheme.copyWith(
      color: pane(1),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
      ),
    ),
    colorScheme: scheme.copyWith(
      surface: Colors.transparent,
      surfaceContainerLowest: pane(.85),
      surfaceContainerLow: pane(1),
      surfaceContainer: pane(1.05),
      surfaceContainerHigh: pane(1.1),
      surfaceContainerHighest: pane(1.15),
    ),
    // what opens over the page stays solid
    dialogTheme: theme.dialogTheme.copyWith(backgroundColor: scheme.surfaceContainerHigh),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
    ),
    popupMenuTheme: theme.popupMenuTheme.copyWith(color: scheme.surfaceContainer),
    menuTheme: MenuThemeData(
      style: (theme.menuTheme.style ?? const MenuStyle()).copyWith(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
      ),
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(backgroundColor: scheme.inverseSurface),
  );
}
