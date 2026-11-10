import 'dart:ui' show FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/utils/custom_loggers.dart';

/// How the app draws, in the log: every 30 seconds one line with the frames drawn in them, the time the UI thread
/// took to build a frame and the time the raster thread took to draw it (average and worst), and how many frames
/// ran over a 60 Hz frame (16.7 ms) and over two (33 ms). A screen that has nothing moving draws no frames at
/// all, so a line with many frames per second at rest shows something redrawing for nothing. The line also says how
/// many of the frames had an animation running (a ticker) as against the ones asked for by a change of data, and each
/// frame over 33 ms is written on its own line (the first few of a window), to be found by its time.
class FrameStats {
  FrameStats._();

  static const _window = Duration(seconds: 30);
  static bool _started = false;
  static DateTime _from = DateTime.now();
  static int _frames = 0;
  static int _slow = 0;
  static int _jank = 0;
  static int _buildSum = 0;
  static int _buildMax = 0;
  static int _rasterSum = 0;
  static int _rasterMax = 0;
  static int _animated = 0;
  static DateTime _probed = DateTime.fromMillisecondsSinceEpoch(0);

  /// the widgets found animating when the tree was looked at (every few seconds, while a frame had an animation
  /// running): their kind and how many times they were found
  static final Map<String, int> _animating = {};
  static int _slowLines = 0;

  /// how often each provider changed in the window (the busiest three go in the line)
  static final Map<String, int> _updates = {};

  /// An observer for the container: counts the providers' changes.
  static final ProviderObserver observer = _UpdateCounter();

  static void start() {
    if (_started) return;
    _started = true;
    _from = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback(_collect);
    // at the end of each frame: is an animation still running (it will ask for the next frame), or not
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (SchedulerBinding.instance.transientCallbackCount > 0) {
        _animated++;
        _probe();
      }
    });
  }

  /// Looks through the widget tree for what animates: the implicitly animated widgets (AnimatedOpacity, a tween
  /// builder, ...) whose controller is running, and the widgets driven by an animation that is running. At most once in
  /// three seconds, and only while a frame has an animation running, so a screen at rest costs nothing.
  static void _probe() {
    final now = DateTime.now();
    if (now.difference(_probed) < const Duration(seconds: 3)) return;
    _probed = now;
    void visit(Element element) {
      final widget = element.widget;
      String? kind;
      if (element is StatefulElement && element.state is ImplicitlyAnimatedWidgetState) {
        // ignore: invalid_use_of_protected_member
        if ((element.state as ImplicitlyAnimatedWidgetState).controller.isAnimating)
          kind = widget.runtimeType.toString();
      } else if (widget is AnimatedWidget) {
        final animation = widget.listenable;
        if (animation is Animation &&
            animation.status != AnimationStatus.completed &&
            animation.status != AnimationStatus.dismissed) {
          kind = widget.runtimeType.toString();
        }
      }
      if (kind != null) _animating[kind] = (_animating[kind] ?? 0) + 1;
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  static void _collect(List<FrameTiming> timings) {
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds;
      final raster = t.rasterDuration.inMicroseconds;
      _frames++;
      _buildSum += build;
      _rasterSum += raster;
      if (build > _buildMax) _buildMax = build;
      if (raster > _rasterMax) _rasterMax = raster;
      final total = t.totalSpan.inMicroseconds;
      if (total > 16700) _slow++;
      if (total > 33400) {
        _jank++;
        if (_slowLines++ < 6) {
          appLogger('perf').info(
            'slow frame: ${(total / 1000).toStringAsFixed(1)} ms (build ${(build / 1000).toStringAsFixed(1)}, '
            'raster ${(raster / 1000).toStringAsFixed(1)})',
          );
        }
      }
    }
    final now = DateTime.now();
    final elapsed = now.difference(_from);
    if (elapsed < _window) return;
    if (_frames > 0) {
      String ms(int micro) => (micro / 1000).toStringAsFixed(1);
      final busiest = (_updates.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(6);
      appLogger('perf').info(
        '${_frames} frames in ${elapsed.inSeconds} s (${(_frames / elapsed.inSeconds).toStringAsFixed(1)}/s): '
        'build avg ${ms(_buildSum ~/ _frames)} max ${ms(_buildMax)} ms, '
        'raster avg ${ms(_rasterSum ~/ _frames)} max ${ms(_rasterMax)} ms, '
        'over 16.7 ms: $_slow, over 33 ms: $_jank; frames with an animation running: $_animated '
        '(found animating: ${(_animating.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).map((e) => '${e.key} ${e.value}').join(', ')}); providers changed: '
        '${busiest.map((e) => '${e.key} ${e.value}').join(', ')}',
      );
    }
    _updates.clear();
    _animating.clear();
    _from = now;
    _frames = _slow = _jank = _buildSum = _buildMax = _rasterSum = _rasterMax = _animated = _slowLines = 0;
  }
}

class _UpdateCounter extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final name = provider.name ?? provider.runtimeType.toString();
    FrameStats._updates[name] = (FrameStats._updates[name] ?? 0) + 1;
  }
}
