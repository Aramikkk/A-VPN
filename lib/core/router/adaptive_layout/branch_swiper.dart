import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The phone's tabs, kept alive like an indexed stack. A sideways drag moves the tab under the finger with the next
/// (or previous) one coming in beside it; let go past a quarter of the width, or with a flick, and it goes on to
/// that tab, otherwise it slides back. A tab chosen in the menu slides in the same way.
class BranchSwiper extends StatefulWidget {
  const BranchSwiper({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<BranchSwiper> createState() => _BranchSwiperState();
}

class _BranchSwiperState extends State<BranchSwiper> with TickerProviderStateMixin {
  /// the change of tab: 0 the old one in place, 1 the new one in place
  late final _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  /// a drag let go short of the next tab, sliding back
  late final _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  late int _current = widget.navigationShell.currentIndex;
  int? _previous;

  /// 1: the new tab comes in from the right, -1: from the left
  double _direction = 1;

  /// how far the finger has moved the tab, as a share of the width: below 0 towards the next tab
  double _drag = 0;

  /// where a drag let go: the change of tab it starts carries on from there
  double? _from;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _drag = _backFrom * (1 - Curves.easeOutCubic.transform(_back.value))));
  }

  double _backFrom = 0;

  @override
  void didUpdateWidget(BranchSwiper old) {
    super.didUpdateWidget(old);
    final index = widget.navigationShell.currentIndex;
    if (index != _current) {
      _direction = index > _current ? 1 : -1;
      _previous = _current;
      _current = index;
      final from = _from ?? 0;
      _from = null;
      _drag = 0;
      _slide.value = from;
      _slide
          .animateTo(1, duration: _slide.duration! * (1 - from).clamp(.35, 1.0), curve: Curves.easeOutCubic)
          .whenComplete(() {
            if (mounted) setState(() => _previous = null);
          });
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _back.dispose();
    super.dispose();
  }

  int? _neighbour(double drag) {
    final next = _current + (drag < 0 ? 1 : -1);
    return drag == 0 || next < 0 || next >= widget.children.length ? null : next;
  }

  void _dragged(DragUpdateDetails details) {
    if (_previous != null) return;
    _back.stop();
    final width = context.size?.width ?? 1;
    var drag = _drag + (details.primaryDelta ?? 0) / width;
    // no tab that way: it gives a little and stops
    if (_neighbour(drag) == null) drag = drag.clamp(-.06, .06);
    setState(() => _drag = drag.clamp(-1.0, 1.0));
  }

  void _released(DragEndDetails details) {
    if (_previous != null || _drag == 0) return;
    final velocity = details.primaryVelocity ?? 0;
    final next = _neighbour(_drag);
    final flick = velocity.abs() > 350 && (velocity < 0) == (_drag < 0);
    if (next != null && (_drag.abs() > .25 || flick)) {
      _from = _drag.abs();
      widget.navigationShell.goBranch(next);
    } else {
      _backFrom = _drag;
      _back.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neighbour = _previous == null ? _neighbour(_drag) : null;
    Widget at(int i, double x, {required bool live}) => FractionalTranslation(
      translation: Offset(x, 0),
      child: live
          ? TickerMode(enabled: true, child: widget.children[i])
          : IgnorePointer(child: TickerMode(enabled: false, child: widget.children[i])),
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _dragged,
      onHorizontalDragEnd: _released,
      onHorizontalDragCancel: () => _released(DragEndDetails()),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            final t = _slide.value;
            return Stack(
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  if (i == _current)
                    at(i, _previous != null ? _direction * (1 - t) : _drag, live: true)
                  else if (i == _previous)
                    at(i, -_direction * t, live: false)
                  else if (i == neighbour)
                    at(i, _drag + (_drag < 0 ? 1 : -1), live: false)
                  else
                    Offstage(child: TickerMode(enabled: false, child: widget.children[i])),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The computer's tabs, kept alive like an indexed stack: the new tab fades in and rises a few pixels instead of
/// appearing at once. The hidden tabs stop their animations (and the pages that check it stop following their
/// data until they're back on screen).
class BranchFader extends StatefulWidget {
  const BranchFader({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<BranchFader> createState() => _BranchFaderState();
}

class _BranchFaderState extends State<BranchFader> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);
  late int _current = widget.navigationShell.currentIndex;

  @override
  void didUpdateWidget(BranchFader old) {
    super.didUpdateWidget(old);
    final index = widget.navigationShell.currentIndex;
    if (index != _current) {
      _current = index;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    return Stack(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i == _current)
            AnimatedBuilder(
              animation: curve,
              builder: (context, child) => Opacity(
                opacity: curve.value,
                child: Transform.translate(offset: Offset(0, 10 * (1 - curve.value)), child: child),
              ),
              child: TickerMode(enabled: true, child: widget.children[i]),
            )
          else
            Offstage(child: TickerMode(enabled: false, child: widget.children[i])),
      ],
    );
  }
}
