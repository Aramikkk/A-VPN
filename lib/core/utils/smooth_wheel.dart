import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// Smooth mouse-wheel scrolling on the computer. Flutter moves a list by the whole wheel step at once, which on a
/// fast monitor looks like a jump; here each wheel step is let out over the next frames instead (most of it in the
/// first ~100 ms, easing out), for every list in the app at once. It sits in front of Flutter's own pointer
/// handling: a wheel event is held back and replayed in small pieces at the same spot; everything else passes
/// straight through.
class SmoothWheel {
  SmoothWheel._(this._forward);

  /// One that passes its pieces to [forward], for tests.
  @visibleForTesting
  SmoothWheel.forTest(PointerDataPacketCallback forward) : this._(forward);

  /// Takes a packet as the binding would.
  @visibleForTesting
  void handle(PointerDataPacket packet) => _handle(packet);

  /// how quickly the held-back scroll is let out: the time constant of the easing
  static const _tau = 0.045;

  final PointerDataPacketCallback _forward;
  PointerData? _last;
  double _x = 0;
  double _y = 0;
  bool _scheduled = false;
  Duration? _previous;

  /// Puts smooth scrolling in front of the binding's pointer handling (the computer only; call it after the binding
  /// is set up).
  static void install() {
    if (!PlatformUtils.isDesktop) return;
    final dispatcher = PlatformDispatcher.instance;
    final forward = dispatcher.onPointerDataPacket;
    if (forward == null) return;
    dispatcher.onPointerDataPacket = SmoothWheel._(forward)._handle;
  }

  void _handle(PointerDataPacket packet) {
    final rest = <PointerData>[];
    for (final datum in packet.data) {
      if (datum.signalKind == PointerSignalKind.scroll && datum.kind == PointerDeviceKind.mouse) {
        // a turn the other way drops what's left of the last one
        if (datum.scrollDeltaY * _y < 0) _y = 0;
        if (datum.scrollDeltaX * _x < 0) _x = 0;
        _x += datum.scrollDeltaX;
        _y += datum.scrollDeltaY;
        _last = datum;
        _schedule();
      } else {
        rest.add(datum);
      }
    }
    if (rest.isNotEmpty) _forward(PointerDataPacket(data: rest));
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_frame);
  }

  void _frame(Duration now) {
    _scheduled = false;
    final last = _last;
    if (last == null) return;
    final dt = _previous == null ? 1 / 120 : ((now - _previous!).inMicroseconds / 1e6).clamp(1 / 1000, 1 / 20);
    _previous = now;
    final share = 1 - math.exp(-dt / _tau);
    var dx = _x * share;
    var dy = _y * share;
    // the last few pixels go at once, so it doesn't creep
    if ((_x - dx).abs() < 2) dx = _x;
    if ((_y - dy).abs() < 2) dy = _y;
    _x -= dx;
    _y -= dy;
    if (dx != 0 || dy != 0) {
      _forward(
        PointerDataPacket(
          data: [
            PointerData(
              viewId: last.viewId,
              embedderId: last.embedderId,
              timeStamp: last.timeStamp,
              kind: last.kind,
              signalKind: PointerSignalKind.scroll,
              device: last.device,
              physicalX: last.physicalX,
              physicalY: last.physicalY,
              scrollDeltaX: dx,
              scrollDeltaY: dy,
            ),
          ],
        ),
      );
    }
    if (_x != 0 || _y != 0) {
      _schedule();
    } else {
      _previous = null;
    }
  }
}
