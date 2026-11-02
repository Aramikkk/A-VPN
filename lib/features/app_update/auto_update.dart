import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_update/ara_update.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// How the program looks for an update by itself: once a day, and a newer build is downloaded and the installer opened
/// (Android lets nothing install itself without a tap: the one tap is on "Install"). Each build is offered once.
///
/// The result is what the user is told (null: nothing to tell).
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
  final waiting = ru
      ? 'Доступна версия ${info.version}: О программе → Обновить'
      : 'Version ${info.version} is available: About → Update';
  try {
    final apk = await AraUpdate.download(folder, info);
    final result = await AraUpdate.install(apk, allowSettings: false);
    return result == 'ok' ? null : waiting;
  } catch (_) {
    return waiting;
  }
}

/// The daily check, running while the app is: the first a little after the start, then every hour the day's wait is looked at
/// again. [tell] shows what a check says.
Timer startAutoUpdate(WidgetRef ref, {required bool Function() ru, required void Function(String) tell}) {
  Future<void> run() async {
    final said = await autoUpdateCheck(ref, ru: ru());
    if (said != null) tell(said);
  }

  Timer(const Duration(seconds: 40), run);
  return Timer.periodic(const Duration(hours: 1), (_) => unawaited(run()));
}

/// The "Check for updates" button: looks now (not waiting for the day), and a newer build is downloaded and the installer
/// opened; [tell] says each step. The page for allowing installs is opened when it is the first time.
Future<void> updateNow(WidgetRef ref, {required bool ru, required void Function(String) tell}) async {
  final folder = ref.read(Preferences.updateFolder).trim();
  if (folder.isEmpty) {
    tell(ru ? 'Не задана папка с обновлениями (О программе)' : 'No update folder set (About)');
    return;
  }
  tell(ru ? 'Проверяю обновления…' : 'Checking for updates…');
  final AraUpdateInfo? info;
  try {
    info = await AraUpdate.latest(folder);
  } catch (_) {
    tell(ru ? 'Не удалось проверить обновления' : 'Could not check for updates');
    return;
  }
  final build = int.tryParse(ref.read(appInfoProvider).valueOrNull?.buildNumber ?? '') ?? 0;
  if (info == null || !info.isNewerThan(build)) {
    tell(ru ? 'Установлена последняя версия' : 'You have the latest version');
    return;
  }
  tell(ru ? 'Скачиваю версию ${info.version}…' : 'Downloading version ${info.version}…');
  try {
    final apk = await AraUpdate.download(folder, info);
    final result = await AraUpdate.install(apk);
    if (result == 'permission') {
      tell(
        ru
            ? 'Разрешите установку из A-VPN и нажмите «Проверить обновления» ещё раз'
            : 'Allow installs from A-VPN, then press "Check for updates" again',
      );
    } else if (result != 'ok') {
      tell(ru ? 'Не удалось запустить установку' : 'Could not start the install');
    }
  } catch (_) {
    tell(ru ? 'Не удалось скачать обновление' : 'Could not download the update');
  }
}
