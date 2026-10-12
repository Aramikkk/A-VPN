import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The phone's tabs, kept alive like an indexed stack, that slide sideways when the tab changes and follow a
/// left or right swipe to the next or previous tab.
class BranchSwiper extends StatefulWidget {
  const BranchSwiper({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<BranchSwiper> createState() => _BranchSwiperState();
}

class _BranchSwiperState extends State<BranchSwiper> with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late int _current = widget.navigationShell.currentIndex;
  int? _previous;

  /// 1: the new tab comes in from the right, -1: from the left
  double _direction = 1;

  @override
  void didUpdateWidget(BranchSwiper old) {
    super.didUpdateWidget(old);
    final index = widget.navigationShell.currentIndex;
    if (index != _current) {
      _direction = index > _current ? 1 : -1;
      _previous = _current;
      _current = index;
      _slide.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _previous = null);
      });
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _swiped(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 350) return;
    final next = _current + (velocity < 0 ? 1 : -1);
    if (next < 0 || next >= widget.children.length) return;
    widget.navigationShell.goBranch(next);
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _swiped,
      child: ClipRect(
        child: Stack(
          children: [
            for (var i = 0; i < widget.children.length; i++)
              if (i == _current)
                AnimatedBuilder(
                  animation: curve,
                  builder: (context, child) => FractionalTranslation(
                    translation: Offset(_previous == null ? 0 : _direction * (1 - curve.value), 0),
                    child: child,
                  ),
                  child: TickerMode(enabled: true, child: widget.children[i]),
                )
              else if (i == _previous)
                AnimatedBuilder(
                  animation: curve,
                  builder: (context, child) =>
                      FractionalTranslation(translation: Offset(-_direction * curve.value, 0), child: child),
                  child: IgnorePointer(child: TickerMode(enabled: false, child: widget.children[i])),
                )
              else
                Offstage(child: TickerMode(enabled: false, child: widget.children[i])),
          ],
        ),
      ),
    );
  }
}
