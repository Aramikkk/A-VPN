import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every test sees the app's own fonts (and the Material icons), so rendered pictures show real text.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final file in files) {
      final f = File(file);
      if (!f.existsSync()) continue;
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      any = true;
    }
    if (any) await loader.load();
  }

  const fonts = 'assets/fonts';
  await load('Manrope', [for (final w in [400, 500, 600, 700, 800]) '$fonts/Manrope-$w.ttf']);
  await load('Golos Text', [for (final w in [400, 500, 600, 700, 800]) '$fonts/GolosText-$w.ttf']);
  await load('Unbounded', ['$fonts/Unbounded-600.ttf', '$fonts/Unbounded-800.ttf']);
  await load('JetBrains Mono', [for (final w in [500, 700, 800]) '$fonts/JetBrainsMono-$w.ttf']);
  await load('Emoji', ['$fonts/Emoji.ttf']);
  await load('MaterialIcons', ['./tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  await testMain();
}
