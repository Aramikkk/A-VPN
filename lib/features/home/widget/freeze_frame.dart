import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The page under a popup, held as a picture while the popup is open and opens and closes. The page (the frosted
/// blocks, the backdrop images) is costly to draw, and every frame of a popup's opening drew it again (the first
/// frames took 35 ms); a picture of it looks the same and costs one drawing. The page itself stays built (only not
/// drawn), and takes over again, pixel for pixel, a moment after the popup is gone.
class FreezeFrame extends StatefulWidget {
  const FreezeFrame({super.key, required this.child});

  final Widget child;

  /// the one in the tree (the app has one shell)
  static _FreezeFrameState? _current;

  /// Takes the picture and puts it in place of the page; false when there is nothing to take (then nothing is held).
  /// Every true is to be answered by a [thawSoon].
  static Future<bool> freeze() async => await _current?._freeze() ?? false;

  /// Lets the page back after a moment (a popup opened again at once keeps the picture).
  static void thawSoon() {
    final state = _current;
    if (state == null) return;
    Timer(const Duration(milliseconds: 250), state._thaw);
  }

  @override
  State<FreezeFrame> createState() => _FreezeFrameState();
}

class _FreezeFrameState extends State<FreezeFrame> {
  final _key = GlobalKey();
  ui.Image? _image;
  int _holds = 0;

  @override
  void initState() {
    super.initState();
    FreezeFrame._current = this;
  }

  @override
  void dispose() {
    if (identical(FreezeFrame._current, this)) FreezeFrame._current = null;
    _image?.dispose();
    super.dispose();
  }

  Future<bool> _freeze() async {
    _holds++;
    if (_image != null) return true;
    final boundary = _key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      _holds--;
      return false;
    }
    try {
      final image = await boundary.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      if (!mounted) {
        image.dispose();
        return false;
      }
      setState(() => _image = image);
      // shown before the popup starts to move
      await WidgetsBinding.instance.endOfFrame;
      return true;
    } catch (_) {
      _holds--;
      return false;
    }
  }

  void _thaw() {
    if (_holds > 0) _holds--;
    final held = _image;
    if (_holds > 0 || held == null || !mounted) return;
    setState(() => _image = null);
    // not disposed under the frame that still shows it
    WidgetsBinding.instance.addPostFrameCallback((_) => held.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: image != null,
          child: TickerMode(
            enabled: image == null,
            child: RepaintBoundary(key: _key, child: widget.child),
          ),
        ),
        if (image != null) RawImage(image: image, fit: BoxFit.fill, scale: MediaQuery.devicePixelRatioOf(context)),
      ],
    );
  }
}
