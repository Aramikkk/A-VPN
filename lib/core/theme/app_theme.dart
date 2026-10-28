import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/contrast_look.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(
    this.mode,
    this.fontFamily, {
    AraAccent? accent,
    this.style = AraStyle.contrast,
    this.glassScheme = GlassScheme.fallback,
    this.contrastPalette = ContrastPalette.fallback,
  }) : accent = accent ?? AraAccent.platformDefault;

  /// Glass's own colour scheme, when the theme is Glass
  final GlassScheme glassScheme;

  /// Contrast's colour, when the theme is Contrast
  final ContrastPalette contrastPalette;

  /// What the one layout is drawn in: the Glass scheme's colours or the Contrast palette's
  ContrastColours get colours => style == AraStyle.glass ? GlassColours(glassScheme) : contrastPalette;
  final AppThemeMode mode;
  final String fontFamily;

  /// the accent colour and gradient (Settings → General → Colour theme)
  final AraAccent accent;

  /// The theme: Contrast or Glass, the same layout in different colours (Settings → Themes)
  final AraStyle style;

  /// The theme by day.
  ThemeData lightTheme(ColorScheme? lightColorScheme) => _styledTheme(Brightness.light);

  /// The theme by night.
  ThemeData darkTheme(ColorScheme? darkColorScheme) => _styledTheme(Brightness.dark);

  /// A tonal palette's colours: by night its darkest shade for the page and its pane shade, lifted step by step,
  /// for the cards and lines; by day its lightest for the page, the cards white.
  static AraPalette _tonal(AraPalette plain, ContrastColours palette, bool dark) {
    final page = palette.page(dark);
    if (!dark) {
      return AraPalette(
        bg: page,
        fg: plain.fg,
        muted: plain.muted,
        card: plain.card,
        container: Color.lerp(page, Colors.white, .6)!,
        high: Color.lerp(page, Colors.white, .4)!,
        highest: Color.lerp(page, Colors.black, .04)!,
        line: Color.lerp(page, Colors.black, .12)!,
        strongLine: Color.lerp(page, Colors.black, .25)!,
        nav: plain.nav,
      );
    }
    final pane = palette.pane(true);
    return AraPalette(
      bg: page,
      fg: plain.fg,
      muted: Color.lerp(palette.cool, plain.muted, .5)!,
      card: pane,
      container: Color.lerp(pane, Colors.white, .04)!,
      high: Color.lerp(pane, Colors.white, .08)!,
      highest: Color.lerp(pane, Colors.white, .12)!,
      line: Color.lerp(pane, Colors.white, .14)!,
      strongLine: Color.lerp(pane, Colors.white, .24)!,
      nav: plain.nav,
    );
  }

  /// The usual colours by day or by night: background, cards, text, lines (a theme with its own page colours
  /// goes over them, see [_tonal]).
  static AraPalette palette(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // warm light grey with white tiles by day, dark graphite with lighter tiles by night (the black panel is drawn by
    // the home screen itself)
    return AraPalette(
      bg: dark ? const Color(0xFF242428) : const Color(0xFFECEBE7),
      fg: dark ? const Color(0xFFF3F1EC) : const Color(0xFF111111),
      muted: dark ? const Color(0xFF8F8C86) : const Color(0xFF6E6A64),
      card: dark ? const Color(0xFF303035) : Colors.white,
      container: dark ? const Color(0xFF34343A) : const Color(0xFFF7F6F3),
      high: dark ? const Color(0xFF3A3A40) : const Color(0xFFF1F0EC),
      highest: dark ? const Color(0xFF424248) : const Color(0xFFE6E4DF),
      line: dark ? const Color(0xFF45454B) : const Color(0xFFD4D1CB),
      strongLine: dark ? const Color(0xFF55555B) : const Color(0xFFB4B0A8),
      // the menu as black as the connect panel over it
      nav: const Color(0xFF0B0B0C),
    );
  }

  /// The one layout in its theme's colours, by day or night.
  ThemeData _styledTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final theme = colours;
    ContrastColours.active = theme;
    final plain = palette(brightness);
    // a theme with its own page colours (a tonal palette, a Glass scheme): the page, the cards and the lines in its
    // own shades
    final tonal = dark ? theme.night != null : theme.day != null;
    final p = tonal ? _tonal(plain, theme, dark) : plain;
    // a dialog, a sheet or a menu lies over the page's content: solid
    final solid = p.card;
    final accentColour = theme.accent(brightness);
    // by day, a light or grey palette: graphite icons and figures (its colour stays on the fills)
    final inkDay = !dark && theme.inkByDay;
    // readable on the page, and on the lighter blocks of a tonal theme by night
    final primary = inkDay ? ContrastPalette.ink : AraLook.readableOn(accentColour, tonal && dark ? p.card : p.bg);
    final onPrimary = primary.computeLuminance() > .45 ? const Color(0xFF111111) : Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: accentColour, brightness: brightness).copyWith(
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

    // body text and headings in Golos Text
    const body = 'Golos Text';
    // the menu is black by day too: its idle tabs in a grey that reads on it
    const navMuted = Color(0xFF8F8C86);
    final base = (dark ? Typography.material2021().white : Typography.material2021().black).apply(
      fontFamily: body,
      bodyColor: p.fg,
      displayColor: p.fg,
    );
    // headings medium and tight, as the big figures
    TextStyle? heading(TextStyle? s, double spacing) =>
        s?.copyWith(fontFamily: 'Golos Text', fontWeight: FontWeight.w600, letterSpacing: spacing * .8);
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

    const radius = 20.0;
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
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
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
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : navMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: body,
            fontSize: 11.5,
            color: s.contains(WidgetState.selected) ? primary : navMuted,
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

  /// The graph's colours and the fills: Contrast's block is a light (or dark) glass card, the download in the accent
  /// and the upload across the colour wheel.
  AraLook _styledLook(Brightness brightness, AraPalette p, Color primary) {
    final dark = brightness == Brightness.dark;
    final theme = colours;
    final blockColours = dark
        ? const [Color(0xFF1D1D21), Color(0xFF141417), Color(0xFF0F0F11)]
        : const [Colors.white, Color(0xFFFAFAFB), Color(0xFFF2F2F5)];
    final block = blockColours[blockColours.length ~/ 2];
    final schemeAccent = theme.accent(brightness);
    final colourless = HSLColor.fromColor(schemeAccent).saturation < .12;
    final Color down;
    final Color up;
    if (colourless) {
      down = dark ? const Color(0xFF3B9BFF) : const Color(0xFF1F66E5);
      up = dark ? const Color(0xFFFF9F2E) : const Color(0xFFD9590B);
    } else {
      final hsl = HSLColor.fromColor(primary);
      down = primary;
      up = hsl.withHue((hsl.hue + 150) % 360).toColor();
    }
    return AraLook(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: blockColours),
      onGradient: p.fg,
      fastPing: primary,
      fill: !dark && theme.inkByDay ? theme.warm : null,
      dark: dark,
      border: p.line,
      graphDown: AraLook.readableOn(down, block),
      graphUp: AraLook.readableOn(up, block),
      pingOn: p.card,
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
