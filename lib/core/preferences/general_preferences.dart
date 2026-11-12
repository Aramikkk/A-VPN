import 'package:hiddify/features/home/model/dots_accent.dart';
import 'package:hiddify/features/home/model/dots_digits.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/model/ping_graph.dart';
import 'package:hiddify/features/home/model/site_graph.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/actions_at_closing.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/app_based_routing/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/profile/model/profile_sort_enum.dart';
import 'package:hiddify/features/proxy/model/ping_style.dart';
import 'package:hiddify/features/window/notifier/window_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

bool _debugIntroPage = false;

abstract class Preferences {
  static final introCompleted = PreferencesNotifier.create(
    "intro_completed",
    false,
    overrideValue: _debugIntroPage && kDebugMode ? false : null,
  );

  // Null means that auto selection has not been performed yet.
  static final autoAppsSelectionRegion = PreferencesNotifier.create<Region?, String?>(
    "auto_apps_selection_region",
    null,
    mapFrom: (value) => value == null || value.isEmpty ? null : Region.values.byName(value),
    mapTo: (value) => value == null ? '' : value.name,
  );

  static final autoAppsSelectionLastUpdate = PreferencesNotifier.create<DateTime?, String?>(
    "auto_apps_selection_last_update",
    null,
    mapFrom: (value) => value == null ? null : DateTime.tryParse(value),
    mapTo: (value) => value?.toIso8601String(),
  );

  // Set when the user turns auto selection off by hand. Until then it comes on by itself when App-based routing
  // is turned on or its mode changes.
  static final autoAppsSelectionOffByUser = PreferencesNotifier.create<bool, bool>(
    "auto_apps_selection_off_by_user",
    false,
  );

  static final includeApps = PreferencesNotifier.create<List<String>, List<String>>(
    "per_app_proxy_include_list",
    <String>[],
  );

  static final excludeApps = PreferencesNotifier.create<List<String>, List<String>>(
    "per_app_proxy_exclude_list",
    <String>[],
  );

  static final windowMaximized = PreferencesNotifier.create<bool, bool>("window_maximized_v2", false);

  static final windowPosition = PreferencesNotifier.create<Offset?, String?>(
    "window_position_v2",
    null,
    mapFrom: (value) {
      if (value == null) return null;
      final list = value.split(',').map((e) => double.tryParse(e)).toList();
      return Offset(list[0]!, list[1]!);
    },
    mapTo: (value) {
      if (value == null) return null;
      return "${value.dx},${value.dy}";
    },
  );

  static final windowSize = PreferencesNotifier.create<Size, String>(
    "window_size_v2",
    defaultWindowSize,
    mapFrom: (value) {
      final list = value.split(',').map((e) => double.tryParse(e)).toList();
      return Size(list[0]!, list[1]!);
    },
    mapTo: (value) => "${value.width},${value.height}",
  );

  /// The computer's: starts in the tray with no window (on by default; the phone has no such thing).
  static final silentStart = PreferencesNotifier.create<bool, bool>("silent_start", true);

  static final disableMemoryLimit = PreferencesNotifier.create<bool, bool>("disable_memory_limit", true);

  static final perAppProxyEnabled = PreferencesNotifier.create<bool, bool>("per_app_proxy_enabled", false);

  // Kept while App-based routing is off, for when it is turned on again.
  static final perAppProxyMode = PreferencesNotifier.create<AppProxyMode, String>(
    "per_app_proxy_mode",
    AppProxyMode.exclude,
    mapFrom: AppProxyMode.values.byName,
    mapTo: (value) => value.name,
  );

  // The mode in use, or null while App-based routing is off.
  static final perAppProxyModeInUse = Provider<AppProxyMode?>(
    (ref) => ref.watch(perAppProxyEnabled) ? ref.watch(perAppProxyMode) : null,
  );

  static final markNewProfileActive = PreferencesNotifier.create<bool, bool>("mark_new_profile_active", true);

