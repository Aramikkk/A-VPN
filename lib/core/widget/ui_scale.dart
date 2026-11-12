import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The whole app drawn [scale] times its size (a car's screen is far from the eyes, a small phone close): the child is
/// laid out in a screen 1/[scale] as large and scaled up to fill the real one, with touches mapped back; the text is
/// scaled on its own by [fontScale] on top of the system's.
/// How much larger everything is made by itself on a big landscape screen of a phone-like system (a car's, a tablet's: a
/// BYD Han's is a metre across): 1 on a phone and in portrait, up to 1.8 on the widest, so the touch targets and the text
/// are as at hand there as on a phone. What the user sets in Settings → Themes comes on top of it.
double autoUiScale(Size size) {
  if (size.width < 1000 || size.width <= size.height) return 1.0;
  // never so large that the page is left under 600 high: below that the home screen drops its blocks (a car's screen is wide
  // and low), and what is not there cannot be read at any size
  return (size.width / 800).clamp(1.0, 1.8).clamp(1.0, math.max(1.0, size.height / 600));
}

class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.scale, required this.fontScale, required this.child});

  final double scale;
  final double fontScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var data = MediaQuery.of(context);
    if (fontScale != 1) {
      data = data.copyWith(textScaler: _Times(data.textScaler, fontScale));
    }
    if (scale == 1) return MediaQuery(data: data, child: child);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth / scale;
        final height = box.maxHeight / scale;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: data.copyWith(
                  size: Size(width, height),
                  padding: data.padding / scale,
                  viewPadding: data.viewPadding / scale,
                  viewInsets: data.viewInsets / scale,
                  systemGestureInsets: data.systemGestureInsets / scale,
                ),
                child: SizedBox(width: width, height: height, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The system's text scaler with one more factor over it.
class _Times extends TextScaler {
  const _Times(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => base.scale(1) * factor;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) =>
      TextScaler.linear((base.scale(1) * factor).clamp(minScaleFactor, maxScaleFactor));

  @override
  bool operator ==(Object other) => other is _Times && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
