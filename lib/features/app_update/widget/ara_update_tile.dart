import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_update/ara_update.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// "Update" in About: looks the newest build up in the update folder, shows what is new and downloads and installs it.
class AraUpdateTile extends HookConsumerWidget {
  const AraUpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = ref.watch(translationsProvider).requireValue.$meta.locale.languageCode == 'ru';
    final folder = ref.watch(Preferences.updateFolder).trim();
    final build = int.tryParse(ref.watch(appInfoProvider).requireValue.buildNumber) ?? 0;
    final status = useState<String?>(null);
    final busy = useState(false);
    final progress = useState<double?>(null);
    final found = useState<AraUpdateInfo?>(null);
    final controller = useTextEditingController(text: folder);

    Future<void> check() async {
      busy.value = true;
      status.value = null;
      try {
        final info = await AraUpdate.latest(folder);
        if (info == null) {
          status.value = ru ? 'Не задана папка с обновлениями' : 'No update folder set';
        } else if (info.isNewerThan(build)) {
          found.value = info;
          status.value = ru ? 'Доступна версия ${info.version}' : 'Version ${info.version} is available';
        } else {
          found.value = null;
          status.value = ru ? 'Установлена последняя версия' : 'You have the latest version';
        }
      } catch (_) {
        status.value = ru ? 'Не удалось проверить обновления' : 'Could not check for updates';
      } finally {
        busy.value = false;
      }
    }

    Future<void> update() async {
      final info = found.value;
      if (info == null) return;
      busy.value = true;
      progress.value = 0;
      try {
        final apk = await AraUpdate.download(folder, info, onProgress: (p) => progress.value = p);
        final result = await AraUpdate.install(apk);
        status.value = switch (result) {
          'ok' => ru ? 'Установщик открыт' : 'The installer is open',
          'permission' =>
            ru
                ? 'Разрешите установку из A-VPN в настройках и нажмите «Обновить» ещё раз'
                : 'Allow installs from A-VPN in settings, then press Update again',
          _ => ru ? 'Не удалось запустить установку' : 'Could not start the install',
        };
      } catch (_) {
        status.value = ru ? 'Не удалось скачать обновление' : 'Could not download the update';
      } finally {
        busy.value = false;
        progress.value = null;
      }
    }

    final info = found.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(ru ? 'Обновление программы' : 'App update'),
          subtitle: status.value == null ? null : Text(status.value!),
          trailing: busy.value
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4, value: progress.value),
                )
              : TextButton(
                  onPressed: folder.isEmpty ? null : (info == null ? check : update),
                  child: Text(info == null ? (ru ? 'Проверить' : 'Check') : (ru ? 'Обновить' : 'Update')),
                ),
        ),
        if (info != null && info.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(info.notes, style: Theme.of(context).textTheme.bodySmall),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              isDense: true,
              labelText: ru ? 'Ссылка на папку с обновлениями (Яндекс Диск)' : 'Update folder link (Yandex Disk)',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              unawaited(ref.read(Preferences.updateFolder.notifier).update(value.trim()));
              found.value = null;
              status.value = null;
            },
          ),
        ),
        const Gap(4),
      ],
    );
  }
}
