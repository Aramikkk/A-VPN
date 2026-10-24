import 'package:flutter/widgets.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A-VPN's light version has two switches (Settings → General), independent of each other.
///
/// The light look: no see-through blocks and no pictures behind them (a flat colour), no gliding of the arcs and
/// the water, no sliding of the pages, a smaller cache of pictures. The colours stay.
final lightLookProvider = Provider<bool>((ref) {
  final on = ref.watch(sharedPreferencesProvider).hasValue && ref.watch(Preferences.lightLook);
  lightLookNow = on;
  // the pictures the app keeps decoded: fewer in the light look
  PaintingBinding.instance.imageCache
    ..maximumSize = on ? 60 : 150
    ..maximumSizeBytes = on ? 16 << 20 : 48 << 20;
  return on;
});

/// The light background work: what runs while the app is out of sight (and the slow polls in it) slows down and
/// stops where nobody looks; the look is the same.
final lightBackgroundProvider = Provider<bool>(
  (ref) => ref.watch(sharedPreferencesProvider).hasValue && ref.watch(Preferences.lightBackground),
);

/// The night mode: the checks sleep while the screen is locked (on by default, until the settings are read too).
final nightModeProvider = Provider<bool>(
  (ref) => !ref.watch(sharedPreferencesProvider).hasValue || ref.watch(Preferences.nightMode),
);

/// [lightLookProvider] for the places with no `ref` (a page's transition, a hook widget): as of the last time the
/// provider was worked out.
bool lightLookNow = false;

/// [normal], or no time at all in the light look.
Duration lightDuration(Duration normal) => lightLookNow ? Duration.zero : normal;
