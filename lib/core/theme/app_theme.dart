import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/utils/platform_utils.dart';

class AppTheme {
  AppTheme(
    this.mode,
    this.fontFamily, {
    AraAccent? accent,
    this.style = AraStyle.classic,
    this.glassScheme = GlassScheme.fallback,
  }) : accent = accent ?? AraAccent.platformDefault;

  /// Glass's own colour scheme (the accent above doesn't colour Glass)
  final GlassScheme glassScheme;

  bool get _glass => style == AraStyle.glass;
  final AppThemeMode mode;
  final String fontFamily;

  /// the accent colour and gradient (Settings → General → Colour theme)
  final AraAccent accent;

  /// Contrast, Glass, Graphite or the classic look (Settings → Themes)
  final AraStyle style;

  AraLook _look(Brightness brightness) {
    final graph = graphColours(accent, brightness);
    return AraLook(
      gradient: accent.gradient(brightness),
      onGradient: accent.onGradient(brightness),
      // the ping's colour scale starts at the accent (red, orange… in the red theme)
      fastPing: brightness == Brightness.dark ? accent.darkPrimary : accent.lightPrimary,
      dark: brightness == Brightness.dark,
      border: accent.pure ? (brightness == Brightness.dark ? Colors.white54 : Colors.black45) : null,
      graphDown: graph.down,
      graphUp: graph.up,
    );
  }

  /// The speed graph's colours on the speed block: download in the accent colour and upload in a colour across
  /// the colour wheel from it, both readable on the block. A colourless accent (Monochrome, OLED) gets blue and
  /// orange; on a coloured gradient the download stays in the text colour and the upload gets the opposite hue.
  static ({Color down, Color up}) graphColours(AraAccent accent, Brightness brightness) {
    final colours = brightness == Brightness.dark ? accent.darkGradient : accent.lightGradient;
    final block = colours[colours.length ~/ 2];
    final blockDark = block.computeLuminance() < .4;
    final seed = HSLColor.fromColor(accent.seed);
    final colourless = seed.saturation < .12;
    final neutralBlock = accent.pure || colourless || accent.icon != null;
    final Color down;
    final Color up;
    if (colourless) {
      down = blockDark ? const Color(0xFF3B9BFF) : const Color(0xFF1F66E5);
      up = blockDark ? const Color(0xFFFF9F2E) : const Color(0xFFD9590B);
    } else if (neutralBlock) {
      final base = HSLColor.fromColor(blockDark ? accent.darkPrimary : accent.lightPrimary);
      down = base.toColor();
      up = base.withHue((base.hue + 150) % 360).toColor();
    } else {
      final hue = HSLColor.fromColor(block).hue;
      down = accent.onGradient(brightness);
      up = HSLColor.fromAHSL(1, (hue + 180) % 360, .95, blockDark ? .75 : .32).toColor();
    }
    return (down: AraLook.readableOn(down, block), up: AraLook.readableOn(up, block));
  }

