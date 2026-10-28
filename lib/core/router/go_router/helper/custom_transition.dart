import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/glass_scheme.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/utils/utils.dart';

/// [fromTop]: the page comes down from the top over the one under it (the home screen's swipe down)
enum TransitionType { slide, fade, fromTop }

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
    // the light look: the page is just there, with no sliding
    transitionDuration: lightLookNow ? Duration.zero : const Duration(milliseconds: 300),
    reverseTransitionDuration: lightLookNow ? Duration.zero : const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (transition == TransitionType.fade) return FadeTransition(opacity: animation, child: child);
      if (transition == TransitionType.fromTop) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
          child: child,
        );
      }
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
    final glass = theme.glassLook;
    // Contrast: its backdrop (the page colour is see-through there), laid out as the one round it
    // (muted: these pages have their text right on it)
    if (theme.contrastLayout) return ContrastGlow(own: true, muted: true, child: child);
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