  static final dynamicNotification = PreferencesNotifier.create<bool, bool>("dynamic_notification", true);

  static final autoCheckIp = PreferencesNotifier.create<bool, bool>("auto_check_ip", true);

  static final startedByUser = PreferencesNotifier.create<bool, bool>("started_by_user", false);

  /// AraVPN: connect as soon as the app opens. On from the start on a computer, off on a phone.
  static final connectOnAppStart = PreferencesNotifier.create<bool, bool>("connect_on_app_start", true);

  /// A-VPN (Android): turn the VPN on in the background when the phone starts, even if it was off before
  static final connectOnBoot = PreferencesNotifier.create<bool, bool>("connect_on_boot", true);

  /// A-VPN: ping the servers when the app opens, if the last such ping was half an hour ago or more
  static final autoPingOnOpen = PreferencesNotifier.create<bool, bool>("auto_ping_on_open", true);

  /// no server has answered its ping for a minute: the ping address switches to the next known one
  static final pingAutoSwitch = PreferencesNotifier.create<bool, bool>("ping_auto_switch", true);
  static final lastAutoPing = PreferencesNotifier.create<int, int>("last_auto_ping", 0);

  /// A-VPN: how often the subscription (the server list) updates, in hours; 0: as the subscription says,
  /// -1: never
  static final subUpdateHours = PreferencesNotifier.create<int, int>("sub_update_hours", 6);

  /// More than one subscription at once: the ids of the profiles whose servers are added to the active profile's
  /// (see ProfileMerge). Kept as one ";"-separated string.
  static final extraProfiles = PreferencesNotifier.create<List<String>, String>(
    "extra_profiles",
    const [],
    mapFrom: (value) => value.split(';').where((e) => e.isNotEmpty).toList(),
    mapTo: (value) => value.join(';'),
  );

  /// The subscriptions switched off, not in the work (the Profiles page): their ids. The ones that are on, in the shown
  /// order, are the main one (the top) and the added ones (see profile_work.dart). Kept as one ";"-separated string.
  static final offProfiles = PreferencesNotifier.create<List<String>, String>(
    "off_profiles",
    const [],
    mapFrom: (value) => value.split(';').where((e) => e.isNotEmpty).toList(),
    mapTo: (value) => value.join(';'),
  );

  /// The old way of choosing (one active profile and added ones) has been moved to [offProfiles].
  static final profilesWorkMigrated = PreferencesNotifier.create<bool, bool>("profiles_work_migrated", false);

  /// Special handling of the Sigma Gate provider (its servers named Sigma, its panel asked as Clash Meta). Off: a plain client.
  static final providerSigma = PreferencesNotifier.create<bool, bool>("provider_sigma", false);

  /// The order the user dragged the subscriptions into on the Profiles page: their ids, first to last. Empty: the
  /// order of the chosen sort (choosing a sort clears this). Kept as one ";"-separated string.
  static final profilesOrder = PreferencesNotifier.create<List<String>, String>(
    "profiles_order",
    const [],
    mapFrom: (value) => value.split(';').where((e) => e.isNotEmpty).toList(),
    mapTo: (value) => value.join(';'),
  );

  /// The priority subscription: the id of the profile whose servers the automatic choice keeps to unless the others
  /// are clearly faster (see the margins in ConfigOptions). Empty: none.
  static final priorityProfile = PreferencesNotifier.create<String, String>("priority_profile", "");

  /// Settings → Profile management: the countries of each profile switched off, by network:
  /// {profile id: {"wifi": [codes], "mobile": [codes]}}. Nothing here: every country is on.
  static final profileCountriesOff = PreferencesNotifier.create<Map<String, Map<String, List<String>>>, String>(
    "profile_countries_off",
    const {},
    mapFrom: (value) {
      try {
        return {
          for (final e in (jsonDecode(value) as Map<String, dynamic>).entries)
            e.key: {
              for (final n in (e.value as Map<String, dynamic>).entries) n.key: [...(n.value as List).cast<String>()],
            },
        };
      } catch (_) {
        return const {};
      }
    },
    mapTo: (value) => jsonEncode(value),
  );