  /// Light: white backgrounds and the accent's deeper shade, whatever the wallpaper colours.
  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    if (style != AraStyle.classic) return _styledTheme(Brightness.light);
    if (PlatformUtils.isDesktop) return _windowsTheme(Brightness.light);
    const white = Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: accent.seed).copyWith(
      primary: accent.lightPrimary,
      onPrimary: white,
      surface: white,
      surfaceDim: const Color(0xFFEDEEEB),
      surfaceBright: white,
      surfaceContainerLowest: white,
      surfaceContainerLow: const Color(0xFFF6F7F4),
      surfaceContainer: const Color(0xFFF0F1EE),
      surfaceContainerHigh: const Color(0xFFEAEBE8),
      surfaceContainerHighest: const Color(0xFFE4E5E2),
      outlineVariant: const Color(0xFFDDDFDA),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(backgroundColor: white, surfaceTintColor: Colors.transparent),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: white, surfaceTintColor: Colors.transparent),
      fontFamily: fontFamily,
      extensions: <ThemeExtension<dynamic>>{ConnectionButtonTheme.light, _look(Brightness.light)},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    if (style != AraStyle.classic) return _styledTheme(Brightness.dark);
    // the app's dark look is OLED black, also when the phone's dark mode picks it
    if (PlatformUtils.isDesktop) return _windowsTheme(Brightness.dark);
    if (mode != AppThemeMode.dark) return _oledTheme();
    final ColorScheme scheme =
        darkColorScheme ?? ColorScheme.fromSeed(seedColor: const Color(0xFF293CA0), brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  /// OLED black: true black backgrounds, near-black cards and the accent, whatever the wallpaper colours.
  ThemeData _oledTheme() {
    const black = Colors.black;
    final scheme = ColorScheme.fromSeed(seedColor: accent.seed, brightness: Brightness.dark).copyWith(
      primary: accent.darkPrimary,
      onPrimary: black,
      surface: black,
      surfaceDim: black,
      surfaceBright: const Color(0xFF1C1C1E),
      surfaceContainerLowest: black,
      surfaceContainerLow: const Color(0xFF0B0B0C),
      surfaceContainer: const Color(0xFF111113),
      surfaceContainerHigh: const Color(0xFF17171A),
      surfaceContainerHighest: const Color(0xFF1E1E22),
      outlineVariant: const Color(0xFF26262B),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      canvasColor: black,
      appBarTheme: const AppBarTheme(backgroundColor: black, surfaceTintColor: Colors.transparent),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: black, surfaceTintColor: Colors.transparent),
      navigationRailTheme: const NavigationRailThemeData(backgroundColor: black),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surfaceContainer),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainer),
      fontFamily: fontFamily,
      extensions: <ThemeExtension<dynamic>>{ConnectionButtonTheme.light, _look(Brightness.dark)},
    );
  }

  /// Windows 11 look for the desktop: the Mica-grey window, white (or dark grey) cards, the Windows accent blue
  /// and a blue gradient for the highlights.
  ThemeData _windowsTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final pure = accent.pure;
    final background = pure
        ? (dark ? Colors.black : Colors.white)
        : (dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3));
    final seeded = ColorScheme.fromSeed(seedColor: accent.seed, brightness: brightness);
    final windows = seeded.copyWith(
      primary: dark ? accent.darkPrimary : accent.lightPrimary,
      onPrimary: dark ? const Color(0xFF101014) : Colors.white,
      surface: background,
      surfaceDim: dark ? const Color(0xFF1A1A1A) : const Color(0xFFEBEBEB),
      surfaceBright: dark ? const Color(0xFF383838) : Colors.white,
      surfaceContainerLowest: dark ? const Color(0xFF1C1C1C) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF2B2B2B) : const Color(0xFFFBFBFB),
      surfaceContainer: dark ? const Color(0xFF2D2D2D) : const Color(0xFFF9F9F9),
      surfaceContainerHigh: dark ? const Color(0xFF323232) : Colors.white,
      surfaceContainerHighest: dark ? const Color(0xFF3A3A3A) : const Color(0xFFEFEFEF),
      outlineVariant: dark ? const Color(0xFF3D3D3D) : const Color(0xFFE5E5E5),
    );
    // OLED: black cards on black (white on white), told apart by their outlines
    final scheme = !pure
        ? windows
        : windows.copyWith(
            surface: background,
            surfaceDim: background,
            surfaceBright: dark ? const Color(0xFF1C1C1C) : Colors.white,
            surfaceContainerLowest: background,
            surfaceContainerLow: dark ? const Color(0xFF0A0A0A) : Colors.white,
            surfaceContainer: dark ? const Color(0xFF0E0E0E) : const Color(0xFFFAFAFA),
            surfaceContainerHigh: dark ? const Color(0xFF141414) : const Color(0xFFF5F5F5),
            surfaceContainerHighest: dark ? const Color(0xFF1C1C1C) : const Color(0xFFEDEDED),
            outlineVariant: dark ? const Color(0xFF333333) : const Color(0xFFD6D6D6),
          );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: AppBarTheme(backgroundColor: background, surfaceTintColor: Colors.transparent),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: scheme.primary.withValues(alpha: .18),
      ),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: background, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerLow),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      // Windows' own UI font renders crisp at small sizes; the bundled emoji font stays as the fallback for flags
      fontFamily: 'Segoe UI Variable Text',
      fontFamilyFallback: ['Segoe UI', if (fontFamily.isNotEmpty) fontFamily],
      extensions: <ThemeExtension<dynamic>>{ConnectionButtonTheme.light, _look(brightness)},
    );
  }

  /// The palette of a style in day or night: background, cards, text, lines.
  static AraPalette palette(AraStyle style, Brightness brightness, {GlassScheme glass = GlassScheme.fallback}) {
    if (style == AraStyle.glass) return glassPalette(glass.look(brightness));
    final dark = brightness == Brightness.dark;
    // Contrast: warm light grey with white tiles by day, dark graphite with lighter tiles by night (its black
    // panel is drawn by the home screen itself)
    return style == AraStyle.contrast
        ? AraPalette(
            bg: dark ? const Color(0xFF1A1A1C) : const Color(0xFFECEBE7),
            fg: dark ? const Color(0xFFF3F1EC) : const Color(0xFF111111),
            muted: dark ? const Color(0xFF8F8C86) : const Color(0xFF6E6A64),
            card: dark ? const Color(0xFF26262A) : Colors.white,
            container: dark ? const Color(0xFF2A2A2E) : const Color(0xFFF7F6F3),
            high: dark ? const Color(0xFF303034) : const Color(0xFFF1F0EC),
            highest: dark ? const Color(0xFF38383D) : const Color(0xFFE6E4DF),
            line: dark ? const Color(0xFF3A3A3F) : const Color(0xFFD4D1CB),
            strongLine: dark ? const Color(0xFF55555B) : const Color(0xFFB4B0A8),
            nav: dark ? const Color(0xFF0B0B0C) : const Color(0xFF111111),
          )
        : AraPalette(
            bg: dark ? const Color(0xFF0B0B0D) : const Color(0xFFF4F4F6),
            fg: dark ? const Color(0xFFF2F2F4) : const Color(0xFF16161A),
            muted: dark ? const Color(0xFF8D8D95) : const Color(0xFF6F6F78),
            card: dark ? const Color(0xFF151517) : Colors.white,
            container: dark ? const Color(0xFF1A1A1D) : const Color(0xFFF8F8FA),
            high: dark ? const Color(0xFF202024) : const Color(0xFFEFEFF2),
            highest: dark ? const Color(0xFF26262B) : const Color(0xFFE8E8EC),
            line: dark ? const Color(0xFF34343B) : const Color(0xFFD3D3DA),
            strongLine: dark ? const Color(0xFF4A4A52) : const Color(0xFFB9B9C2),
            nav: dark ? const Color(0xFF0F0F12) : Colors.white,
          );
  }

  /// Glass's colours: see-through panels and lines over the backdrop ([AraPalette.bg] is the backdrop's own colour,
  /// for working out readable colours; the pages themselves are clear so the backdrop shows).
  static AraPalette glassPalette(GlassLook s) {
    final dark = s.dark;
    Color more(double alpha) => Colors.white.withValues(alpha: (s.panel.a + alpha).clamp(0.0, 1.0));
    return AraPalette(
      bg: s.base,
      fg: dark ? const Color(0xFFF4F4F7) : const Color(0xFF15151A),
      muted: dark ? const Color(0xFFA4A4AE) : const Color(0xFF55555F),
      card: s.panel,
      container: more(dark ? .02 : .05),
      high: more(dark ? .05 : .12),
      highest: more(dark ? .09 : .2),
      line: s.edge,
      strongLine: dark ? Colors.white.withValues(alpha: .3) : Colors.white,
      nav: Colors.transparent,
    );
  }

  /// Contrast, Glass and Graphite, by day or night, in the accent colour (Glass: its scheme's).
  ThemeData _styledTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final contrast = style == AraStyle.contrast;
    final styled = palette(style, brightness, glass: glassScheme);
    final glass = _glass;
    final look = glassScheme.look(brightness);
    // a dialog, a sheet or a menu lies over the page's content: a solid version of the glass
    final solid = glass
        ? Color.alphaBlend(look.dark ? const Color(0x24FFFFFF) : const Color(0xE6FFFFFF), look.base)
        : styled.card;
    // the OLED theme in Graphite: true black by night (pixels off) and pure white by day, cards just off it
    final p = accent.pure && style == AraStyle.graphite
        ? AraPalette(
            bg: dark ? Colors.black : Colors.white,
            fg: styled.fg,
            muted: styled.muted,
            card: dark ? const Color(0xFF0A0A0B) : Colors.white,
            container: dark ? const Color(0xFF0E0E10) : const Color(0xFFF7F7F8),
            high: dark ? const Color(0xFF151517) : const Color(0xFFF0F0F2),
            highest: dark ? const Color(0xFF1C1C1F) : const Color(0xFFE8E8EB),
            line: dark ? const Color(0xFF2E2E33) : const Color(0xFFD6D6DC),
            strongLine: styled.strongLine,
            nav: dark ? Colors.black : Colors.white,
          )
        : styled;
    final accentColour = glass ? look.accent : (dark ? accent.darkPrimary : accent.lightPrimary);
    final primary = AraLook.readableOn(accentColour, glass ? look.panelOnBase : p.bg);
    final onPrimary = primary.computeLuminance() > .45 ? const Color(0xFF111111) : Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: glass ? look.accent : accent.seed, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: Color.alphaBlend(primary.withValues(alpha: .16), p.card),
      onPrimaryContainer: p.fg,
      secondaryContainer: Color.alphaBlend(primary.withValues(alpha: .12), p.card),
      onSecondaryContainer: p.fg,
      surface: p.bg,
      onSurface: p.fg,
      onSurfaceVariant: p.muted,
      surfaceDim: p.bg,
      surfaceBright: p.card,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.card,
      surfaceContainer: p.container,
      surfaceContainerHigh: p.high,
      surfaceContainerHighest: p.highest,
      outline: p.strongLine,
      outlineVariant: p.line,
    );

    // body text: Manrope (Graphite, Glass) or Golos Text (Contrast); headings in Unbounded (Contrast: Golos)
    final body = contrast ? 'Golos Text' : 'Manrope';
    final base = (dark ? Typography.material2021().white : Typography.material2021().black).apply(
      fontFamily: body,
      bodyColor: p.fg,
      displayColor: p.fg,
    );
    // Contrast's headings in Golos too, medium and tight, as its big figures
    TextStyle? heading(TextStyle? s, double spacing) => contrast
        ? s?.copyWith(fontFamily: 'Golos Text', fontWeight: FontWeight.w600, letterSpacing: spacing * .8)
        : s?.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w800, letterSpacing: spacing);
    final text = base.copyWith(
      displayLarge: heading(base.displayLarge, -2),
      displayMedium: heading(base.displayMedium, -1.5),
      displaySmall: heading(base.displaySmall, -1),
      headlineLarge: heading(base.headlineLarge, -1),
      headlineMedium: heading(base.headlineMedium, -.8),
      headlineSmall: heading(base.headlineSmall, -.5),
      titleLarge: heading(base.titleLarge, -.4)?.copyWith(fontSize: 21),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );

    final radius = (glass ? 24.0 : 20.0);
    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: p.line),
    );
    final OutlinedBorder small = RoundedRectangleBorder(borderRadius: BorderRadius.circular(99));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: body,
      // the bundled emoji font draws the servers' flags (Windows has none of its own)
      fontFamilyFallback: [if (fontFamily.isNotEmpty) fontFamily, 'Emoji'],
      // Glass: every page clear, the backdrop behind the whole app showing through
      scaffoldBackgroundColor: glass ? Colors.transparent : p.bg,
      canvasColor: glass ? Colors.transparent : p.bg,
      dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: glass ? Colors.transparent : p.bg,
        foregroundColor: p.fg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
        // the status bar's icons in the opposite of the page: on white they were white too, all but the battery
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.nav,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: .16),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : p.muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: body,
            fontSize: 11.5,
            color: s.contains(WidgetState.selected) ? primary : p.muted,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.nav,
        indicatorColor: primary.withValues(alpha: .16),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: p.muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: p.fg, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: p.muted),
      ),
      cardTheme: CardThemeData(color: p.card, surfaceTintColor: Colors.transparent, elevation: 0, shape: shape),
      dialogTheme: DialogThemeData(backgroundColor: solid, surfaceTintColor: Colors.transparent, shape: shape),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: solid, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(color: solid, surfaceTintColor: Colors.transparent),
      menuTheme: MenuThemeData(style: MenuStyle(backgroundColor: WidgetStatePropertyAll(solid))),
      snackBarTheme: glass
          ? SnackBarThemeData(
              backgroundColor: solid,
              contentTextStyle: TextStyle(color: p.fg),
            )
          : null,
      chipTheme: ChipThemeData(
        shape: small.copyWith(side: BorderSide(color: p.line)),
        // a selected chip keeps its text colour, so its fill is a tint
        selectedColor: primary.withValues(alpha: .18),
        backgroundColor: Colors.transparent,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: p.fg),
        checkmarkColor: primary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(small),
          side: WidgetStatePropertyAll(BorderSide(color: p.line)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? (primary.withValues(alpha: .18)) : null,
          ),
          foregroundColor: WidgetStatePropertyAll(p.fg),
          iconColor: WidgetStatePropertyAll(p.fg),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? (onPrimary) : p.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? (primary) : p.highest),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => (s.contains(WidgetState.selected) ? primary : p.line),
        ),
        thumbIcon: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Icon(Icons.check_rounded, size: 16, color: primary) : null,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: small)),
      listTileTheme: ListTileThemeData(iconColor: primary),
      extensions: <ThemeExtension<dynamic>>{ConnectionButtonTheme.light, _styledLook(brightness, p, primary)},
    );
  }

  /// The speed block and the graph's colours for a style: Graphite's block is a dark (or white) glass card with the
  /// download in the accent and the upload across the colour wheel.
  AraLook _styledLook(Brightness brightness, AraPalette p, Color primary) {
    final dark = brightness == Brightness.dark;
    final glass = _glass;
    final look = glassScheme.look(brightness);
    final blockColours = glass
        ? [p.high, p.card]
        : accent.filled
        ? [accent.darkPrimary, accent.darkPrimary]
        : accent.pure
        ? [p.card, p.card]
        : dark
        ? const [Color(0xFF1D1D21), Color(0xFF141417), Color(0xFF0F0F11)]
        : const [Colors.white, Color(0xFFFAFAFB), Color(0xFFF2F2F5)];
    final block = glass ? look.panelOnBase : blockColours[blockColours.length ~/ 2];
    final colourless = HSLColor.fromColor(glass ? look.accent : accent.seed).saturation < .12;
    final Color down;
    final Color up;
    final filled = accent.filled && !glass;
    if (filled) {
      // on the neon block: black lines, upload a lighter shade of it
      down = Colors.black;
      up = Color.alphaBlend(Colors.black.withValues(alpha: .55), block);
    } else if (colourless) {
      down = dark ? const Color(0xFF3B9BFF) : const Color(0xFF1F66E5);
      up = dark ? const Color(0xFFFF9F2E) : const Color(0xFFD9590B);
    } else {
      final hsl = HSLColor.fromColor(primary);
      down = primary;
      up = hsl.withHue((hsl.hue + 150) % 360).toColor();
    }
    return AraLook(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: blockColours),
      onGradient: filled ? Colors.black : p.fg,
      fastPing: primary,
      neonFill: filled ? accent.darkPrimary : null,
      dark: dark,
      border: p.line,
      graphDown: filled ? down : AraLook.readableOn(down, block),
      graphUp: filled ? up : AraLook.readableOn(up, block),
      style: style,
      pingOn: glass ? look.panelOnBase : p.card,
      glass: glass ? look : null,
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}

/// A style's colours in day or night.
class AraPalette {
  const AraPalette({
    required this.bg,
    required this.fg,
    required this.muted,
    required this.card,
    required this.container,
    required this.high,
    required this.highest,
    required this.line,
    required this.strongLine,
    required this.nav,
  });

  final Color bg;
  final Color fg;
  final Color muted;
  final Color card;
  final Color container;
  final Color high;
  final Color highest;

  /// a hairline between rows
  final Color line;

  /// a stronger hairline
  final Color strongLine;
  final Color nav;
}
