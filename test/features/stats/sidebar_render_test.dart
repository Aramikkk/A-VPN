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
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hiddify/features/stats/widget/speed_page.dart';
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

class _History extends SpeedHistory {
  @override
  List<({int down, int up})> build() => [
    for (var i = 0; i < 60; i++)
      (
        down: (1.2e6 + 9e5 * ((i * 37) % 11) / 10 + (i > 40 && i < 46 ? 4e6 : 0)).round(),
        up: (1.5e5 + 9e4 * (i % 5)).round(),
      ),
  ];
}

class _Quality extends ConnectionQuality {
  @override
  List<int?> build() => [for (var i = 0; i < 30; i++) i % 9 == 4 ? null : 50 + (i * 7) % 30];

  // three stretches of loss through the day
  @override
  LossDay lossDay({DateTime? since}) {
    final now = DateTime(2026, 10, 15, 21, 40);
    final minutes = List<double?>.filled(24 * 60, 0);
    for (final (ago, length, share) in [(30, 4, .2), (320, 1, .05), (790, 12, .6)]) {
      for (var i = 0; i < length; i++) {
        minutes[24 * 60 - ago + i] = share;
      }
    }
    return (
      total: PingBucket(86400, 520),
      minutes: minutes,
      episodes: [
        (start: now.subtract(const Duration(minutes: 30)), minutes: 4, sent: 240, lost: 48),
        (start: now.subtract(const Duration(minutes: 320)), minutes: 1, sent: 60, lost: 3),
        (start: now.subtract(const Duration(minutes: 790)), minutes: 12, sent: 720, lost: 432),
      ],
    );
  }
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
  testWidgets('traffic panel fits: desktop sidebar 248 px, phone tab 330 px, unfolded home 320 x 640', (tester) async {
    await _loadFont('Segoe UI Variable Text', [r'C:\Windows\Fonts\SegUIVar.ttf']);
    await _loadFont('Segoe UI', [
      r'C:\Windows\Fonts\segoeui.ttf',
      r'C:\Windows\Fonts\seguisb.ttf',
      r'C:\Windows\Fonts\segoeuib.ttf',
    ]);
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    for (final (dark, width, large, dense) in [
      (false, 248.0, false, false),
      (true, 248.0, false, false),
      (true, 330.0, true, false),
      (false, 320.0, true, true),
    ]) {
      final theme = AppTheme(
        AppThemeMode.system,
        '',
        accent: AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'neonBlue'),
        style: AraStyle.values.byName(Platform.environment['STYLE'] ?? 'classic'),
      );
      await tester.binding.setSurfaceSize(Size(width, dense ? 640 : (large ? 1100 : 760)));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationsProvider.overrideWith((ref) async => t),
            statsNotifierProvider.overrideWith(_Stats.new),
            connectionQualityProvider.overrideWith(_Quality.new),
            speedHistoryProvider.overrideWith(_History.new),
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
                          child: SizedBox(
                            width: width,
                            child: SideBarStatsOverview(large: large, dense: dense),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // stretched to the servers' column on an unfolded phone: fills the given height without overflowing
      if (dense) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationsProvider.overrideWith((ref) async => t),
              statsNotifierProvider.overrideWith(_Stats.new),
              connectionQualityProvider.overrideWith(_Quality.new),
              speedHistoryProvider.overrideWith(_History.new),
            ],
            child: MaterialApp(
              theme: theme.lightTheme(null),
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => !ref.watch(translationsProvider).hasValue
                      ? const SizedBox()
                      : const SizedBox(height: 660, child: SideBarStatsOverview(large: true, dense: true, fill: true)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(SideBarStatsOverview)).height, 660);
        if (Platform.environment['RENDER'] == '1') {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/sidebar_fill.png'));
        }
        continue;
      }
      // beside the servers on an unfolded phone the whole panel has to fit the screen's height
      if (dense) {
        final height = tester.getSize(find.byType(SideBarStatsOverview)).height;
        expect(height, lessThanOrEqualTo(640), reason: 'the dense panel is $height tall');
      }
      // overflowing text fails the test by itself; the picture is written only on request (RENDER=1)
      if (Platform.environment['RENDER'] == '1') {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/sidebar_${dense
                ? 'dense'
                : large
                ? 'large'
                : dark
                ? 'dark'
                : 'light'}.png',
          ),
        );
      }
    }
  });

  // the screen less the status bar and the bottom navigation: the unfolded Fold 7 in two columns, the folded one
  // in one; neither scrolls
  for (final (name, size) in [('unfolded', Size(750, 720)), ('folded', Size(411, 850))])
    testWidgets('the Statistics tab fits the $name phone with no scroll', (tester) async {
      await _loadFont('Segoe UI', [
        r'C:/Windows/Fonts/segoeui.ttf',
        r'C:/Windows/Fonts/seguisb.ttf',
        r'C:/Windows/Fonts/segoeuib.ttf',
      ]);
      final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
      final theme = AppTheme(
        AppThemeMode.light,
        '',
        accent: AraAccent.values.byName(Platform.environment['ACCENT'] ?? 'neonRed'),
        style: AraStyle.values.byName(Platform.environment['STYLE'] ?? 'classic'),
      );
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationsProvider.overrideWith((ref) async => t),
            statsNotifierProvider.overrideWith(_Stats.new),
            connectionQualityProvider.overrideWith(_Quality.new),
            speedHistoryProvider.overrideWith(_History.new),
          ],
          child: MaterialApp(
            theme: theme.lightTheme(null),
            home: Consumer(
              builder: (context, ref, _) =>
                  !ref.watch(translationsProvider).hasValue ? const SizedBox() : const SpeedPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // (Contrast pages down to the graph)
      if (Platform.environment['STYLE'] != 'contrast') expect(find.byType(Scrollable), findsNothing);
      if (Platform.environment['RENDER'] == '1') {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/speed_$name.png'));
      }
    });
}
