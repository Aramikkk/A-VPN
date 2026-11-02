import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_update/ara_changelog.dart';
import 'package:hiddify/features/app_update/update_controller.dart';
import 'package:hiddify/features/app_update/widget/update_card.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show dotsAccentNow;
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// "Update" in About: looks the newest build up (the card with what is new opens when there is one), then the changelog
/// of the versions, the installed one first, and the link of the folder the builds are taken from.
class AraUpdateTile extends HookConsumerWidget {
  const AraUpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = ref.watch(translationsProvider).valueOrNull?.$meta.locale.languageCode == 'ru';
    final folder = ref.watch(Preferences.updateFolder).trim();
    final state = ref.watch(araUpdateProvider);
    final changelog = ref.watch(araChangelogProvider).valueOrNull ?? const <AraRelease>[];
    final version = ref.watch(appInfoProvider).valueOrNull?.version ?? '';
    final controller = useTextEditingController(text: folder);
    final all = useState(false);
    final theme = Theme.of(context);
    final soft = theme.colorScheme.onSurfaceVariant;

    Future<void> check() async {
      final info = await ref.read(araUpdateProvider.notifier).check();
      if (info != null && context.mounted) await showUpdateCard(context);
    }

    final busy = state.phase == UpdatePhase.checking;
    final working = state.phase == UpdatePhase.downloading || state.phase == UpdatePhase.ready;
    final status = switch (state.phase) {
      UpdatePhase.checking => ru ? 'Проверяю…' : 'Checking…',
      UpdatePhase.offer =>
        ru ? 'Доступна версия ${state.info?.version}' : 'Version ${state.info?.version} is available',
      UpdatePhase.downloading =>
        ru
            ? 'Скачиваю ${state.info?.version}: ${(state.progress * 100).round()}%'
            : 'Downloading ${state.info?.version}',
      UpdatePhase.ready =>
        ru ? 'Версия ${state.info?.version} готова к установке' : 'Version ${state.info?.version} is ready',
      UpdatePhase.failed =>
        state.problem == 'download'
            ? (ru ? 'Не удалось скачать обновление' : 'Could not download the update')
            : (ru ? 'Не удалось проверить обновления' : 'Could not check for updates'),
      UpdatePhase.idle => state.upToDate ? (ru ? 'Установлена последняя версия' : 'You have the latest version') : null,
    };
    final shown = all.value ? changelog : changelog.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(ru ? 'Обновление программы' : 'App update'),
          subtitle: status == null ? null : Text(status),
          trailing: busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
              : TextButton(
                  onPressed: folder.isEmpty
                      ? null
                      : working || state.phase == UpdatePhase.offer
                      ? () => unawaited(showUpdateCard(context))
                      : check,
                  child: Text(
                    working || state.phase == UpdatePhase.offer
                        ? (ru ? 'Открыть' : 'Open')
                        : (ru ? 'Проверить' : 'Check'),
                  ),
                ),
        ),
        if (shown.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              ru ? 'ЧТО НОВОГО' : 'WHAT IS NEW',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: soft,
              ),
            ),
          ),
          for (final release in shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: release.version == version ? dotsAccentNow : soft.withValues(alpha: .5),
                        ),
                      ),
                      const Gap(10),
                      Text(
                        '${release.version}  ${release.shortDate}',
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                  for (final point in release.points.take(all.value ? release.points.length : 2))
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 4),
                      child: Text('· $point', style: theme.textTheme.bodySmall?.copyWith(color: soft)),
                    ),
                ],
              ),
            ),
          if (changelog.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: GestureDetector(
                onTap: () => all.value = !all.value,
                child: Text(
                  all.value
                      ? (ru ? 'Свернуть  ‹' : 'Less  ‹')
                      : (ru ? 'Показать все версии  ›' : 'Show all versions  ›'),
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: soft),
                ),
              ),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              isDense: true,
              labelText: ru ? 'Ссылка на папку с обновлениями (Яндекс Диск)' : 'Update folder link (Yandex Disk)',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              unawaited(ref.read(Preferences.updateFolder.notifier).update(value.trim()));
              ref.read(araUpdateProvider.notifier).dismiss();
            },
          ),
        ),
        const Gap(4),
      ],
    );
  }
}
