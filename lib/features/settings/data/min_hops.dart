import 'dart:math' as math;

/// The "fewer hops" mode: the server chosen stays while it is steady, and the servers are checked less often.

/// How much faster another server must be before the automatic choice leaves the one in use, in milliseconds.
const minHopsToleranceWifi = 300;
const minHopsToleranceMobile = 350;

/// How seldom the servers are checked in that mode, at the most often.
const minHopsInterval = Duration(minutes: 30);

/// The threshold the automatic choice works with: [user]'s own, or in the fewer-hops mode at least the mode's (a
/// server that stops answering is still left at once: that is watched apart from this).
int hopsTolerance({required bool minHops, required bool mobile, required int user}) =>
    minHops ? math.max(user, mobile ? minHopsToleranceMobile : minHopsToleranceWifi) : user;

/// How often the servers are checked: [user]'s own, or in the fewer-hops mode at least [minHopsInterval].
Duration hopsInterval({required bool minHops, required Duration user}) =>
    minHops && user < minHopsInterval ? minHopsInterval : user;
