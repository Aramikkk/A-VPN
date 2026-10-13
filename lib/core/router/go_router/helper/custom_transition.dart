import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/utils/utils.dart';

enum TransitionType { slide, fade }

Page<dynamic> customTransition(TransitionType transition, LocalKey pageKey, Widget child) {
  // On iOS, use CupertinoPage so pages get the native interactive (edge-swipe)
  // back gesture. CustomTransitionPage does not support that gesture.
  if (PlatformUtils.isIOS) {
    return CupertinoPage<dynamic>(key: pageKey, child: child);
  }
  // a fade-through: the page underneath fades out as the new one fades in, coming in from a little to the side
  // (slide) or a little below (fade). A plain slide over it showed both at once: with see-through pages (Glass)
  // the two pages' text ran into each other for the length of the slide
  final offset = transition == TransitionType.slide ? const Offset(.06, 0) : const Offset(0, .02);
  return CustomTransitionPage<dynamic>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final incoming = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      // the page being covered fades out over the first half
      final covered = CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0, .5, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: ReverseAnimation(covered),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(.3, 1, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero).animate(incoming),
            textDirection: Directionality.of(context),
            child: child,
          ),
        ),
      );
    },
  );
}
