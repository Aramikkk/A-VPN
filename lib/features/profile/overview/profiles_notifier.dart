import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_repository.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/model/profile_sort_enum.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profiles_notifier.g.dart';

@riverpod
class ProfilesSortNotifier extends _$ProfilesSortNotifier with AppLogger {
  @override
  ({ProfilesSort by, SortMode mode}) build() => ref.watch(Preferences.profilesSort);

  void changeSort(ProfilesSort sortBy) {
    ref.read(Preferences.profilesSort.notifier).update((
      by: sortBy,
      mode: switch (sortBy) {
        ProfilesSort.name => SortMode.ascending, // A → Z
        ProfilesSort.lastUpdate => SortMode.descending, // newest first
      },
    ));
  }

  void toggleMode() {
    final current = ref.read(Preferences.profilesSort);
    ref.read(Preferences.profilesSort.notifier).update((
      by: current.by,
      mode: current.mode == SortMode.ascending ? SortMode.descending : SortMode.ascending,
    ));
  }
}

@riverpod
class ProfilesNotifier extends _$ProfilesNotifier with AppLogger {
  @override
  Stream<List<ProfileEntity>> build() {
    final sort = ref.watch(profilesSortNotifierProvider);
    return _profilesRepo.watchAll(sort: sort.by, sortMode: sort.mode).map((event) => event.getOrElse((l) => throw l));
  }

  ProfileRepository get _profilesRepo => ref.read(profileRepositoryProvider).requireValue;

  Future<Unit> selectActiveProfile(String id) async {
    loggy.debug('changing active profile to: [$id]');
    // the active profile is the base; it isn't one of the added ones
    await _dropExtra(id);
    await ref.read(hapticServiceProvider.notifier).lightImpact();
    return _profilesRepo.setAsActive(id).getOrElse((err) {
      loggy.warning('failed to set [$id] as active profile', err);
      throw err;
    }).run();
  }

  Future<void> _dropExtra(String id) async {
    final extras = ref.read(Preferences.extraProfiles);
    if (extras.contains(id)) await ref.read(Preferences.extraProfiles.notifier).update([...extras]..remove(id));
  }

  /// Adds the profile's servers to the active profile's (or takes them out again): several subscriptions at once.
  /// The config is made at the start, so a running VPN is restarted to take it.
  Future<void> toggleExtra(ProfileEntity profile) async {
    final extras = ref.read(Preferences.extraProfiles);
    final on = extras.contains(profile.id);
    loggy.debug('profile [${profile.id}] as an extra one: ${!on}');
    await ref
        .read(Preferences.extraProfiles.notifier)
        .update(on ? ([...extras]..remove(profile.id)) : [...extras, profile.id]);
    final active = await ref.read(activeProfileProvider.future);
    if (active != null && ref.read(connectionNotifierProvider).valueOrNull is Connected) {
      await ref.read(connectionNotifierProvider.notifier).reconnect(active);
    }
  }

  /// The priority subscription: its servers are kept to unless the others are clearly faster (or the choice is taken
  /// off it again). The core makes its choice at the start, so a running VPN is restarted to take it.
  Future<void> togglePriority(ProfileEntity profile) async {
    final on = ref.read(Preferences.priorityProfile) == profile.id;
    loggy.debug('profile [${profile.id}] as the priority one: ${!on}');
    await ref.read(Preferences.priorityProfile.notifier).update(on ? '' : profile.id);
    final active = await ref.read(activeProfileProvider.future);
    if (active != null && ref.read(connectionNotifierProvider).valueOrNull is Connected) {
      await ref.read(connectionNotifierProvider.notifier).reconnect(active);
    }
  }

  Future<void> togglePin(ProfileEntity profile) async {
    loggy.debug('toggling pin for profile: [${profile.id}] -> ${!profile.pinned}');
    await _profilesRepo.setPinned(profile.id, !profile.pinned).getOrElse((err) {
      loggy.warning('failed to toggle pin for [${profile.id}]', err);
      throw err;
    }).run();
  }

  Future<void> deleteProfile(ProfileEntity profile) async {
    loggy.debug('deleting profile: ${profile.name}');

    if (profile.active) await ref.read(connectionNotifierProvider.notifier).abortConnection();
    await _dropExtra(profile.id);
    await _profilesRepo
        .deleteById(profile.id, profile.active)
        .match(
          (err) {
            loggy.warning('failed to delete profile', err);
            throw err;
          },
          (_) async {
            loggy.info('successfully deleted profile, was active? [${profile.active}]');
            final t = ref.read(translationsProvider).requireValue;
            ref.read(inAppNotificationControllerProvider).showSuccessToast(t.pages.profiles.msg.delete.success);

            final activePrfile = await ref.read(activeProfileProvider.future);
            if (profile.id == ref.read(ConfigOptions.extraSecurityProfileId)) {
              ref.read(ConfigOptions.extraSecurityProfileId.notifier).update(activePrfile?.id);
            }
            if (profile.id == ref.read(ConfigOptions.unblockerProfileId)) {
              ref.read(ConfigOptions.unblockerProfileId.notifier).update(activePrfile?.id);
            }

            return unit;
          },
        )
        .run();
  }

  Future<void> exportConfigToClipboard(ProfileEntity profile) async {
    await _profilesRepo
        .generateConfig(profile.id)
        .match(
          (err) {
            loggy.warning('error generating config', err);
            throw err;
          },
          (configJson) async {
            await Clipboard.setData(ClipboardData(text: configJson));
            final t = ref.read(translationsProvider).requireValue;
            ref.read(inAppNotificationControllerProvider).showSuccessToast(t.common.msg.export.clipboard.success);
          },
        )
        .run();
  }
}
