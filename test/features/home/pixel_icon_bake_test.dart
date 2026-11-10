import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/pixel_flag.dart';

Future<ui.Image> _picture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 96, 96), Paint()..color = const Color(0xFF2A7FDB));
  canvas.drawCircle(const Offset(48, 48), 28, Paint()..color = const Color(0xFFFFFFFF));
  return recorder.endRecording().toImage(96, 96);
}

Future<Uint8List> _render(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = const Color(0xFF111111));
  draw(canvas);
  final image = await recorder.endRecording().toImage(40, 40);
  return (await image.toByteData())!.buffer.asUint8List();
}

void main() {
  queueTests();
  late PixelIcon icon;
  setUp(() {
    PixelIcons.clearBaked();
    PixelIcons.pixelRatio = 1;
  });

  testWidgets('a baked icon looks like the icon drawn directly', (tester) async {
    late Uint8List direct, baked;
    await tester.runAsync(() async {
      icon = PixelIcon(await _picture(), const Rect.fromLTWH(0, 0, 96, 96));
      const box = Rect.fromLTWH(4, 4, 32, 32);
      direct = await _render((c) => PixelIcons.paintDirect(c, box, icon));
      baked = await _render((c) => PixelIcons.paint(c, box, icon));
    });
    var worst = 0;
    for (var i = 0; i < direct.length; i++) {
      final d = (direct[i] - baked[i]).abs();
      if (d > worst) worst = d;
    }
    expect(worst, lessThanOrEqualTo(40), reason: 'the baked icon must be the same picture');
  });

  testWidgets('an icon is baked once for a size, however often it is drawn', (tester) async {
    await tester.runAsync(() async {
      icon = PixelIcon(await _picture(), const Rect.fromLTWH(0, 0, 96, 96));
      const box = Rect.fromLTWH(4, 4, 32, 32);
      for (var i = 0; i < 5; i++) {
        await _render((c) => PixelIcons.paint(c, box, icon));
      }
    });
    expect(PixelIcons.bakedCount, 1);
  });

  testWidgets('another size or another edge colour is another baked picture', (tester) async {
    await tester.runAsync(() async {
      icon = PixelIcon(await _picture(), const Rect.fromLTWH(0, 0, 96, 96));
      await _render((c) => PixelIcons.paint(c, const Rect.fromLTWH(4, 4, 32, 32), icon));
      await _render((c) => PixelIcons.paint(c, const Rect.fromLTWH(4, 4, 24, 24), icon));
      await _render((c) => PixelIcons.paint(c, const Rect.fromLTWH(4, 4, 32, 32), icon, edge: const Color(0xFFFFFFFF)));
    });
    expect(PixelIcons.bakedCount, 3);
  });
}

void queueTests() {
  testWidgets('icons are baked one to a frame, not all in the frame they appear in', (tester) async {
    PixelIcon? a, b, c;
    await tester.runAsync(() async {
      final image = await _picture();
      a = PixelIcon(image, const Rect.fromLTWH(0, 0, 96, 96));
      b = PixelIcon(await _picture(), const Rect.fromLTWH(0, 0, 96, 96));
      c = PixelIcon(await _picture(), const Rect.fromLTWH(0, 0, 96, 96));
    });
    const size = Size.square(32);
    const edge = Color(0xFF000000);
    for (final icon in [a!, b!, c!]) {
      PixelIcons.bakeLater(icon, size, edge);
    }
    expect(PixelIcons.bakedCount, 0, reason: 'nothing is baked inside the frame that asked');
    await tester.pump();
    expect(PixelIcons.bakedCount, 1);
    await tester.pump();
    expect(PixelIcons.bakedCount, 2);
    await tester.pump();
    expect(PixelIcons.bakedCount, 3);
    expect(PixelIcons.isBaked(a!, size, edge), isTrue);
    expect(PixelIcons.isBaked(c!, size, edge), isTrue);
  });

  testWidgets('asking again for one that is queued or baked adds nothing', (tester) async {
    PixelIcon? a;
    await tester.runAsync(() async => a = PixelIcon(await _picture(), const Rect.fromLTWH(0, 0, 96, 96)));
    const size = Size.square(32);
    const edge = Color(0xFF000000);
    PixelIcons.bakeLater(a!, size, edge);
    PixelIcons.bakeLater(a!, size, edge);
    await tester.pump();
    await tester.pump();
    PixelIcons.bakeLater(a!, size, edge);
    await tester.pump();
    expect(PixelIcons.bakedCount, 1);
  });
}
