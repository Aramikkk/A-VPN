import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings → Themes: light or dark (or with the system), and the colour theme.
class ThemesPage extends ConsumerWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.themes)),
      body: ListView(children: const [ThemeModePrefTile(), AccentPicker()]),
    );
  }
}

/// The colour themes as gradient swatches, the chosen one ringed.
class AccentPicker extends ConsumerWidget {
  const AccentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = ref.watch(Preferences.araAccent);
    final brightness = Theme.of(context).brightness;
    String name(AraAccent accent) => switch (accent) {
      AraAccent.acid => t.avpn.accentAcid,
      AraAccent.windows => t.avpn.accentWindows,
      AraAccent.aurora => t.avpn.accentAurora,
      AraAccent.sunset => t.avpn.accentSunset,
      AraAccent.lagoon => t.avpn.accentLagoon,
      AraAccent.neon => t.avpn.accentNeon,
      AraAccent.mono => t.avpn.accentMono,
      AraAccent.pastel => t.avpn.accentPastel,
      AraAccent.cyber => t.avpn.accentCyber,
      AraAccent.oled => t.avpn.accentOled,
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
                            // the OLED swatch is the background's own colour: outline it
                            border: accent.pure ? Border.all(color: Theme.of(context).colorScheme.outline) : null,
                          ),
                          child: accent == selected
                              ? Icon(Icons.check_rounded, color: accent.onGradient(brightness), size: 18)
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
