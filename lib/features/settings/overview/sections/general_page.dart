import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/home_wifi/home_wifi_page.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/features/settings/widget/settings_block.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A dialog listing [values], [selected] ticked; returns the one tapped.
Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T) label,
}) => showDialog<T>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      for (final value in values)
        ListTile(
          title: Text(label(value)),
          trailing: value == selected ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
          onTap: () => Navigator.of(context).pop(value),
        ),
    ],
  ),
);

/// Settings → General (the app itself) or, with [connection], Settings → Launch and connection.
class GeneralPage extends HookConsumerWidget {
  const GeneralPage({super.key, this.connection = false});

  /// the launch and connection settings instead of the general ones
  final bool connection;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    String subUpdateName(int hours) => switch (hours) {
      0 => t.avpn.subUpdateAsProvider,
      < 0 => t.avpn.subUpdateNever,
      _ => t.avpn.subUpdateEvery(n: hours),
    };

    return Scaffold(
      appBar: AppBar(title: Text(connection ? t.avpn.settingsConnection : t.pages.settings.general.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          SettingsBlock(
            children: [
              if (!connection) ...[
                const LocalePrefTile(),
                const EnableAnalyticsPrefTile(),
                SwitchListTile.adaptive(
                  title: Text(t.pages.settings.general.autoIpCheck),
                  value: ref.watch(Preferences.autoCheckIp),
                  secondary: const Icon(Icons.flag_rounded),
                  onChanged: ref.read(Preferences.autoCheckIp.notifier).update,
                ),
                if (PlatformUtils.isAndroid) ...[
                  SwitchListTile.adaptive(
                    title: Text(t.pages.settings.general.dynamicNotification),
                    secondary: const Icon(Icons.speed_rounded),
                    value: ref.watch(Preferences.dynamicNotification),
                    onChanged: ref.read(Preferences.dynamicNotification.notifier).update,
                  ),
                  SwitchListTile.adaptive(
                    title: Text(t.pages.settings.general.hapticFeedback),
                    secondary: const Icon(Icons.vibration_rounded),
                    value: ref.watch(hapticServiceProvider),
                    onChanged: ref.read(hapticServiceProvider.notifier).updatePreference,
                  ),
                ],
                SwitchListTile.adaptive(
                  title: Text(t.pages.settings.general.memoryLimit),
                  subtitle: Text(t.pages.settings.general.memoryLimitMsg),
                  secondary: const Icon(Icons.memory_rounded),
                  value: !ref.watch(Preferences.disableMemoryLimit),
                  onChanged: (value) async => await ref.read(Preferences.disableMemoryLimit.notifier).update(!value),
                ),
                SwitchListTile.adaptive(
                  title: Text(t.avpn.lightLook),
                  subtitle: Text(t.avpn.lightLookMsg),
                  secondary: const Icon(Icons.blur_off_rounded),
                  value: ref.watch(Preferences.lightLook),
                  onChanged: ref.read(Preferences.lightLook.notifier).update,
                ),
                SwitchListTile.adaptive(
                  title: Text(t.avpn.nightMode),
                  subtitle: Text(t.avpn.nightModeMsg),
                  secondary: const Icon(Icons.bedtime_rounded),
                  value: ref.watch(Preferences.nightMode),
                  onChanged: ref.read(Preferences.nightMode.notifier).update,
                ),
                SwitchListTile.adaptive(
                  title: Text(t.avpn.lightBackground),
                  subtitle: Text(t.avpn.lightBackgroundMsg),
                  secondary: const Icon(Icons.battery_saver_rounded),
                  value: ref.watch(Preferences.lightBackground),
                  onChanged: ref.read(Preferences.lightBackground.notifier).update,
                ),
                // About is here (the logs are on the settings' main page)
                ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title: Text(t.pages.about.title),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.goNamed('about'),
                ),
                // Debug mode and log level moved to the Logs page. Both decide how
                // much is recorded, which is only meaningful next to the logs
                // themselves — and next to the filters that decide what is shown. The ping's settings are on a page
                // of their own (Settings → Ping).
              ] else ...[
                SwitchListTile.adaptive(
                  title: Text(t.avpn.connectOnAppStart),
                  subtitle: Text(t.avpn.connectOnAppStartMsg),
                  secondary: const Icon(Icons.bolt_rounded),
                  value: ref.watch(Preferences.connectOnAppStart),
                  onChanged: ref.read(Preferences.connectOnAppStart.notifier).update,
                ),
                if (PlatformUtils.isAndroid) ...[
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline_rounded),
                    title: Text(t.avpn.autoPause),
                    subtitle: Text(
                      ref.watch(Preferences.autoPauseEnabled)
                          ? t.avpn.autoPauseCount(n: ref.watch(Preferences.autoPauseApps).length)
                          : t.avpn.autoPauseHint,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.goNamed('autoPause'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.home_work_outlined),
                    title: Text(t.avpn.homeWifi),
                    subtitle: Text(
                      ref.watch(Preferences.homeWifiEnabled)
                          ? t.avpn.homeWifiCount(n: parseHomeRouters(ref.watch(Preferences.homeWifiList)).length)
                          : t.avpn.homeWifiHint,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.goNamed('homeWifi'),
                  ),
                  if (PlatformUtils.isAndroid)
                    SwitchListTile.adaptive(
                      title: Text(t.avpn.connectOnBoot),
                      subtitle: Text(t.avpn.connectOnBootMsg),
                      secondary: const Icon(Icons.restart_alt_rounded),
                      value: ref.watch(Preferences.connectOnBoot),
                      onChanged: ref.read(Preferences.connectOnBoot.notifier).update,
                    ),
                ],
                if (PlatformUtils.isDesktop) ...[
                  const ClosingPrefTile(),
                  SwitchListTile.adaptive(
                    title: Text(t.pages.settings.general.autoStart),
                    secondary: const Icon(Icons.auto_mode_rounded),
                    value: ref.watch(autoStartNotifierProvider).valueOrNull ?? false,
                    onChanged: (value) async => value
                        ? await ref.read(autoStartNotifierProvider.notifier).enable()
                        : await ref.read(autoStartNotifierProvider.notifier).disable(),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(t.pages.settings.general.silentStart),
                    secondary: const Icon(Icons.visibility_off_rounded),
                    value: ref.watch(Preferences.silentStart),
                    onChanged: ref.read(Preferences.silentStart.notifier).update,
                  ),
                ],
                if (PlatformUtils.isAndroid) const BatteryOptimizationWidget(),
                ListTile(
                  title: Text(t.avpn.subUpdate),
                  subtitle: Text(subUpdateName(ref.watch(Preferences.subUpdateHours))),
                  leading: const Icon(Icons.update_rounded),
                  onTap: () async {
                    final picked = await _pick(
                      context,
                      title: t.avpn.subUpdate,
                      values: const [0, 1, 3, 6, 12, 24, -1],
                      selected: ref.read(Preferences.subUpdateHours),
                      label: subUpdateName,
                    );
                    if (picked != null) await ref.read(Preferences.subUpdateHours.notifier).update(picked);
                  },
                ),
                ValuePreferenceWidget(
                  value: ref.watch(ConfigOptions.mtu),
                  preferences: ref.watch(ConfigOptions.mtu.notifier),
                  title: t.avpn.mtu,
                  icon: Icons.straighten_rounded,
                  inputToValue: int.tryParse,
                  digitsOnly: true,
                  validateInput: (value) {
                    final mtu = int.tryParse(value);
                    return mtu != null && mtu >= 1280 && mtu <= 9000;
                  },
                ),
                ValuePreferenceWidget(
                  value: ref.watch(ConfigOptions.clashApiPort),
                  preferences: ref.watch(ConfigOptions.clashApiPort.notifier),
                  title: t.pages.settings.general.clashApiPort,
                  icon: Icons.api_rounded,
                  validateInput: isPort,
                  digitsOnly: true,
                  inputToValue: int.tryParse,
                ),
                SwitchListTile.adaptive(
                  title: Text(t.pages.settings.general.useXrayCoreWhenPossible),
                  subtitle: Text(t.pages.settings.general.useXrayCoreWhenPossibleMsg),
                  secondary: const Icon(Icons.extension_rounded),
                  value: ref.watch(ConfigOptions.useXrayCoreWhenPossible),
                  onChanged: ref.read(ConfigOptions.useXrayCoreWhenPossible.notifier).update,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
