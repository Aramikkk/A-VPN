import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A-VPN's own Android tools (see AraToolsHandler.kt): an app's icon drawn as the launcher draws it, and the installer for
/// the downloaded update.
final _log = appLogger('AppIcons');

abstract class AraTools {
  static const _channel = MethodChannel('com.aravpn.app/tools');

  /// The icon of the app [package] as a PNG, or null (not Android, no such app, no icon).
  static Future<Uint8List?> appIcon(String package) async {
    if (!Platform.isAndroid) return null;
    try {
      final answer = await _channel.invokeMethod<Map<Object?, Object?>>('appIcon', {'package': package});
      final icon = answer?['icon'];
      if (icon is Uint8List && icon.isNotEmpty) return icon;
      // what each source said, so the log shows why an app is drawn as a letter
      _log.warning('no icon for $package:${answer?['why']}');
      return null;
    } catch (e) {
      _log.warning('no icon for $package: $e');
      return null;
    }
  }

  /// Hands the APK at [path] to the system's installer: "ok", "permission" (the page where the user lets A-VPN install
  /// apps was opened; try again after), or "error".
  static Future<String> install(String path, {bool allowSettings = true}) async {
    if (!Platform.isAndroid) return 'error';
    try {
      return await _channel.invokeMethod<String>('install', {'path': path, 'allowSettings': allowSettings}) ?? 'error';
    } catch (_) {
      return 'error';
    }
  }
}

/// The icons of apps the installed-apps list had none for, asked from the system by package, one at a time as they are
/// wanted. The state is a map of package to icon; [want] starts what is not asked yet.
final nativeIconsProvider = NotifierProvider<NativeIcons, Map<String, Uint8List>>(NativeIcons.new);

class NativeIcons extends Notifier<Map<String, Uint8List>> {
  final _asked = <String>{};

  @override
  Map<String, Uint8List> build() => const {};

  void want(Iterable<String> packages) {
    for (final package in packages) {
      if (package.isEmpty || !_asked.add(package)) continue;
      unawaited(_load(package));
    }
  }

  Future<void> _load(String package) async {
    if (!Platform.isAndroid) return;
    // an icon that did not come is asked for again a few times: the first ask can be too early (the app is only being
    // installed or updated) and a package that answers nothing is not asked for ever after
    for (var attempt = 0; attempt < 3; attempt++) {
      final icon = await AraTools.appIcon(package);
      if (icon != null && icon.isNotEmpty) {
        state = {...state, package: icon};
        return;
      }
      await Future<void>.delayed(Duration(seconds: 15 * (attempt + 1)));
    }
  }
}
