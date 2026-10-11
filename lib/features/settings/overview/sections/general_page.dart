import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/proxy/model/ping_style.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:humanizer/humanizer.dart';

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

class GeneralPage extends HookConsumerWidget {
  const GeneralPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    String pingStyleName(PingStyle style) => switch (style) {
      PingStyle.numbers => t.avpn.pingNumbers,
      PingStyle.bars => t.avpn.pingBars,
      PingStyle.barsAndNumbers => t.avpn.pingBarsAndNumbers,
      PingStyle.dots => t.avpn.pingDots,
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.pages.settings.general.title)),
      body: ListView(
        children: [
          const LocalePrefTile(),
          const ThemeModePrefTile(),
          if (PlatformUtils.isDesktop) const _AccentTile(),
          const EnableAnalyticsPrefTile(),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.general.autoIpCheck),
            value: ref.watch(Preferences.autoCheckIp),
            secondary: const Icon(Icons.flag_rounded),
            onChanged: ref.read(Preferences.autoCheckIp.notifier).update,
          ),
          if (PlatformUtils.isAndroid) ...[
            SwitchListTile.adaptive(
              title: Text(t.avpn.connectOnAppStart),
              subtitle: Text(t.avpn.connectOnAppStartMsg),
              secondary: const Icon(Icons.bolt_rounded),
              value: ref.watch(Preferences.connectOnAppStart),
              onChanged: ref.read(Preferences.connectOnAppStart.notifier).update,
            ),
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
          if (PlatformUtils.isDesktop) ...[
            const ClosingPrefTile(),
            SwitchListTile.adaptive(
              title: Text(t.pages.settings.general.autoStart),
              secondary: const Icon(Icons.auto_mode_rounded),
              value: ref.watch(autoStartNotifierProvider).asData!.value,
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
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.general.memoryLimit),
            subtitle: Text(t.pages.settings.general.memoryLimitMsg),
            secondary: const Icon(Icons.memory_rounded),
            value: !ref.watch(Preferences.disableMemoryLimit),
            onChanged: (value) async => await ref.read(Preferences.disableMemoryLimit.notifier).update(!value),
          ),
          // Debug mode and log level moved to the Logs page. Both decide how
          // much is recorded, which is only meaningful next to the logs
          // themselves — and next to the filters that decide what is shown.
          ListTile(
            title: Text(t.avpn.pingStyle),
            subtitle: Text(pingStyleName(ref.watch(Preferences.pingStyle))),
            leading: const Icon(Icons.signal_cellular_alt_rounded),
            onTap: () async {
              final picked = await _pick(
                context,
                title: t.avpn.pingStyle,
                values: PingStyle.values,
                selected: ref.read(Preferences.pingStyle),
                label: pingStyleName,
              );
              if (picked != null) await ref.read(Preferences.pingStyle.notifier).update(picked);
            },
          ),
          ListTile(
            title: Text(t.avpn.pingTimeout),
            subtitle: Text(
              '${t.avpn.seconds(n: ref.watch(ConfigOptions.urlTestTimeout).inSeconds)} · ${t.avpn.pingTimeoutMsg}',
            ),
            leading: const Icon(Icons.hourglass_bottom_rounded),
            onTap: () async {
              final picked = await _pick(
                context,
                title: t.avpn.pingTimeout,
                values: const [2, 3, 5, 7, 10],
                selected: ref.read(ConfigOptions.urlTestTimeout).inSeconds,
                label: (n) => t.avpn.seconds(n: n),
              );
              if (picked != null) {
                await ref.read(ConfigOptions.urlTestTimeout.notifier).update(Duration(seconds: picked));
              }
            },
          ),
          ValuePreferenceWidget(
            value: ref.watch(ConfigOptions.connectionTestUrl),
            preferences: ref.watch(ConfigOptions.connectionTestUrl.notifier),
            title: t.pages.settings.general.connectionTestUrl,
            icon: Icons.link_rounded,
          ),
          ListTile(
            title: Text(t.pages.settings.general.urlTestInterval),
            subtitle: Text(ref.watch(ConfigOptions.urlTestInterval).toApproximateTime(isRelativeToNow: false)),
            leading: const Icon(Icons.timer_rounded),
            onTap: () async => await ref
                .read(dialogNotifierProvider.notifier)
                .showSettingSlider(
                  title: t.pages.settings.general.urlTestInterval,
                  initialValue: ref.watch(ConfigOptions.urlTestInterval).inMinutes.coerceIn(0, 60).toDouble(),
                  onReset: ref.read(ConfigOptions.urlTestInterval.notifier).reset,
                  min: 1,
                  max: 60,
                  divisions: 60,
                  labelGen: (value) => Duration(minutes: value.toInt()).toApproximateTime(isRelativeToNow: false),
                )
                .then((value) async {
                  if (value == null) return;
                  await ref.read(ConfigOptions.urlTestInterval.notifier).update(Duration(minutes: value.toInt()));
                }),
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
      ),
    );
  }
}

/// Desktop colour theme: a row of gradient swatches, the chosen one ringed.
class _AccentTile extends ConsumerWidget {
  const _AccentTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = ref.watch(Preferences.araAccent);
    final brightness = Theme.of(context).brightness;
    String name(AraAccent accent) => switch (accent) {
      AraAccent.windows => t.avpn.accentWindows,
      AraAccent.aurora => t.avpn.accentAurora,
      AraAccent.sunset => t.avpn.accentSunset,
      AraAccent.lagoon => t.avpn.accentLagoon,
      AraAccent.neon => t.avpn.accentNeon,
    };
    return ListTile(
      leading: const Icon(Icons.palette_rounded),
      title: Text(t.avpn.accentTheme),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final accent in AraAccent.values)
              Tooltip(
                message: name(accent),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => ref.read(Preferences.araAccent.notifier).update(accent),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 36,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent == selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: accent.gradient(brightness),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: accent == selected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(name(accent), style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
