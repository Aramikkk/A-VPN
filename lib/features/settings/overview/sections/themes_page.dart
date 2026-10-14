import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/settings/widget/settings_block.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings → Themes: light or dark (or with the system), and the colour theme.
class ThemesPage extends ConsumerWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // Glass has its own colour schemes (each by day and by night), not the colour themes the others share; Contrast
    // takes its colour from them too
    final style = ref.watch(Preferences.araStyle);
    final glass = style == AraStyle.glass || style == AraStyle.contrast;
    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.themes)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          // the colour themes are all true black now: OLED and the neon colours
          SettingsBlock(
            children: glass
                ? const [StylePicker(), ThemeModePrefTile(), GlassSchemePicker()]
                : const [StylePicker(), ThemeModePrefTile(), AccentPicker(oled: true)],
          ),
        ],
      ),
    );
  }
}

/// Glass's own colour schemes in their three kinds of glass, each as a little backdrop with a pane on it.
class GlassSchemePicker extends ConsumerWidget {
  const GlassSchemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = ref.watch(Preferences.glassScheme);
    final theme = Theme.of(context);
    String name(GlassScheme s) => switch (s) {
      GlassScheme.lemonade => t.avpn.glassLemonade,
      GlassScheme.lagoon => t.avpn.glassLagoon,
      GlassScheme.sunset => t.avpn.glassSunset,
      GlassScheme.mint => t.avpn.glassMint,
      GlassScheme.peach => t.avpn.glassPeach,
      GlassScheme.midnight => t.avpn.glassMidnight,
      GlassScheme.neon => t.avpn.glassNeon,
      GlassScheme.aurora => t.avpn.glassAurora,
      GlassScheme.magma => t.avpn.glassMagma,
      GlassScheme.ocean => t.avpn.glassOcean,
      GlassScheme.frostbite => t.avpn.glassFrostbite,
      GlassScheme.pearl => t.avpn.glassPearl,
      GlassScheme.sage => t.avpn.glassSage,
      GlassScheme.sand => t.avpn.glassSand,
      GlassScheme.graphite => t.avpn.glassGraphite,
      GlassScheme.citrus => t.avpn.glassCitrus,
      GlassScheme.sky => t.avpn.glassSky,
      GlassScheme.tropic => t.avpn.glassTropic,
      GlassScheme.coral => t.avpn.glassCoral,
      GlassScheme.kiwi => t.avpn.glassKiwi,
      GlassScheme.rainbow => t.avpn.glassRainbow,
      GlassScheme.ember => t.avpn.glassEmber,
      GlassScheme.emerald => t.avpn.glassEmerald,
      GlassScheme.abyss => t.avpn.glassAbyss,
      GlassScheme.crimson => t.avpn.glassCrimson,
      GlassScheme.gold => t.avpn.glassGold,
      GlassScheme.toxic => t.avpn.glassToxic,
      GlassScheme.ice => t.avpn.glassIce,
      GlassScheme.dusk => t.avpn.glassDusk,
      GlassScheme.mist => t.avpn.glassMist,
      GlassScheme.linen => t.avpn.glassLinen,
      GlassScheme.slate => t.avpn.glassSlate,
      GlassScheme.seafoam => t.avpn.glassSeafoam,
      GlassScheme.cloud => t.avpn.glassCloud,
      GlassScheme.apricot => t.avpn.glassApricot,
      GlassScheme.glacier => t.avpn.glassGlacier,
      GlassScheme.moss => t.avpn.glassMoss,
      GlassScheme.ash => t.avpn.glassAsh,
      GlassScheme.chalk => t.avpn.glassChalk,
      GlassScheme.steel => t.avpn.glassSteel,
      GlassScheme.onyx => t.avpn.glassOnyx,
      GlassScheme.carbon => t.avpn.glassCarbon,
      GlassScheme.smoke => t.avpn.glassSmoke,
      GlassScheme.fog => t.avpn.glassFog,
      GlassScheme.stone => t.avpn.glassStone,
      GlassScheme.silver => t.avpn.glassSilver,
      GlassScheme.anthracite => t.avpn.glassAnthracite,
      GlassScheme.asphalt => t.avpn.glassAsphalt,
      GlassScheme.cyberpunk => t.avpn.glassCyberpunk,
      GlassScheme.pistachio => t.avpn.glassPistachio,
      GlassScheme.mintLeaf => t.avpn.glassMintLeaf,
      GlassScheme.cornflower => t.avpn.glassCornflower,
      GlassScheme.honey => t.avpn.glassHoney,
      GlassScheme.eucalyptus => t.avpn.glassEucalyptus,
      GlassScheme.claude => t.avpn.glassClaude,
      GlassScheme.claudeLight => t.avpn.glassClaudeLight,
      GlassScheme.tangerine => t.avpn.glassTangerine,
      GlassScheme.sunflower => t.avpn.glassSunflower,
      GlassScheme.ruby => t.avpn.glassRuby,
      GlassScheme.azure => t.avpn.glassAzure,
      GlassScheme.turquoise => t.avpn.glassTurquoise,
      GlassScheme.jade => t.avpn.glassJade,
      GlassScheme.lime => t.avpn.glassLime,
    };
    String kind(GlassVariant v) => switch (v) {
      GlassVariant.liquid => t.avpn.glassLiquid,
      GlassVariant.frost => t.avpn.glassFrost,
      GlassVariant.clear => t.avpn.glassClear,
    };
    return ListTile(
      leading: const Icon(Icons.blur_on_rounded),
      title: Text(t.avpn.glassSchemeTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.avpn.glassSchemeMsg),
          for (final variant in GlassVariant.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(
                kind(variant),
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final scheme in GlassScheme.values.where((s) => s.variant == variant))
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => ref.read(Preferences.glassScheme.notifier).update(scheme),
                    child: SizedBox(
                      width: 66,
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme == selected ? theme.colorScheme.onSurface : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: _GlassSwatch(look: scheme.look(theme.brightness), selected: scheme == selected),
                          ),
                          const SizedBox(height: 4),
                          Text(name(scheme), maxLines: 1, style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A scheme in small: its backdrop with a pane of its glass and a dot of its colour.
class _GlassSwatch extends StatelessWidget {
  const _GlassSwatch({required this.look, required this.selected});

  final GlassLook look;
  final bool selected;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Positioned.fill(child: GlassBackdrop(look: look)),
          Positioned(
            left: 7,
            right: 7,
            bottom: 7,
            height: 22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: look.panel,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: look.edge),
              ),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: look.accent, shape: BoxShape.circle),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: look.accent.computeLuminance() > .45 ? Colors.black : Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The colour themes as gradient swatches, the chosen one ringed: the coloured ones, or ([oled]) the true-black
/// ones (OLED and the neon themes).
class AccentPicker extends ConsumerWidget {
  const AccentPicker({super.key, this.oled = false});

  final bool oled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = ref.watch(Preferences.araAccent);
    final brightness = Theme.of(context).brightness;
    String name(AraAccent accent) => switch (accent) {
      AraAccent.oled => t.avpn.accentOled,
      AraAccent.neonYellow => t.avpn.accentNeonYellow,
      AraAccent.neonRed => t.avpn.accentNeonRed,
      AraAccent.neonBlue => t.avpn.accentNeonBlue,
      AraAccent.neonGreen => t.avpn.accentNeonGreen,
      AraAccent.neonOrange => t.avpn.accentNeonOrange,
      AraAccent.neonAmber => t.avpn.accentNeonAmber,
      AraAccent.neonCoral => t.avpn.accentNeonCoral,
      AraAccent.neonPink => t.avpn.accentNeonPink,
      AraAccent.neonFuchsia => t.avpn.accentNeonFuchsia,
      AraAccent.neonViolet => t.avpn.accentNeonViolet,
      AraAccent.neonIndigo => t.avpn.accentNeonIndigo,
      AraAccent.neonTurquoise => t.avpn.accentNeonTurquoise,
      AraAccent.neonMint => t.avpn.accentNeonMint,
      AraAccent.neonLavender => t.avpn.accentNeonLavender,
    };
    return ListTile(
      leading: Icon(oled ? Icons.contrast_rounded : Icons.palette_rounded),
      title: Text(oled ? t.avpn.accentOledGroup : t.avpn.accentTheme),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (oled) Text(t.avpn.accentOledGroupMsg),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final accent in AraAccent.values.where((a) => a.pure == oled))
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
                                color: accent == selected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
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
                                  // the Mono themes' blocks are all graphite: a dot shows their colour
                                  : accent.icon != null
                                  ? Center(
                                      child: CircleAvatar(
                                        radius: 7,
                                        backgroundColor: brightness == Brightness.dark
                                            ? accent.darkPrimary
                                            : accent.lightPrimary,
                                      ),
                                    )
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
        ],
      ),
    );
  }
}

