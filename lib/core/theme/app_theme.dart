import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/utils/platform_utils.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  /// Light: white backgrounds and a deeper A-VPN green (the acid green doesn't read on white), whatever the
  /// wallpaper colours.
  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    if (PlatformUtils.isDesktop) return _windowsTheme(Brightness.light);
    const white = Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF9EFF1F)).copyWith(
      primary: const Color(0xFF3B8A00),
      onPrimary: white,
      primaryContainer: const Color(0xFFE2F9C8),
      onPrimaryContainer: const Color(0xFF142B00),
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
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
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

  /// OLED black: true black backgrounds, near-black cards and the A-VPN acid green, whatever the wallpaper colours.
  ThemeData _oledTheme() {
    const black = Colors.black;
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF9EFF1F), brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF9EFF1F),
      onPrimary: black,
      primaryContainer: const Color(0xFF1F3A05),
      onPrimaryContainer: const Color(0xFFD9FFB0),
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
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  /// Windows 11 look for the desktop: the Mica-grey window, white (or dark grey) cards, the Windows accent blue
  /// and a blue gradient for the highlights.
  ThemeData _windowsTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0078D4), brightness: brightness).copyWith(
      primary: dark ? const Color(0xFF60CDFF) : const Color(0xFF005FB8),
      onPrimary: dark ? const Color(0xFF00243A) : Colors.white,
      primaryContainer: dark ? const Color(0xFF0B3F70) : const Color(0xFFCCE4F7),
      onPrimaryContainer: dark ? const Color(0xFFCDEBFF) : const Color(0xFF002A4D),
      secondary: dark ? const Color(0xFF99D9FF) : const Color(0xFF0A6CC2),
      tertiary: dark ? const Color(0xFF9FB8FF) : const Color(0xFF3A5BC7),
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
      fontFamily: fontFamily,
      extensions: <ThemeExtension<dynamic>>{
        ConnectionButtonTheme.light,
        if (dark) AraLook.windowsDark else AraLook.windowsLight,
      },
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
