import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/chain/model/chain_enum.dart';
import 'package:hiddify/features/chain/overview/chain_timeline.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('every step of the chain draws in the dot style on a phone, in both themes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    for (final dark in [true, false]) {
      // the translations and the preferences are loaded before the first frame, as they are in the program
      final container = ProviderContainer(
        overrides: [
          translationsProvider.overrideWith((ref) async => t),
          sharedPreferencesProvider.overrideWith((ref) async => prefs),
        ],
      );
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await container.read(translationsProvider.future);
        await container.read(sharedPreferencesProvider.future);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: ListView(
                children: [
                  for (final level in ChainTimelineLevel.values) ChainTimeline(level: level),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'dark=$dark');
      // the steps are named in capitals, as the program's other headings
      expect(find.text(t.pages.settings.chain.title.toUpperCase()), findsNothing);
      expect(find.byType(ChainTimeline), findsNWidgets(ChainTimelineLevel.values.length));
    }
  });
}
