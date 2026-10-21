import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/settings/widget/settings_block.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings → Themes: light or dark (or with the system), the theme (Contrast or Glass: one layout in different
/// colours) and its colours.
class ThemesPage extends ConsumerWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final glass = ref.watch(Preferences.araStyle) == AraStyle.glass;
    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.themes)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          // Glass has its own colour schemes (each by day and by night); Contrast its palettes and backdrops
          SettingsBlock(
            children: [const StylePicker(), const ThemeModePrefTile(), if (glass) const GlassSchemePicker()],
          ),
          // how see-through the blocks are, for both; Contrast: the backdrop and the colour too
          ContrastThemePicker(glass: glass),
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

/// The two themes as small previews in today's brightness: Contrast and Glass (one layout, different colours).
class StylePicker extends ConsumerWidget {
  const StylePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final selected = ref.watch(Preferences.araStyle);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accentColour = ref.watch(Preferences.contrastPalette).accent(brightness);
    (String, String) names(AraStyle style) => switch (style) {
      AraStyle.contrast => (t.avpn.styleContrast, t.avpn.styleContrastHint),
      AraStyle.glass => (t.avpn.styleGlass, t.avpn.styleGlassHint),
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
                            : _StylePreview(brightness: brightness, accent: accentColour),
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

/// Contrast's thumbnail: its background, a few server rows with the chosen one, and the black panel with its ring.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.brightness, required this.accent});

  final Brightness brightness;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palette(brightness);
    Widget row(bool selected) => Container(
      height: 9,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: .3) : p.card,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Container(
      height: 86,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(true),
          row(false),
          row(false),
          const Spacer(),
          _PanelPreview(accent: accent),
        ],
      ),
    );
  }
}

/// The black connect panel in small: the ring, lit in [accent].
class _PanelPreview extends StatelessWidget {
  const _PanelPreview({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: const Color(0xFF0B0B0C), borderRadius: BorderRadius.circular(8)),
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF3F1EC),
        border: Border.all(color: accent, width: 2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .6), blurRadius: 8)],
      ),
    ),
  );
}

/// Glass's thumbnail: the chosen scheme's backdrop with see-through rows and the same black panel.
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
                  _PanelPreview(accent: look.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The theme's look in steps: clarity (both themes), then Contrast's backdrop and colour palettes (Glass has its own
/// colour schemes above, and its backdrop is their colour spots).
class ContrastThemePicker extends ConsumerWidget {
  const ContrastThemePicker({super.key, this.glass = false});

  /// Glass: just the clarity
  final bool glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final ru = t.$meta.locale.languageCode == 'ru';
    final clarity = ref.watch(Preferences.contrastClarity);
    final backdrop = ref.watch(Preferences.contrastBackdrop);
    final palette = ref.watch(Preferences.contrastPalette);
    final (warm, cool) = ref.watch(contrastColoursProvider).backdrop(theme.brightness);
    final accent = scheme.primary;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
        ),
      ),
    );
    Widget card(Widget child) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
    Widget label(String text, bool on) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall?.copyWith(
        color: on ? accent : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
    Widget backdropOf(ContrastBackdrop kind, {double radius = 12}) => ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: ContrastBackdropPainter(kind: kind, warm: warm, cool: cool, dark: dark, seed: 5),
        child: const SizedBox.expand(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(t.avpn.contrastClarityTitle),
        card(
          Row(
            children: [
              for (final c in ContrastClarity.values) ...[
                if (c != ContrastClarity.values.first) const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => ref.read(Preferences.contrastClarity.notifier).update(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: c == clarity ? accent.withValues(alpha: .13) : null,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c == clarity ? accent : scheme.outlineVariant, width: 1.4),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 40,
                            child: Stack(
                              children: [
                                Positioned.fill(child: backdropOf(ContrastBackdrop.stripes, radius: 10)),
                                // a pane at this clarity over it
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: c.blur / 3, sigmaY: c.blur / 3),
                                        child: ColoredBox(
                                          color: dark
                                              ? const Color(0xFF1E1E22).withValues(alpha: c.night)
                                              : Colors.white.withValues(alpha: c.day),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          label(ru ? c.ru : c.en, c == clarity),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!glass) ...[
          heading(t.avpn.contrastBackdropTitle),
          card(
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: .58,
              children: [
                for (final k in ContrastBackdrop.values)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ref.read(Preferences.contrastBackdrop.notifier).update(k),
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: k == backdrop ? accent : Colors.transparent, width: 2),
                            ),
                            child: backdropOf(k),
                          ),
                        ),
                        const SizedBox(height: 4),
                        label(ru ? k.ru : k.en, k == backdrop),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          heading(t.avpn.contrastPaletteTitle),
          card(
            GridView(
              // a cell as tall as its swatch and name (a share of the width left the name cut on a narrow screen)
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 4,
                mainAxisExtent: 76,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final p in ContrastPalette.values)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ref.read(Preferences.contrastPalette.notifier).update(p),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: p == palette ? accent : Colors.transparent, width: 2),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [p.warm, p.warm, p.cool, p.cool],
                                stops: const [0, .5, .5, 1],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        label(ru ? p.ru : p.en, p == palette),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
