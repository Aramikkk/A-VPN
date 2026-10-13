import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/utils/utils.dart';

enum TransitionType { slide, fade }

Page<dynamic> customTransition(TransitionType transition, LocalKey pageKey, Widget child) {
  // On iOS, use CupertinoPage so pages get the native interactive (edge-swipe)
  // back gesture. CustomTransitionPage does not support that gesture.
  if (PlatformUtils.isIOS) {
    return CupertinoPage<dynamic>(key: pageKey, child: child);
  }
  // the usual way: a page slides in from the right over the one under it, which moves a little to the left; a fade
  // for the few that fade. The page carries its own background (Glass: the backdrop), so the one under it never
  // shows through a see-through page while they move
  return CustomTransitionPage<dynamic>(
    key: pageKey,
    child: _Opaque(child: child),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (transition == TransitionType.fade) return FadeTransition(opacity: animation, child: child);
      final incoming = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final covered = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: const Offset(-.25, 0)).animate(covered),
        textDirection: Directionality.of(context),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(incoming),
          textDirection: Directionality.of(context),
          child: child,
        ),
      );
    },
  );
}

/// A page on its own background: Glass's backdrop, or the theme's page colour.
class _Opaque extends StatelessWidget {
  const _Opaque({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = theme.araLook.glass;
    if (glass == null) return ColoredBox(color: theme.scaffoldBackgroundColor, child: child);
    return Stack(
      fit: StackFit.expand,
      children: [
        GlassBackdrop(look: glass),
        child,
      ],
    );
  }
}
