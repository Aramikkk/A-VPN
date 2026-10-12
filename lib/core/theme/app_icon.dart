import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// The home-screen icon follows the colour theme (Android): the Mono themes have an icon in their colour, the
/// others keep the red one.
///
/// The switch waits until the app leaves the screen: turning off the launcher entry the app was opened from can
/// make some launchers (Samsung's among them) close the app on the spot.
abstract class AppIcon {
  static const _channel = MethodChannel('com.aravpn.app/icon');
  static String? _applied;
  static String? _wanted;
  static AppLifecycleListener? _listener;

  static void follow(AraAccent accent) {
    if (!PlatformUtils.isAndroid) return;
    _wanted = accent.icon ?? 'red';
    _listener ??= AppLifecycleListener(onHide: _apply, onPause: _apply, onDetach: _apply);
  }

  static Future<void> _apply() async {
    final icon = _wanted;
    if (icon == null || icon == _applied) return;
    try {
      await _channel.invokeMethod<bool>('setIcon', icon);
      _applied = icon;
    } catch (_) {
      // an older build without the handler: the icon just stays
    }
  }
}
