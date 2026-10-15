import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

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

  /// Contrast: the change goes up or down instead (Settings and Connections, the branches off the menu)
  bool _vertical = false;

  /// the phone's branches off Contrast's menu: Connections (from below) and Settings (from the top)
  static const _connections = 0;
  static const _settings = 4;

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
      _vertical = _contrast && {index, _current}.any((i) => i == _connections || i == _settings);
      if (_vertical) {
        // Settings come down from the top and go back up; Connections come up from below and go back down
        _direction = index == _settings || _current == _connections ? -1 : 1;
      }
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

  bool get _contrast => Theme.of(context).araLook.style == AraStyle.contrast;

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
    // every tab in the same wrapping, only its place and state changing: a tab that came into sight was rebuilt
    // in a new wrapping and stayed blank for the first frames of a drag
    Widget tab(int i, {double x = 0, bool shown = false, bool live = false}) => Offstage(
      offstage: !shown,
      child: FractionalTranslation(
        translation: _vertical && _previous != null ? Offset(0, x) : Offset(x, 0),
        child: IgnorePointer(
          ignoring: !live,
          child: TickerMode(enabled: live, child: widget.children[i]),
        ),
      ),
    );
    // Contrast: no sideways dragging between the tabs (the menu, and the home screen's long swipes up and down)
    final drags = !_contrast;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: drags ? _dragged : null,
      onHorizontalDragEnd: drags ? _released : null,
      onHorizontalDragCancel: drags ? () => _released(DragEndDetails()) : null,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            final t = _slide.value;
            return Stack(
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  if (i == _current)
                    tab(i, x: _previous != null ? _direction * (1 - t) : _drag, shown: true, live: true)
                  else if (i == _previous)
                    tab(i, x: -_direction * t, shown: true)
                  else if (i == neighbour)
                    tab(i, x: _drag + (_drag < 0 ? 1 : -1), shown: true)
                  else
                    tab(i),
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