  /// Settings → Profile management: the countries outside the region filter (Europe only, World and CIS) that the user
  /// switched on by hand, by profile and network, the same form as [profileCountriesOff]. A choice made by hand wins
  /// over the filter.
  static final profileCountriesOn = PreferencesNotifier.create<Map<String, Map<String, List<String>>>, String>(
    "profile_countries_on",
    const {},
    mapFrom: (value) {
      try {
        return {
          for (final e in (jsonDecode(value) as Map<String, dynamic>).entries)
            e.key: {
              for (final n in (e.value as Map<String, dynamic>).entries) n.key: [...(n.value as List).cast<String>()],
            },
        };
      } catch (_) {
        return const {};
      }
    },
    mapTo: (value) => jsonEncode(value),
  );

  /// The countries each profile had at the last look (at its last update), by profile id: a country not in it is new.
  static final profileCountriesSeen = PreferencesNotifier.create<Map<String, List<String>>, String>(
    "profile_countries_seen_v2",
    const {},
    mapFrom: (value) {
      try {
        return {
          for (final e in (jsonDecode(value) as Map<String, dynamic>).entries)
            e.key: [...(e.value as List).cast<String>()],
        };
      } catch (_) {
        return const {};
      }
    },
    mapTo: (value) => jsonEncode(value),
  );

  /// AraVPN auto-pause (Android): the VPN steps aside while one of [autoPauseApps] is on screen. Read by the
  /// VPN service itself (SettingsKey.AUTO_PAUSE_*), so the list is one ";"-separated string.
  static final autoPauseEnabled = PreferencesNotifier.create<bool, bool>("auto_pause_enabled", true);

  static final autoPauseApps = PreferencesNotifier.create<Set<String>, String>(
    "auto_pause_apps",
    const {
      'ru.gosuslugi.goskey',
      'ru.rostel',
      'ru.gosuslugi.auto',
      'com.valvesoftware.android.steam.community',
      'com.valvesoftware.android.steam.friendsui',
    },
    mapFrom: (value) => value.split(';').where((e) => e.isNotEmpty).toSet(),
    mapTo: (value) => value.join(';'),
  );

  /// AraVPN home Wi-Fi (Android): the VPN pauses on a Wi-Fi whose router runs a VPN of its own. Read by the VPN
  /// service itself (SettingsKey.HOME_WIFI_*); the homes as JSON (see HomeWifiPage).
  static final homeWifiEnabled = PreferencesNotifier.create<bool, bool>("avpn-home-wifi-enabled", true);

  static final homeWifiList = PreferencesNotifier.create<String, String>("avpn-home-wifi-list", "[]");

  /// AraVPN: the accent colour and gradient.
  static final araAccent = PreferencesNotifier.create<AraAccent, String>(
    "ara_accent",
    AraAccent.neonOrange,
    mapFrom: (value) => AraAccent.values.firstWhere((e) => e.name == value, orElse: () => AraAccent.platformDefault),
    mapTo: (value) => value.name,
  );

