import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/adaptive_layout/branch_swiper.dart';
import 'package:hiddify/core/router/adaptive_layout/my_adaptive_layout.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/custom_transition.dart';
import 'package:hiddify/core/router/go_router/refresh_listenable.dart';
import 'package:hiddify/features/about/widget/about_page.dart';
import 'package:hiddify/features/app_based_routing/overview/app_list_page.dart';
import 'package:hiddify/features/home/widget/home_page.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:hiddify/features/log/overview/logs_page.dart';
import 'package:hiddify/features/profile/details/profile_details_page.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_page.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_page.dart';
import 'package:hiddify/features/route_rules/notifier/rule_notifier.dart';
import 'package:hiddify/features/route_rules/overview/generic_list_page.dart';
import 'package:hiddify/features/route_rules/overview/package_names_page.dart';
import 'package:hiddify/features/route_rules/overview/rule_page.dart';
import 'package:hiddify/features/settings/overview/sections/chain_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/dns_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/general_page.dart';
import 'package:hiddify/features/settings/overview/sections/inbound_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/ping_page.dart';
import 'package:hiddify/features/settings/overview/sections/routing_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/themes_page.dart';
import 'package:hiddify/features/settings/overview/sections/tls_tricks_page.dart';
import 'package:hiddify/features/settings/overview/settings_page.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/features/stats/widget/speed_page.dart';
import 'package:hiddify/features/stats/widget/topology_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'routing_config_notifier.g.dart';

// each branch in go router has its own focus scope
final branchesScope = <String, FocusScopeNode>{
  'home': FocusScopeNode(),
  'speed': FocusScopeNode(),
  'connections': FocusScopeNode(),
  'topology': FocusScopeNode(),
  'profiles': FocusScopeNode(),
  'settings': FocusScopeNode(),
  'logs': FocusScopeNode(),
  'about': FocusScopeNode(),
};

// when the routing config is not yet initialized, this config is used
final loadingConfig = RoutingConfig(
  routes: <RouteBase>[GoRoute(path: '/home', builder: (context, state) => const Material())],
);

String getNameOfBranch(bool isMobileBreakpoint, bool showProfilesAction, int index) => isMobileBreakpoint
    ? ['connections', 'speed', 'home', 'topology', 'settings'][index]
    : ['home', 'connections', 'topology', if (showProfilesAction) 'profiles', 'settings'][index];

int getIndexOfBranch(bool isMobileBreakpoint, bool showProfilesAction, String name) => isMobileBreakpoint
    ? ['connections', 'speed', 'home', 'topology', 'settings'].indexOf(name)
    : ['home', 'connections', 'topology', if (showProfilesAction) 'profiles', 'settings'].indexOf(name);