/// The looks as small previews in today's brightness: Contrast, Glass, Graphite and the classic one.
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
      AraStyle.contrast => (t.avpn.styleContrast, t.avpn.styleContrastHint),
      AraStyle.glass => (t.avpn.styleGlass, t.avpn.styleGlassHint),
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
                        child: style == AraStyle.glass
                            ? _GlassStylePreview(look: ref.watch(Preferences.glassScheme).look(brightness))
                            : _StylePreview(style: style, brightness: brightness, accent: accentColour),
                      ),
                      const SizedBox(height: 6),
                      Text(names(style).$1, style: theme.textTheme.titleSmall),
                      Text(
                        names(style).$2,
                        maxLines: 3,
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
    final neon = accent;
    final bg = p?.bg ?? (dark ? Colors.black : Colors.white);
    final line = p?.line ?? (dark ? const Color(0xFF26262B) : const Color(0xFFDDDFDA));
    final card = p?.card ?? (dark ? const Color(0xFF111113) : const Color(0xFFF6F7F4));
    final contrast = style == AraStyle.contrast;
    Widget row(bool selected) => Container(
      height: 9,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected ? neon.withValues(alpha: .3) : card,
        borderRadius: BorderRadius.circular(4),
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
                    border: Border.all(color: neon, width: 2),
                    boxShadow: [BoxShadow(color: neon.withValues(alpha: .5), blurRadius: 8)],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 34,
                  height: 12,
                  decoration: BoxDecoration(color: neon, borderRadius: BorderRadius.circular(9)),
                ),
              ],
            )
          // Contrast: the black panel with the glowing ring under the light rows
          else if (contrast)
            Container(
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF0B0B0C), borderRadius: BorderRadius.circular(8)),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF3F1EC),
                  border: Border.all(color: neon, width: 2),
                  boxShadow: [BoxShadow(color: neon.withValues(alpha: .6), blurRadius: 8)],
                ),
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

/// Glass's thumbnail: the chosen scheme's backdrop with see-through rows and a floating pane.
class _GlassStylePreview extends StatelessWidget {
  const _GlassStylePreview({required this.look});

  final GlassLook look;

  @override
  Widget build(BuildContext context) {
    Widget row(bool selected) => Container(
      height: 10,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected ? look.accent.withValues(alpha: look.dark ? .35 : .6) : look.panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: selected ? look.accent : look.edge, width: .8),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 86,
        child: Stack(
          children: [
            Positioned.fill(child: GlassBackdrop(look: look)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row(true),
                  row(false),
                  row(false),
                  const Spacer(),
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: look.panel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: look.edge),
                    ),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: look.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
