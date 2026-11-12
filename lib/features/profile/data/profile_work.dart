import 'package:flutter/foundation.dart';

/// Which subscriptions are in the work, and which of them is the main one.
///
/// The Profiles page lists the subscriptions in the order the user dragged them into. Each one is on or off: the ones
/// that are on are in the work. The top one that is on is the main one (the core's active profile, the one the home
/// screen names); the other ones that are on add their servers to it (the added ones).

/// The main profile and the added ones for [orderedIds] (in the order shown) with [off] switched off.
({String? main, List<String> extras}) workingProfiles(List<String> orderedIds, Set<String> off) {
  final on = [
    for (final id in orderedIds)
      if (!off.contains(id)) id,
  ];
  if (on.isEmpty) return (main: null, extras: const <String>[]);
  return (main: on.first, extras: on.sublist(1));
}

/// Whether [id] may be switched off: never the last one that is on (there would be nothing to connect to).
bool canSwitchOff(List<String> orderedIds, Set<String> off, String id) {
  if (off.contains(id)) return true;
  final stillOn = orderedIds.where((other) => other != id && !off.contains(other));
  return stillOn.isNotEmpty;
}

/// What is switched off when the old way of choosing (one active profile and the added ones) is moved over: every
/// profile that was neither the active one nor an added one. With no active profile known, nothing is switched off.
Set<String> offFromOldModel(List<String> allIds, {required String? activeId, required List<String> extras}) {
  if (activeId == null && extras.every((id) => !allIds.contains(id))) return <String>{};
  return {
    for (final id in allIds)
      if (id != activeId && !extras.contains(id)) id,
  };
}

/// Whether the core's active profile and the added ones are not as [workingProfiles] says they should be.
bool workNeedsSync(List<String> orderedIds, Set<String> off, {required String? activeId, required List<String> extras}) {
  final want = workingProfiles(orderedIds, off);
  if (want.main == null) return false;
  if (activeId != want.main) return true;
  return extras.length != want.extras.length || !extras.toSet().containsAll(want.extras);
}

/// The subscription whose settings were asked for by a tap on it (Settings → Profile management opens that one);
/// null: the active one.
final profileManagementFocus = ValueNotifier<String?>(null);

/// The order to keep when some shown profile has no place in the kept [order] yet (none was ever kept, or a profile was
/// added): the order shown now. Null when every shown one has its place. Without it the list follows the sort (by the
/// last update, as a rule), and a subscription that updates would move to the top and become the main one by itself.
List<String>? orderToPin(List<String> order, List<String> shownIds) {
  if (shownIds.isEmpty) return null;
  final kept = order.toSet();
  return shownIds.every(kept.contains) ? null : [...shownIds];
}
