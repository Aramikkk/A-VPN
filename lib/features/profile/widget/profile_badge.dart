import 'package:flutter/material.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show sigmaName;
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A mark of a subscription: a coloured circle with the first letter of its name.
typedef ProfileBadge = ({String letter, String glyph, Color colour});

/// The marks of the subscriptions in the work, the active profile first, then the added ones in the order they were
/// added; the same order the servers are numbered in (see ProfileMerge). Empty with one subscription: nothing to tell
/// apart, so no marks.
final profileBadgesProvider = Provider<List<ProfileBadge>>((ref) {
  final ready = ref.watch(sharedPreferencesProvider).hasValue;
  final extras = ready ? ref.watch(Preferences.extraProfiles) : const <String>[];
  final active = ref.watch(activeProfileProvider).valueOrNull;
  final profiles = ref.watch(profilesNotifierProvider).valueOrNull ?? const <ProfileEntity>[];
  final byId = {for (final profile in profiles) profile.id: profile};
  final used = [
    if (active != null) active,
    for (final id in extras)
      if (id != active?.id && byId[id] != null) byId[id]!,
  ];
  final badges = used.length < 2 ? const <ProfileBadge>[] : [for (final (i, p) in used.indexed) badgeOf(i, p.name)];
  profileBadgesNow = badges;
  return badges;
});

/// [profileBadgesProvider] for the places with no `ref` (a name worked out in a static method): as of the last time it
/// was worked out.
List<ProfileBadge> profileBadgesNow = const [];

const _colours = [Color(0xFF4F8CFF), Color(0xFFF0A030), Color(0xFF45B97C), Color(0xFFB36BFF), Color(0xFFE5483B)];

/// The mark of the [index]th subscription, [name] its name.
ProfileBadge badgeOf(int index, String name) {
  final text = sigmaName(name).trim();
  final letter = text.isEmpty ? '?' : String.fromCharCode(text.runes.first).toUpperCase();
  final code = letter.codeUnitAt(0);
  // as text (where no widget fits): a circled Latin letter, or a circled digit for any other alphabet
  final glyph = code >= 0x41 && code <= 0x5A
      ? String.fromCharCode(0x24B6 + code - 0x41)
      : String.fromCharCode(0x2460 + (index % 20));
  return (letter: letter, glyph: glyph, colour: _colours[index % _colours.length]);
}

/// Which subscription a server of the running config is from: the provider's own `§ N` ending of its name is shifted by
/// 1000 for each added profile (see ProfileMerge), so N ~/ 1000 is the index. The active profile is 0.
int profileOfTag(String tag) {
  final match = RegExp(r'§\s*(\d+)\s*$').firstMatch(tag.replaceAll('§hide§', '').trimRight());
  final number = match == null ? 0 : int.parse(match.group(1)!);
  return number ~/ 1000;
}

/// A server's mark as text (a circled letter) for the lists that are text only; empty with one subscription.
String profileGlyph(int profile) =>
    profile >= 0 && profile < profileBadgesNow.length ? profileBadgesNow[profile].glyph : '';

/// The coloured circle with the subscription's letter; nothing with one subscription.
class ProfileBadgeDot extends ConsumerWidget {
  const ProfileBadgeDot({super.key, required this.profile, this.size = 15});

  final int profile;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(profileBadgesProvider);
    if (profile < 0 || profile >= badges.length) return const SizedBox.shrink();
    final badge = badges[profile];
    final ink = ThemeData.estimateBrightnessForColor(badge.colour) == Brightness.dark
        ? Colors.white
        : const Color(0xFF11151A);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: badge.colour,
        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.2),
      ),
      child: Text(
        badge.letter,
        style: TextStyle(color: ink, fontSize: size * .6, height: 1, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// A flag (or its circle) with the mark of its subscription on its lower right corner.
class FlagBadge extends ConsumerWidget {
  const FlagBadge({super.key, required this.profile, required this.child, this.size = 15});

  final int profile;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(profileBadgesProvider);
    if (profile < 0 || profile >= badges.length) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -size * .3,
          bottom: -size * .3,
          child: ProfileBadgeDot(profile: profile, size: size),
        ),
      ],
    );
  }
}