  /// A-VPN: the look (Contrast, Glass, Graphite or the classic one).
  static final araStyle = PreferencesNotifier.create<AraStyle, String>(
    "ara_style",
    AraStyle.fallback,
    // Editorial's place went to Contrast
    mapFrom: (value) => value == 'editorial'
        ? AraStyle.contrast
        : AraStyle.values.firstWhere((e) => e.name == value, orElse: () => AraStyle.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN: Glass's own colour scheme, when the look is Glass.
  static final glassScheme = PreferencesNotifier.create<GlassScheme, String>(
    "glass_scheme",
    GlassScheme.cornflower,
    mapFrom: (value) => GlassScheme.values.firstWhere((e) => e.name == value, orElse: () => GlassScheme.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN: Contrast's colour (a warm accent and a cool second colour).
  static final contrastPalette = PreferencesNotifier.create<ContrastPalette, String>(
    "contrast_palette",
    ContrastPalette.citrus,
    mapFrom: (value) =>
        ContrastPalette.values.firstWhere((e) => e.name == value, orElse: () => ContrastPalette.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN: the size of everything, in percent (Settings → Themes): a screen far from the eyes, or a small one.
  static final uiScalePercent = PreferencesNotifier.create<int, int>("ui_scale_percent", 100);

  /// A-VPN: the size of the text on top of the system's, in percent.
  static final fontScalePercent = PreferencesNotifier.create<int, int>("font_scale_percent", 100);

  /// A-VPN: how the figures of the Dots style are drawn (the dots of the matrix, bold, wide, solid pixels).
  static final dotsDigits = PreferencesNotifier.create<DotsDigits, String>(
    "dots_digits",
    DotsDigits.wide,
    mapFrom: DotsDigits.fromName,
    mapTo: (value) => value.name,
  );

  /// A-VPN: the Dots style's one colour (its OLED look: black, white and this).
  static final dotsAccent = PreferencesNotifier.create<DotsAccent, String>(
    "dots_accent",
    DotsAccent.fallback,
    mapFrom: DotsAccent.fromName,
    mapTo: (value) => value.name,
  );

  /// A-VPN: the GitHub project (owner/repo) whose releases the program updates itself from (see AraUpdate.repoOf)
  /// The newest crash report the user was offered, by name, so each crash is offered once.
  static final lastSeenCrashReport = PreferencesNotifier.create<String, String>("last_seen_crash_report", "");

  static final updateFolder = PreferencesNotifier.create<String, String>("update_folder", "Aramikkk/hiddify-app");

  /// A-VPN: when the program last looked for an update by itself (milliseconds), once a day
  static final lastUpdateCheck = PreferencesNotifier.create<int, int>("last_update_check", 0);

  /// A-VPN: the build the program last offered by itself (downloaded and opened the installer for): each only once
  static final lastOfferedBuild = PreferencesNotifier.create<int, int>("last_offered_build", 0);

  /// A-VPN: how the Dots ping block draws the answers (the menu of the big ping).
  static final pingGraph = PreferencesNotifier.create<PingGraph, String>(
    "ping_graph",
    PingGraph.bars,
    mapFrom: PingGraph.fromName,
    mapTo: (value) => value.name,
  );

  /// A-VPN: how the Dots sites block shows the delays (the menu a tap on the block opens).
  static final siteGraph = PreferencesNotifier.create<SiteGraph, String>(
    "site_graph",
    SiteGraph.fallback,
    mapFrom: SiteGraph.fromName,
    mapTo: (value) => value.name,
  );

  /// A-VPN: how the home screen is laid out (Contrast).
  // (the defaults over this file are the owner's own settings as of 1.0.72, what a new install starts with)
  static final homeLayout = PreferencesNotifier.create<HomeLayout, String>(
    "home_layout",
    // Dots for a new install (1.0.71); a choice made stays
    HomeLayout.dots,
    mapFrom: HomeLayout.fromName,
    mapTo: (value) => value.name,
  );

  /// A-VPN: Contrast's backdrop.
  static final contrastBackdrop = PreferencesNotifier.create<ContrastBackdrop, String>(
    "contrast_backdrop",
    ContrastBackdrop.fallback,
    mapFrom: (value) =>
        ContrastBackdrop.values.firstWhere((e) => e.name == value, orElse: () => ContrastBackdrop.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN: how see-through Contrast's blocks are.
  static final contrastClarity = PreferencesNotifier.create<ContrastClarity, String>(
    "contrast_clarity",
    ContrastClarity.weak,
    mapFrom: (value) =>
        ContrastClarity.values.firstWhere((e) => e.name == value, orElse: () => ContrastClarity.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN's light version, the look: flat colours, no see-through blocks, no gliding and sliding.
  static final lightLook = PreferencesNotifier.create<bool, bool>("light_look", false);

  /// A-VPN's light version, the background: slower polls, fewer wake-ups while the app is out of sight.
  static final lightBackground = PreferencesNotifier.create<bool, bool>("light_background", false);

  /// The night mode (on by default): with the screen locked the periodic checks sleep (the core's server pings, the
  /// service's watchers) and the polls out of sight go far apart; they wake with the screen.
  static final nightMode = PreferencesNotifier.create<bool, bool>("night_mode", true);

  /// The super light mode: only the home screen (the servers, the statistics block above and the connect panel
  /// below, refreshed every ten seconds); no graphs, topology, site delays or per-app servers, the background
  /// checks cut to a ping of the servers every half hour. The button is on the home screen.
  static final superLight = PreferencesNotifier.create<bool, bool>("super_light", false);

  /// The apps of Settings → Sites (the ones with a server of their own) marked for the home screen's delay block.
  /// "*" (until the user touches a switch): the six services' apps, as the screen always had.
  static final homeApps = PreferencesNotifier.create<List<String>, List<String>>("home_apps", <String>[
    'com.instagram.android',
    'com.whatsapp',
    'org.telegram.messenger',
    'com.openai.chatgpt',
    'com.anthropic.claude',
    'com.google.android.youtube',
  ]);

  /// The order of those apps in Settings → Sites (their packages, dragged up and down) and of the home screen's tiles.
  /// Kept apart from the apps' own list: the connection follows that one and would restart at every drag.
  static final appsOrder = PreferencesNotifier.create<List<String>, List<String>>("apps_order", <String>[
    'com.instagram.android',
    'com.whatsapp',
    'org.telegram.messenger',
    'com.openai.chatgpt',
    'com.google.android.youtube',
    'com.anthropic.claude',
    'com.google.android.apps.bard',
    'com.google.android.apps.docs',
    'com.facebook.katana',
    'com.instagram.barcelona',
    'com.android.vending',
    'ai.perplexity.app.android',
    'com.deepseek.chat',
  ]);

  /// AraVPN: how the server list shows each server's ping.
  static final pingStyle = PreferencesNotifier.create<PingStyle, String>(
    "ping_style",
    PingStyle.barsAndNumbers,
    mapFrom: (value) => PingStyle.values.firstWhere((e) => e.name == value, orElse: () => PingStyle.numbers),
    mapTo: (value) => value.name,
  );

  static final storeReviewedByUser = PreferencesNotifier.create<bool, bool>("store_reviewed_by_user", false);

  static final actionAtClose = PreferencesNotifier.create<ActionsAtClosing, String>(
    "action_at_close",
    ActionsAtClosing.ask,
    mapFrom: ActionsAtClosing.values.byName,
    mapTo: (value) => value.name,
  );

  static final warpConsentGiven = PreferencesNotifier.create<bool, bool>("warp-consent-given", false);

  static final psiphonConsentGiven = PreferencesNotifier.create<bool, bool>("psiphon-consent-given", false);

  /// How many records the in-memory log ring keeps. Saved, so a size picked
  /// once while chasing a bug is still there on the next run.
  static final logBufferSize = PreferencesNotifier.create<int, int>("log-buffer-size", 5000);

  static final profilesSort = PreferencesNotifier.create<({ProfilesSort by, SortMode mode}), String>(
    "profiles_sort",
    (by: ProfilesSort.lastUpdate, mode: SortMode.descending),
    mapFrom: (value) {
      final parts = value.split(":");
      return (by: ProfilesSort.values.byName(parts.first), mode: SortMode.values.byName(parts.last));
    },
    mapTo: (value) => "${value.by.name}:${value.mode.name}",
  );
}
