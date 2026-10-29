import 'package:flutter/material.dart';

/// Keep the curve's status listener for the lifetime of the transition, rather
/// than allocating a new CurvedAnimation on each route animation tick.
class HomePopupTransition extends StatefulWidget {
  const HomePopupTransition({
    super.key,
    required this.animation,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Animation<double> animation;
  final Widget child;
  final Alignment alignment;

  @override
  State<HomePopupTransition> createState() => _HomePopupTransitionState();
}

class _HomePopupTransitionState extends State<HomePopupTransition> {
  late CurvedAnimation _curve;
  late Animation<double> _scale;

  void _attach() {
    _curve = CurvedAnimation(parent: widget.animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _scale = Tween<double>(begin: .96, end: 1).animate(_curve);
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(HomePopupTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curve.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    // the card is drawn once and the fade and scale move that picture: otherwise every frame of the opening redraws
    // the whole list into a temporary layer
    child: ScaleTransition(
      scale: _scale,
      alignment: widget.alignment,
      child: RepaintBoundary(child: widget.child),
    ),
  );
}
