import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/app_update/ara_changelog.dart';
import 'package:hiddify/features/app_update/ara_update.dart';
import 'package:hiddify/features/app_update/update_controller.dart';
import 'package:hiddify/features/app_update/widget/update_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _changelog = '''# A-VPN — версии

Заголовок, не версия.

## 1.1.19 — 02.11.2026
- Потери: IPv6 выключен
- Иконки: запасные пути

## 1.1.18 — 02.11.2026
- Подключение на ядре 5.4.0

## 1.0.0
- Первая версия
''';

class _Controller extends AraUpdateController {
  _Controller(this._state);

  final UpdateState _state;

  @override
  UpdateState build() => _state;
}

void main() {
  test('the changelog is read version by version, newest first as written', () {
    final releases = parseChangelog(_changelog);
    expect(releases.map((r) => r.version), ['1.1.19', '1.1.18', '1.0.0']);
    expect(releases.first.date, '02.11.2026');
    expect(releases.first.shortDate, '02.11');
    expect(releases.first.points, ['Потери: IPv6 выключен', 'Иконки: запасные пути']);
    // a version with no date is still a version
    expect(releases.last.date, '');
    expect(releases.last.points, ['Первая версия']);
  });

  test('an empty or foreign text is no releases, and the notes of latest.json are lines', () {
    expect(parseChangelog(''), isEmpty);
    expect(parseChangelog('только текст\n- и пункт без версии'), isEmpty);
    expect(notePoints('Один\n\n  - Два  \nТри'), ['Один', 'Два', 'Три']);
  });

  Future<void> show(WidgetTester tester, UpdateState state, {bool dark = true}) async {
    final t = await tester.runAsync(() => AppLocale.ru.build()) as Translations;
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          translationsProvider.overrideWith((ref) async => t),
          araUpdateProvider.overrideWith(() => _Controller(state)),
        ],
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: const Scaffold(
            body: Center(child: SingleChildScrollView(child: UpdateCard())),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  const info = AraUpdateInfo(
    version: '1.1.20',
    build: 60120,
    apk: 'A-VPN-1.1.20-arm64.apk',
    size: 51 * 1024 * 1024,
    notes: 'Один\nДва\nТри\nЧетыре\nПять',
  );

  testWidgets('the offer shows the version, three changes and a way to see the rest', (tester) async {
    await show(tester, const UpdateState(phase: UpdatePhase.offer, info: info));
    expect(find.text('1.1.20'), findsOneWidget);
    expect(find.text('ПОСТАВИТЬ'), findsOneWidget);
    expect(find.text('ПОЗЖЕ'), findsOneWidget);
    expect(find.text('Три'), findsOneWidget);
    expect(find.text('Четыре'), findsNothing);
    await tester.tap(find.textContaining('ещё 2'));
    await tester.pump();
    expect(find.text('Четыре'), findsOneWidget);
    expect(find.text('Пять'), findsOneWidget);
  });

  testWidgets('the download shows the share, the size and that it goes on in the background', (tester) async {
    await show(
      tester,
      const UpdateState(phase: UpdatePhase.downloading, info: info, progress: .62, speed: 3.2 * 1024 * 1024),
    );
    expect(find.text('62%'), findsOneWidget);
    expect(find.textContaining('МБ'), findsWidgets);
    expect(find.textContaining('загрузка продолжится'), findsOneWidget);
  });

  testWidgets('a downloaded build says what to tap, and a refused install says why', (tester) async {
    await show(tester, const UpdateState(phase: UpdatePhase.ready, info: info, progress: 1), dark: false);
    expect(find.text('УСТАНОВИТЬ'), findsOneWidget);
    expect(find.textContaining('нажмите «Установить»'), findsOneWidget);
    await show(tester, const UpdateState(phase: UpdatePhase.ready, info: info, progress: 1, problem: 'permission'));
    expect(find.textContaining('Разрешите установку'), findsOneWidget);
  });

  testWidgets('a failed download offers to try again, a failed look only to close', (tester) async {
    await show(tester, const UpdateState(phase: UpdatePhase.failed, info: info, problem: 'download'));
    expect(find.text('ПОВТОРИТЬ'), findsOneWidget);
    await show(tester, const UpdateState(phase: UpdatePhase.failed, problem: 'check'));
    expect(find.text('ПОВТОРИТЬ'), findsNothing);
    expect(find.text('ЗАКРЫТЬ'), findsOneWidget);
  });

  testWidgets('on a phone 360 wide nothing overflows, in either theme and for long lines', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    const long = AraUpdateInfo(
      version: '1.1.20',
      build: 60120,
      apk: 'a.apk',
      size: 51 * 1024 * 1024,
      notes:
          'Подключение держится после сворачивания приложения на несколько минут и возврата в него\nИконки приложений\nЕщё одна длинная строка про потери и IPv6, которая переносится\nЧетыре',
    );
    for (final dark in [true, false]) {
      for (final state in [
        const UpdateState(phase: UpdatePhase.offer, info: long),
        const UpdateState(phase: UpdatePhase.downloading, info: long, progress: .31, speed: 1.2 * 1024 * 1024),
        const UpdateState(phase: UpdatePhase.ready, info: long, progress: 1, problem: 'permission'),
        const UpdateState(phase: UpdatePhase.failed, info: long, problem: 'download'),
        const UpdateState(phase: UpdatePhase.checking),
      ]) {
        await show(tester, state, dark: dark);
        expect(tester.takeException(), isNull, reason: '${state.phase} dark=$dark');
      }
    }
  });
}
