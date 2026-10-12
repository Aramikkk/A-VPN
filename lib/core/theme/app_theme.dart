import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/utils/platform_utils.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily, {AraAccent? accent}) : accent = accent ?? AraAccent.platformDefault;
  final AppThemeMode mode;
  final String fontFamily;

  /// the accent colour and gradient (Settings → General → Colour theme)
  final AraAccent accent;

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

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
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
