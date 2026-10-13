import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/actions_at_closing.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/app_based_routing/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/profile/model/profile_sort_enum.dart';
import 'package:hiddify/features/proxy/model/ping_style.dart';
import 'package:hiddify/features/window/notifier/window_notifier.dart';
import 'package:hiddify/utils/platform_utils.dart';
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

  static final windowMaximized = PreferencesNotifier.create<bool, bool>("window_maximized", false);

  static final windowPosition = PreferencesNotifier.create<Offset?, String?>(
    "window_position",
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
    "window_size",
    defaultWindowSize,
    mapFrom: (value) {
      final list = value.split(',').map((e) => double.tryParse(e)).toList();
      return Size(list[0]!, list[1]!);
    },
    mapTo: (value) => "${value.width},${value.height}",
  );

  static final silentStart = PreferencesNotifier.create<bool, bool>("silent_start", false);

  static final disableMemoryLimit = PreferencesNotifier.create<bool, bool>(
    "disable_memory_limit",
    // disable memory limit on desktop by default
    PlatformUtils.isDesktop,
  );

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

  /// A-VPN: connect as soon as the app opens (Android; the desktop restores the last session instead).
  static final connectOnAppStart = PreferencesNotifier.create<bool, bool>("connect_on_app_start", false);

  /// A-VPN (Android): turn the VPN on in the background when the phone starts, even if it was off before
  static final connectOnBoot = PreferencesNotifier.create<bool, bool>("connect_on_boot", false);

  /// A-VPN: ping the servers when the app opens, if the last such ping was half an hour ago or more
  static final autoPingOnOpen = PreferencesNotifier.create<bool, bool>("auto_ping_on_open", true);
  static final lastAutoPing = PreferencesNotifier.create<int, int>("last_auto_ping", 0);

  /// A-VPN: how often the subscription (the server list) updates, in hours; 0: as the subscription says,
  /// -1: never
  static final subUpdateHours = PreferencesNotifier.create<int, int>("sub_update_hours", 0);

  /// A-VPN auto-pause (Android): the VPN steps aside while one of [autoPauseApps] is on screen. Read by the
  /// VPN service itself (SettingsKey.AUTO_PAUSE_*), so the list is one ";"-separated string.
  static final autoPauseEnabled = PreferencesNotifier.create<bool, bool>("auto_pause_enabled", false);

  static final autoPauseApps = PreferencesNotifier.create<Set<String>, String>(
    "auto_pause_apps",
    const {},
    mapFrom: (value) => value.split(';').where((e) => e.isNotEmpty).toSet(),
    mapTo: (value) => value.join(';'),
  );

  /// A-VPN: the accent colour and gradient.
  static final araAccent = PreferencesNotifier.create<AraAccent, String>(
    "ara_accent",
    AraAccent.platformDefault,
    mapFrom: (value) => AraAccent.values.firstWhere((e) => e.name == value, orElse: () => AraAccent.platformDefault),
    mapTo: (value) => value.name,
  );

  /// A-VPN: the look (Graphite, Editorial or the classic one).
  static final araStyle = PreferencesNotifier.create<AraStyle, String>(
    "ara_style",
    AraStyle.fallback,
    mapFrom: (value) => AraStyle.values.firstWhere((e) => e.name == value, orElse: () => AraStyle.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN: Glass's own colour scheme, when the look is Glass.
  static final glassScheme = PreferencesNotifier.create<GlassScheme, String>(
    "glass_scheme",
    GlassScheme.fallback,
    mapFrom: (value) => GlassScheme.values.firstWhere((e) => e.name == value, orElse: () => GlassScheme.fallback),
    mapTo: (value) => value.name,
  );

  /// A-VPN: how the server list shows each server's ping.
  static final pingStyle = PreferencesNotifier.create<PingStyle, String>(
    "ping_style",
    PingStyle.numbers,
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
  static final logBufferSize = PreferencesNotifier.create<int, int>("log-buffer-size", 1000);

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
