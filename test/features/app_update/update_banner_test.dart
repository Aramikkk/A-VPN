import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/app_update/ara_update.dart';
import 'package:hiddify/features/app_update/update_controller.dart';
import 'package:hiddify/features/app_update/widget/update_banner.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Controller extends AraUpdateController {
  _Controller(this._state);

  final UpdateState _state;

  @override
  UpdateState build() => _state;
}

const _info = AraUpdateInfo(version: '1.2.1', build: 60201, apk: 'a.apk', size: 51650789, notes: 'Один\nДва');

void main() {
  Future<void> show(WidgetTester tester, UpdateState state, {bool dark = true, double width = 360}) async {
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          translationsProvider.overrideWith((ref) async => t),
          araUpdateProvider.overrideWith(() => _Controller(state)),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          home: const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: UpdateBanner()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('nothing to show: no strip', (tester) async {
    await show(tester, const UpdateState());
    expect(find.text('Обновить'), findsNothing);
    expect(tester.getSize(find.byType(UpdateBanner)).height, 0);
  });

  testWidgets('an offer: the version, the size, what is new and the Update button', (tester) async {
    await show(tester, const UpdateState(phase: UpdatePhase.offer, info: _info));
    expect(find.textContaining('1.2.1'), findsWidgets);
    expect(find.textContaining('что нового'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a download shows its share, a ready build the Install button, a failed one Retry', (tester) async {
    await show(tester, const UpdateState(phase: UpdatePhase.downloading, info: _info, progress: .62, speed: 3e6));
    expect(find.textContaining('62%'), findsOneWidget);
    await show(tester, const UpdateState(phase: UpdatePhase.ready, info: _info, progress: 1));
    expect(find.text('Установить'), findsOneWidget);
    await show(tester, const UpdateState(phase: UpdatePhase.failed, info: _info, problem: 'download'));
    expect(find.text('Повторить'), findsOneWidget);
    // a failed look for an update says nothing on the home screen
    await show(tester, const UpdateState(phase: UpdatePhase.failed, problem: 'check'));
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('nothing overflows on a narrow phone, by day or by night', (tester) async {
    for (final dark in [true, false]) {
      for (final state in [
        const UpdateState(phase: UpdatePhase.offer, info: _info),
        const UpdateState(phase: UpdatePhase.downloading, info: _info, progress: .3, speed: 1e6),
        const UpdateState(phase: UpdatePhase.ready, info: _info, progress: 1, problem: 'permission'),
      ]) {
        await show(tester, state, dark: dark, width: 320);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
