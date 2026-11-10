import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/model/ping_graph.dart';
import 'package:hiddify/features/home/model/site_graph.dart';
import 'package:hiddify/features/home/widget/pixel_flag.dart';

void main() {
  group('pixel flags', () {
    test('a drawn flag is a grid of 12 by 8 pixels', () {
      final grid = PixelFlag.of('🇵🇱')!;
      expect(grid.length, PixelFlag.rows);
      expect(grid.every((row) => row.length == PixelFlag.cols), isTrue);
    });

    test('Poland is white over red, Germany black, red and gold', () {
      final poland = PixelFlag.of('🇵🇱')!;
      expect(poland.first.toSet(), {const Color(0xFFF2F2EE)});
      expect(poland.last.toSet(), {const Color(0xFFD52B1E)});
      final germany = PixelFlag.of('🇩🇪')!;
      expect(germany.first.first, const Color(0xFF151515));
      expect(germany[3].first, const Color(0xFFD52B1E));
      expect(germany.last.first, const Color(0xFFFFD500));
    });

    test('the Union Jack has a red cross in the middle and blue in the field', () {
      final jack = PixelFlag.of('🇬🇧')!;
      expect(jack[3][5], const Color(0xFFD52B1E));
      expect(jack[4][6], const Color(0xFFD52B1E));
      final colours = {for (final row in jack) ...row};
      expect(colours, containsAll([const Color(0xFFD52B1E), const Color(0xFFF2F2EE), const Color(0xFF0057B8)]));
    });

    test('a country with no drawing, and what is no flag at all, have no ready grid', () {
      expect(PixelFlag.of('🇬🇷'), isNull);
      expect(PixelFlag.of('abc'), isNull);
      expect(PixelFlag.of(''), isNull);
      // one letter of a flag is not a flag
      expect(PixelFlag.of('🇵'), isNull);
    });

    test('paintPixelFlag draws a known flag, also see-through', () {
      final canvas = ui.Canvas(ui.PictureRecorder());
      expect(paintPixelFlag(canvas, '🇸🇪', const Offset(20, 20), 30), isTrue);
      expect(paintPixelFlag(canvas, '🇸🇪', const Offset(20, 20), 30, alpha: .5), isTrue);
    });

    testWidgets('flagsText turns each flag of a line to pixels and leaves the words', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: flagsText('через VPN · 🇸🇪 🇱🇻 🇫🇮', width: 15))));
      expect(find.byType(FlagMark), findsNWidgets(3));
      expect(find.textContaining('через VPN', findRichText: true), findsOneWidget);
      // the emoji themselves are not left in the text
      expect(find.textContaining('🇸🇪', findRichText: true), findsNothing);
    });

    testWidgets('a line without flags stays one text', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: flagsText('напрямую'))));
      expect(find.byType(FlagMark), findsNothing);
      expect(find.textContaining('напрямую', findRichText: true), findsOneWidget);
    });

    testWidgets('flagMark of a drawn flag paints at the width asked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: flagMark('🇫🇷', width: 42))),
        ),
      );
      final box = tester.getSize(find.byType(FlagMark));
      expect(box.width, 42);
      expect(box.height, 28);
    });

    testWidgets('no flag at all is the globe', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: flagMark(null))));
      expect(find.text('🌐'), findsOneWidget);
    });
  });

  group('pixel icons', () {
    Future<Uint8List> green() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 96, 96), Paint()..color = const Color(0xFF30A050));
      final image = await recorder.endRecording().toImage(96, 96);
      return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    }

    testWidgets('an icon is decoded once: not ready at once, the revision ticks, then it is there', (tester) async {
      final png = (await tester.runAsync(green))!;
      final before = PixelIcons.revision.value;
      await tester.runAsync(() async {
        expect(PixelIcons.of('green', png), isNull);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      expect(PixelIcons.revision.value, greaterThan(before));
      final icon = PixelIcons.of('green', png)!;
      expect(icon.image.width, greaterThan(0));
      expect(PixelIcons.of('green', png), same(icon));
    });

    testWidgets('an icon with wide empty margins is cut to what is drawn, as big as one that fills its tile', (
      tester,
    ) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawCircle(const Offset(48, 48), 20, Paint()..color = const Color(0xFF2090E0));
      final png = (await tester.runAsync(() async {
        final image = await recorder.endRecording().toImage(96, 96);
        return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      }))!;
      await tester.runAsync(() async {
        PixelIcons.of('small-round', png);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      final icon = PixelIcons.of('small-round', png)!;
      // the circle is 40 of 96 across: the part taken is about that, not the whole picture
      expect(icon.source.width, lessThan(100));
      expect(icon.source.width, greaterThan(70));
      final full = (await tester.runAsync(green))!;
      await tester.runAsync(() async {
        PixelIcons.of('full', full);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      expect(PixelIcons.of('full', full)!.source.width, closeTo(192, 8));
    });

    testWidgets('the grid is over the icon only: a corner outside it stays clear', (tester) async {
      final png = (await tester.runAsync(green))!;
      await tester.runAsync(() async {
        PixelIcons.of('grid', png);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      final icon = PixelIcons.of('grid', png)!;
      final result = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        PixelIcons.paint(canvas, const Rect.fromLTWH(0, 0, 36, 36), icon);
        final image = await recorder.endRecording().toImage(60, 60);
        final data = (await image.toByteData())!;
        // inside: green with a grid line darker somewhere; outside the icon (x = 50): nothing
        int a(int x, int y) => data.getUint8((y * 60 + x) * 4 + 3);
        return (inside: a(10, 10), outside: a(50, 50));
      });
      expect(result!.inside, 255);
      expect(result.outside, 0);
    });

    testWidgets('DotsAppIcon has room for the icon while it is made and keeps its size', (tester) async {
      final png = (await tester.runAsync(green))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DotsAppIcon(icon: png, size: 40)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DotsAppIcon)), const Size.square(40));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      // the picture is made a frame at a time: the frame after the icon is decoded makes it, the next draws it
      await tester.pump();
      await tester.pump();
      expect(find.descendant(of: find.byType(DotsAppIcon), matching: find.byType(CustomPaint)), findsWidgets);
      expect(tester.getSize(find.byType(DotsAppIcon)), const Size.square(40));
    });

    testWidgets('an icon that is not a picture is never made, and nothing breaks', (tester) async {
      final bad = Uint8List.fromList([1, 2, 3]);
      expect(PixelIcons.of('broken', bad), isNull);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      expect(PixelIcons.of('broken', bad), isNull);
      expect(PixelIcons.failed('broken'), isTrue);
    });
  });

  group('the views of the Dots blocks', () {
    test('every view has a name in both languages and the first one is the default', () {
      expect(PingGraph.values.length, 5);
      expect(SiteGraph.values.length, 5);
      for (final g in PingGraph.values) {
        expect(g.ru, isNotEmpty);
        expect(g.en, isNotEmpty);
        expect(PingGraph.fromName(g.name), g);
      }
      for (final g in SiteGraph.values) {
        expect(g.ru, isNotEmpty);
        expect(g.en, isNotEmpty);
        expect(SiteGraph.fromName(g.name), g);
      }
    });

    test('an unknown or missing name falls back to the default', () {
      expect(PingGraph.fromName('nope'), PingGraph.bars);
      expect(PingGraph.fromName(null), PingGraph.fallback);
      expect(SiteGraph.fromName('axis'), SiteGraph.columns);
      expect(SiteGraph.fromName(null), SiteGraph.fallback);
      expect(SiteGraph.fallback, SiteGraph.columns);
    });
  });
}
