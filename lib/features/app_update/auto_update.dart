import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_update/ara_update.dart';
import 'package:hiddify/features/app_update/update_controller.dart';
import 'package:hiddify/features/app_update/widget/update_card.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// How the program looks for an update by itself: once a day, and a newer build is offered in the update card (what is new,
/// Update / Later; the download and the one tap on "Install" follow when the user agrees). Each build is offered once.
///
/// The result is the short line to tell with the card (null: nothing to tell).
Future<String?> autoUpdateCheck(WidgetRef ref, {required bool ru, DateTime? now}) async {
  final folder = ref.read(Preferences.updateFolder).trim();
  if (folder.isEmpty || !Platform.isAndroid) return null;
  final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final last = ref.read(Preferences.lastUpdateCheck);
  if (at - last < const Duration(hours: 24).inMilliseconds) return null;
  // set at once: two checks never run together
  await ref.read(Preferences.lastUpdateCheck.notifier).update(at);
  final AraUpdateInfo? info;
  try {
    info = await AraUpdate.latest(folder);
  } catch (_) {
    // no network: tried again at the next start
    await ref.read(Preferences.lastUpdateCheck.notifier).update(last);
    return null;
  }
  final build = int.tryParse(ref.read(appInfoProvider).valueOrNull?.buildNumber ?? '') ?? 0;
  if (info == null || !info.isNewerThan(build)) return null;
  if (info.build <= ref.read(Preferences.lastOfferedBuild)) return null;
  await ref.read(Preferences.lastOfferedBuild.notifier).update(info.build);
  ref.read(araUpdateProvider.notifier).offer(info);
  return ru ? 'Доступна версия ${info.version}' : 'Version ${info.version} is available';
}

/// The daily check, running while the app is: the first a little after the start, then every hour the day's wait is looked at
/// again. [tell] shows what a check says.
Timer startAutoUpdate(WidgetRef ref, {required bool Function() ru, required void Function(String) tell}) {
  Future<void> run() async {
    final said = await autoUpdateCheck(ref, ru: ru());
    if (said != null) {
      tell(said);
      await openUpdateCard();
    }
  }

  Timer(const Duration(seconds: 40), run);
  return Timer.periodic(const Duration(hours: 1), (_) => unawaited(run()));
}

/// The "Check for updates" button: looks now (not waiting for the day) and opens the update card when there is a newer
/// build; [tell] says what a look finds when there is none.
Future<void> updateNow(WidgetRef ref, {required bool ru, required void Function(String) tell}) async {
  final controller = ref.read(araUpdateProvider.notifier);
  if (ref.read(araUpdateProvider).phase == UpdatePhase.downloading ||
      ref.read(araUpdateProvider).phase == UpdatePhase.ready) {
    await openUpdateCard();
    return;
  }
  tell(ru ? 'Проверяю обновления…' : 'Checking for updates…');
  final info = await controller.check();
  if (info != null) {
    await openUpdateCard();
    return;
  }
  final state = ref.read(araUpdateProvider);
  tell(switch (state.problem) {
    'folder' => ru ? 'Не задана папка с обновлениями (О программе)' : 'No update folder set (About)',
    'check' => ru ? 'Не удалось проверить обновления' : 'Could not check for updates',
    _ => ru ? 'Установлена последняя версия' : 'You have the latest version',
  });
}
