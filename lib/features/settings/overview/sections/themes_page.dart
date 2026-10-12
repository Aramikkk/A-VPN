import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
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
      body: ListView(children: const [StylePicker(), ThemeModePrefTile(), AccentPicker()]),
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
      AraAccent.monoRed => t.avpn.accentMonoRed,
      AraAccent.monoBlue => t.avpn.accentMonoBlue,
      AraAccent.monoEmerald => t.avpn.accentMonoEmerald,
      AraAccent.monoOrange => t.avpn.accentMonoOrange,
      AraAccent.monoViolet => t.avpn.accentMonoViolet,
      AraAccent.monoTeal => t.avpn.accentMonoTeal,
      AraAccent.monoGold => t.avpn.accentMonoGold,
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

/// The looks as small previews in today's brightness: Graphite, Editorial and the classic one.
class StylePicker extends ConsumerWidget {
  const StylePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = ref.watch(Preferences.araStyle);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = ref.watch(Preferences.araAccent);
    final accentColour = brightness == Brightness.dark ? accent.darkPrimary : accent.lightPrimary;
    (String, String) names(AraStyle style) => switch (style) {
      AraStyle.graphite => (t.avpn.styleGraphite, t.avpn.styleGraphiteHint),
      AraStyle.editorial => (t.avpn.styleEditorial, t.avpn.styleEditorialHint),
      AraStyle.classic => (t.avpn.styleClassic, t.avpn.styleClassicHint),
    };
    return ListTile(
      leading: const Icon(Icons.style_rounded),
      title: Text(t.avpn.styleTitle),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final style in AraStyle.values)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ref.read(Preferences.araStyle.notifier).update(style),
                child: SizedBox(
                  width: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: style == selected ? theme.colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: _StylePreview(style: style, brightness: brightness, accent: accentColour),
                      ),
                      const SizedBox(height: 6),
                      Text(names(style).$1, style: theme.textTheme.titleSmall),
                      Text(
                        names(style).$2,
                        maxLines: 2,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
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

/// A thumbnail of a look: its background, a few server rows with the chosen one, and its connect control.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style, required this.brightness, required this.accent});

  final AraStyle style;
  final Brightness brightness;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final p = style == AraStyle.classic ? null : AppTheme.palette(style, brightness);
    final bg = p?.bg ?? (dark ? Colors.black : Colors.white);
    final fg = p?.fg ?? (dark ? Colors.white : Colors.black);
    final line = p?.line ?? (dark ? const Color(0xFF26262B) : const Color(0xFFDDDFDA));
    final card = p?.card ?? (dark ? const Color(0xFF111113) : const Color(0xFFF6F7F4));
    final editorial = style == AraStyle.editorial;
    Widget row(bool selected) => Container(
      height: 9,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected ? (editorial ? fg : accent.withValues(alpha: .3)) : card,
        borderRadius: BorderRadius.circular(editorial ? 0 : 4),
        border: editorial ? Border(bottom: BorderSide(color: line)) : null,
      ),
    );
    return Container(
      height: 86,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
        gradient: style == AraStyle.graphite
            ? RadialGradient(
                center: const Alignment(0, -1.3),
                radius: 1.2,
                colors: [
                  Color.alphaBlend(accent.withValues(alpha: dark ? .25 : .12), bg),
                  bg,
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(true),
          row(false),
          row(false),
          const Spacer(),
          if (style == AraStyle.graphite)
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: .5), blurRadius: 8)],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 34,
                  height: 12,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(9)),
                ),
              ],
            )
          else if (editorial)
            Container(
              padding: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: fg, width: 1.5)),
              ),
              child: Row(
                children: [
                  Text(
                    'ВКЛ.',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: fg,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 13,
                    padding: const EdgeInsets.all(2),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(9)),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 16,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: .6)]),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
    );
  }
}
