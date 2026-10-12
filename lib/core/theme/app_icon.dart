import 'package:flutter/services.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// The home-screen icon follows the colour theme (Android): the Mono themes have an icon in their colour, the
/// others keep the red one.
abstract class AppIcon {
  static const _channel = MethodChannel('com.aravpn.app/icon');
  static String? _applied;

  static Future<void> follow(AraAccent accent) async {
    if (!PlatformUtils.isAndroid) return;
    final icon = accent.icon ?? 'red';
    if (icon == _applied) return;
    try {
      await _channel.invokeMethod<bool>('setIcon', icon);
      _applied = icon;
    } catch (_) {
      // an older build without the handler: the icon just stays
    }
  }
}