@Riverpod(keepAlive: true)
class RoutingConfigNotifier extends _$RoutingConfigNotifier {
  @override
  RoutingConfig build() {
    final isMobileBreakpoint = ref.watch(isMobileBreakpointProvider);
    final bool showProfilesAction;
    if (isMobileBreakpoint == true) {
      showProfilesAction = false;
    } else {
      showProfilesAction = ref.watch(hasAnyProfileProvider).value ?? false;
    }
    if (isMobileBreakpoint == null) return loadingConfig;
    final speedBranch = StatefulShellBranch(
      routes: <GoRoute>[
        GoRoute(
          name: 'speed',
          path: '/speed',
          builder: (_, _) => FocusScope(node: branchesScope['speed'], child: const SpeedPage()),
        ),
      ],
    );
    final connectionsBranch = StatefulShellBranch(
      routes: <GoRoute>[
        GoRoute(
          name: 'connections',
          path: '/connections',
          builder: (_, _) => FocusScope(node: branchesScope['connections'], child: const ConnectionsPage()),
        ),
      ],
    );
    return RoutingConfig(
      redirect: (context, state) {
        // fix path-parameters for deep link
        String? url;
        if (LinkParser.protocols.contains(state.uri.scheme)) {
          // Android & iOS deep link
          url = state.uri.toString();
        } else if (PlatformUtils.isDesktop && newUrlFromAppLink.isNotEmpty) {
          // Desktops deep link
          url = newUrlFromAppLink;
          newUrlFromAppLink = '';
        } else if (state.uri.queryParameters['url'] != null) {
          // Get the configured URL for intro
          url = state.uri.queryParameters['url'];
        }

        if (!ref.read(Preferences.introCompleted)) {
          // Intro is not completed
          return url != null ? '/intro?url=$url' : '/intro';
        } else if (state.matchedLocation == '/intro') {
          // Intro is completed
          // Current page in '/intro'
          if (url != null && Uri.parse(url).host == 'import') {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) =>
                  ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(url: url, triggeredByDeepLink: true),
            );
          }
          return '/home';
        } else if (url != null && Uri.parse(url).host == 'import') {
          // Auto import profile from url
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(url: url, triggeredByDeepLink: true),
          );
          return '/home';
        } else if (url != null) {
          final uri = Uri.parse(url);
          final path = uri.path + (uri.hasQuery ? "?${uri.query}" : "");
          return path;
        } else if (state.matchedLocation.contains('chain-options') &&
            (ref.watch(hasAnyProfileProvider).value == false)) {
          // Prevent showing chainOptions while hasAnyProfile == false
          return '/settings';
        }
        return null;
      },
      routes: <RouteBase>[
        StatefulShellRoute(
          builder: (_, _, navigationShell) => MyAdaptiveLayout(
            navigationShell: navigationShell,
            isMobileBreakpoint: isMobileBreakpoint,
            showProfilesAction: showProfilesAction,
          ),
          // the phone's tabs slide and follow a swipe; the computer's fade in
          navigatorContainerBuilder: (context, navigationShell, children) => isMobileBreakpoint
              ? BranchSwiper(navigationShell: navigationShell, children: children)
              : BranchFader(navigationShell: navigationShell, children: children),
          branches: <StatefulShellBranch>[
            // the phone: Connections and Statistics left of Home, which sits in the middle and opens first
            if (isMobileBreakpoint) ...[connectionsBranch, speedBranch],
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'home',
                  path: '/home',
                  builder: (_, _) => FocusScope(node: branchesScope['home'], child: const HomePage()),
                  routes: <GoRoute>[
                    GoRoute(
                      name: 'proxies',
                      path: 'proxies',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.fade, state.pageKey, const ProxiesOverviewPage()),
                    ),
                    if (isMobileBreakpoint)
                      GoRoute(
                        name: 'profileDetails',
                        path: 'profile-details/:id',
                        pageBuilder: (_, state) => customTransition(
                          TransitionType.fade,
                          state.pageKey,
                          ProfileDetailsPage(id: state.pathParameters['id']!),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // the desktop: Connections right after Home (Statistics is its sidebar)
            if (!isMobileBreakpoint) connectionsBranch,
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'topology',
                  path: '/topology',
                  builder: (_, _) => FocusScope(node: branchesScope['topology'], child: const TopologyPage()),
                ),
              ],
            ),
            if (showProfilesAction)
              StatefulShellBranch(
                routes: <GoRoute>[
                  GoRoute(
                    name: 'profiles',
                    path: '/profiles',
                    builder: (_, _) => FocusScope(node: branchesScope['profiles'], child: const ProfilesPage()),
                    routes: <GoRoute>[
                      GoRoute(
                        name: 'profileDetails',
                        path: 'profile-details/:id',
                        pageBuilder: (_, state) => customTransition(
                          TransitionType.fade,
                          state.pageKey,
                          ProfileDetailsPage(id: state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'settings',
                  path: '/settings',
                  builder: (_, _) => FocusScope(node: branchesScope['settings'], child: settingsWidth(SettingsPage())),
                  routes: <GoRoute>[
                    // the profiles, from Settings, where there's no tab of their own (the phone, or no profile yet)
                    if (!showProfilesAction)
                      GoRoute(
                        name: 'profiles',
                        path: 'profiles',
                        pageBuilder: (_, state) =>
                            customTransition(TransitionType.fade, state.pageKey, const ProfilesPage()),
                        routes: <GoRoute>[
                          GoRoute(
                            name: 'profileDetails',
                            path: 'profile-details/:id',
                            pageBuilder: (_, state) => customTransition(
                              TransitionType.fade,
                              state.pageKey,
                              ProfileDetailsPage(id: state.pathParameters['id']!),
                            ),
                          ),
                        ],
                      ),
                    GoRoute(
                      name: 'general',
                      path: 'general',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, settingsWidth(const GeneralPage())),
                    ),
                    GoRoute(
                      name: 'connectionOptions',
                      path: 'connection-options',
                      pageBuilder: (_, state) => customTransition(
                        TransitionType.slide,
                        state.pageKey,
                        settingsWidth(const GeneralPage(connection: true)),
                      ),
                    ),
                    GoRoute(
                      name: 'serversOptions',
                      path: 'servers-options',
                      pageBuilder: (_, state) => customTransition(
                        TransitionType.slide,
                        state.pageKey,
                        settingsWidth(const ServersOptionsPage()),
                      ),
                    ),
                    GoRoute(
                      name: 'pingOptions',
                      path: 'ping-options',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, settingsWidth(const PingPage())),
                    ),
                    GoRoute(
                      name: 'themes',
                      path: 'themes',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, settingsWidth(const ThemesPage())),
                    ),
                    GoRoute(
                      name: 'routingOptions',
                      path: 'routing-options',
                      pageBuilder: (_, state) => customTransition(
                        TransitionType.slide,
                        state.pageKey,
                        settingsWidth(RoutingOptionsPage(routeRule: state.uri.queryParameters['routeRule'])),
                      ),
                      routes: <GoRoute>[
                        GoRoute(
                          name: 'rule',
                          path: 'rule/:orderId',
                          pageBuilder: (_, state) {
                            final orderIdString = state.pathParameters['orderId']!;
                            return customTransition(
                              TransitionType.slide,
                              state.pageKey,
                              settingsWidth(
                                RulePage(ruleListOrder: orderIdString != 'new' ? int.tryParse(orderIdString) : null),
                              ),
                            );
                          },
                          onExit: (context, state) async {
                            final t = ref.read(translationsProvider).requireValue;
                            final orderId = int.tryParse(state.pathParameters['orderId']!);
                            final isRuleEdited = ref.read(IsRuleEditedProvider(orderId));
                            if (orderId != null && isRuleEdited) {
                              await ref.read(ruleNotifierProvider(orderId).notifier).save();
                              ref
                                  .read(inAppNotificationControllerProvider)
                                  .showSuccessToast(t.common.msg.autoSave.success);
                            }
                            return true;
                          },
                          routes: <GoRoute>[
                            GoRoute(
                              name: 'genericList',
                              path: 'generic-list/:ruleEnum',
                              pageBuilder: (_, state) {
                                final orderId = int.tryParse(state.pathParameters['orderId']!);
                                final ruleEnum = RuleEnum.values.byName(state.pathParameters['ruleEnum']!);
                                return customTransition(
                                  TransitionType.slide,
                                  state.pageKey,
                                  settingsWidth(GenericListPage(ruleListOrder: orderId, ruleEnum: ruleEnum)),
                                );
                              },
                            ),
                            GoRoute(
                              name: 'packageNames',
                              path: 'package-names',
                              pageBuilder: (_, state) => customTransition(
                                TransitionType.slide,
                                state.pageKey,
                                settingsWidth(
                                  PackageNamesPage(ruleListOrder: int.tryParse(state.pathParameters['orderId']!)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        GoRoute(
                          name: 'appList',
                          path: 'app-list',
                          pageBuilder: (_, state) =>
                              customTransition(TransitionType.slide, state.pageKey, settingsWidth(const AppListPage())),
                        ),
                      ],
                    ),
                    GoRoute(
                      name: 'dnsOptions',
                      path: 'dns-options',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, settingsWidth(const DnsOptionsPage())),
                    ),
                    GoRoute(
                      name: 'inboundOptions',
                      path: 'inbound-options',
                      pageBuilder: (_, state) => customTransition(
                        TransitionType.slide,
                        state.pageKey,
                        settingsWidth(const InboundOptionsPage()),
                      ),
                    ),
                    GoRoute(
                      name: 'tlsTricks',
                      path: 'tls-tricks',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, settingsWidth(const TlsTricksPage())),
                    ),
                    GoRoute(
                      name: 'chainOptions',
                      path: 'chain-options',
                      pageBuilder: (_, state) => customTransition(
                        TransitionType.slide,
                        state.pageKey,
                        settingsWidth(const ChainOptionsPage()),
                      ),
                    ),
                    // the logs and About are on the settings list everywhere, the computer's side menu included
                    ...[
                      GoRoute(
                        name: 'logs',
                        path: 'logs',
                        pageBuilder: (_, state) =>
                            customTransition(TransitionType.slide, state.pageKey, settingsWidth(const LogsPage())),
                      ),
                      GoRoute(
                        name: 'about',
                        path: 'about',
                        pageBuilder: (_, state) =>
                            customTransition(TransitionType.slide, state.pageKey, settingsWidth(const AboutPage())),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(name: 'intro', path: '/intro', builder: (_, _) => const IntroPage()),
      ],
    );
  }
}

/// The settings in a column the width of a phone or tablet in the middle of a computer's window, as on the
/// phone, rather than stretched across it.
Widget settingsWidth(Widget page) => !PlatformUtils.isDesktop
    ? page
    : Builder(
        builder: (context) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: page),
          ),
        ),
      );
