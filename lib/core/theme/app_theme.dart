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

  AraLook _look(Brightness brightness) => AraLook(
    gradient: accent.gradient(brightness),
    onGradient: accent.onGradient(brightness),
    fastPing: brightness == Brightness.dark ? const Color(0xFF6CCB5F) : const Color(0xFF0F7B0F),
  );

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
    final background = dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3);
    final seeded = ColorScheme.fromSeed(seedColor: accent.seed, brightness: brightness);
    final scheme = seeded.copyWith(
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
