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
