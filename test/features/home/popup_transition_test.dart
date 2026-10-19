import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/popup_transition.dart';

class _TrackedAnimation extends ProxyAnimation {
  _TrackedAnimation() : super(const AlwaysStoppedAnimation(.5));
  final listeners = <AnimationStatusListener>{};

  @override
  void addStatusListener(AnimationStatusListener listener) {
    listeners.add(listener);
    super.addStatusListener(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    listeners.remove(listener);
    super.removeStatusListener(listener);
  }
}

void main() {
  testWidgets('rebuilding a route keeps one curve listener and releases it', (tester) async {
    final animation = _TrackedAnimation();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HomePopupTransition(animation: animation, child: Text('$frame')),
        ),
      );
      expect(animation.listeners, hasLength(1));
    }
    final replacement = _TrackedAnimation();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HomePopupTransition(animation: replacement, child: const Text('new')),
      ),
    );
    expect(animation.listeners, isEmpty);
    expect(replacement.listeners, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(replacement.listeners, isEmpty);
  });
}
