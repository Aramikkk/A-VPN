// Renders the desktop sidebar's traffic panel at its real width with Windows' own font, to look at it and to
// catch overflowing text. To look at it: RENDER=1 flutter test --update-goldens <this file>.
@Tags(['render'])
library;

import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Stats extends StatsNotifier {
  @override
  Stream<SystemInfo> build() => Stream.value(
    SystemInfo(
        uplink: Int64(613),
        downlink: Int64(469 * 1024),
        uplinkTotal: Int64(241 * 1024),
        downlinkTotal: Int64(328 * 1024 * 1024),
        connectionsIn: 48,
      )
      ..unknownFields.mergeVarintField(100, Int64(200 * 1024))
      ..unknownFields.mergeVarintField(101, Int64(300 * 1024 * 1024)),
  );
}

class _Quality extends ConnectionQuality {
  @override
  List<int?> build() => [for (var i = 0; i < 30; i++) i % 9 == 4 ? null : 50 + (i * 7) % 30];
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final f = File(file);
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  testWidgets('traffic panel fits: desktop sidebar 248 px, unfolded phone 330 px', (tester) async {
    await _loadFont('Segoe UI Variable Text', [r'C:\Windows\Fonts\SegUIVar.ttf']);
    await _loadFont('Segoe UI', [
      r'C:\Windows\Fonts\segoeui.ttf',
      r'C:\Windows\Fonts\seguisb.ttf',
      r'C:\Windows\Fonts\segoeuib.ttf',
    ]);
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    for (final (dark, width, large) in [(false, 248.0, false), (true, 248.0, false), (true, 330.0, true)]) {
      final theme = AppTheme(AppThemeMode.system, '', accent: AraAccent.lagoon);
      await tester.binding.setSurfaceSize(Size(width, large ? 1100 : 760));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationsProvider.overrideWith((ref) async => t),
            statsNotifierProvider.overrideWith(_Stats.new),
            connectionQualityProvider.overrideWith(_Quality.new),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? theme.darkTheme(null) : theme.lightTheme(null),
            home: Scaffold(
              body: Consumer(
                // the translations load a frame later
                builder: (context, ref, _) => !ref.watch(translationsProvider).hasValue
                    ? const SizedBox()
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: SingleChildScrollView(
                          child: SizedBox(width: width, child: SideBarStatsOverview(large: large)),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // overflowing text fails the test by itself; the picture is written only on request (RENDER=1)
      if (Platform.environment['RENDER'] == '1') {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/sidebar_${large ? 'large' : dark ? 'dark' : 'light'}.png'),
        );
      }
    }
  });
}
