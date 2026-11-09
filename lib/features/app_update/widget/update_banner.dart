import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/strip_look.dart';
import 'package:hiddify/features/app_update/ara_changelog.dart';
import 'package:hiddify/features/app_update/update_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The program's update on the home screen: a thin strip under the title, in the look of the theme in use (Dots, Bento,
/// Contrast or Glass). It offers the new version, shows the download and, when the file is ready, the install button. A
/// tap on "what is new" opens the list of changes; the cross turns the offer down until the next version.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(araUpdateProvider);
    final info = state.info;
    final shown =
        info != null &&
        (state.phase == UpdatePhase.offer ||
            state.phase == UpdatePhase.downloading ||
            state.phase == UpdatePhase.ready ||
            (state.phase == UpdatePhase.failed && state.problem == 'download'));
    if (!shown) return const SizedBox.shrink();
    final ru = ref.watch(translationsProvider).valueOrNull?.$meta.locale.languageCode == 'ru';
    final controller = ref.read(araUpdateProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // the colours and the shape of the theme in use, the same for every strip of the app
    final look = StripLook.of(context);
    final dots = look.dots;
    final bento = look.bento;
    final glass = look.glass;
    final accent = look.accent;
    final edge = look.edge;
    final ink = look.ink;
    final soft = look.soft;
    final btnFill = look.btnFill;
    final btnInk = look.btnInk;
    final text = look.text;
    String caps(String s) => dots ? s.toUpperCase() : s;

    Widget button(String label, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: btnFill,
          borderRadius: BorderRadius.circular(dots ? 6 : 16),
          border: dots ? Border.all(color: btnFill) : null,
        ),
        child: Text(caps(label), style: text(12.5, btnInk, weight: FontWeight.w700)),
      ),
    );

    Widget cross() => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.dismiss,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Icon(Icons.close_rounded, size: 18, color: soft),
      ),
    );

    final Widget body;
    switch (state.phase) {
      case UpdatePhase.downloading:
        final percent = (state.progress * 100).round();
        const total = 13;
        final filled = (state.progress * total).round();
        body = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caps(ru ? 'Скачиваю ${info.version} · $percent%' : 'Downloading ${info.version} · $percent%'),
                    style: text(13, ink, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  if (dots)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < total; i++)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: i < filled ? accent : edge),
                          ),
                      ],
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 5,
                        color: bento || glass ? scheme.primary : ink,
                        backgroundColor: ink.withValues(alpha: .14),
                      ),
                    ),
                ],
              ),
            ),
            if (state.speed > 0) ...[
              const SizedBox(width: 12),
              Text('${_mb(state.speed.round())} ${ru ? 'МБ/с' : 'MB/s'}', style: text(11.5, soft)),
            ],
          ],
        );
      case UpdatePhase.ready:
        body = Row(
          children: [
            if (dots) ...[_Dot(accent), const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caps(ru ? '${info.version} готова' : '${info.version} is ready'),
                    style: text(13, ink, weight: FontWeight.w700),
                  ),
                  Text(
                    state.problem == 'permission'
                        ? (ru ? 'разрешите установку и нажмите ещё раз' : 'allow installs, then press again')
                        : state.problem == 'install'
                        ? (ru ? 'не удалось начать, попробуйте ещё раз' : 'could not start, try again')
                        : (ru ? 'откроется окно установки' : 'the install window opens'),
                    style: text(11, soft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            button(ru ? 'Установить' : 'Install', () => unawaited(controller.install())),
          ],
        );
      case UpdatePhase.failed:
        body = Row(
          children: [
            Expanded(
              child: Text(
                caps(ru ? 'Не удалось скачать ${info.version}' : 'Could not download ${info.version}'),
                style: text(13, ink, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            button(ru ? 'Повторить' : 'Retry', () => unawaited(controller.download())),
            cross(),
          ],
        );
      default:
        final points = notePoints(info.notes);
        body = Row(
          children: [
            if (dots) ...[_Dot(accent), const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caps(ru ? 'Доступна ${info.version}' : '${info.version} is available'),
                    style: text(13, ink, weight: FontWeight.w700),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: points.isEmpty ? null : () => unawaited(_showNotes(context, info.version, points, ru)),
                    child: Text(
                      [
                        if (info.size > 0) '${_mb(info.size)} ${ru ? 'МБ' : 'MB'}',
                        if (points.isNotEmpty) (ru ? 'что нового ›' : 'what is new ›'),
                      ].join(' · '),
                      style: text(11, soft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            button(ru ? 'Обновить' : 'Update', () => unawaited(controller.download())),
            cross(),
          ],
        );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Container(padding: const EdgeInsets.fromLTRB(14, 9, 8, 9), decoration: look.decoration, child: body),
    );
  }
}

/// The list of changes of the offered version, in a sheet over the home screen.
Future<void> _showNotes(BuildContext context, String version, List<String> points, bool ru) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                ru ? 'Что нового в $version' : 'What is new in $version',
                style: Theme.of(sheet).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 7, right: 10), child: _Dot(null, size: 5)),
                      Expanded(child: Text(point, style: Theme.of(sheet).textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

/// "49": bytes as megabytes, one decimal below ten.
String _mb(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb >= 10 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
}

class _Dot extends StatelessWidget {
  const _Dot(this.colour, {this.size = 4.5});

  final Color? colour;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 2,
    height: size * 2,
    decoration: BoxDecoration(color: colour ?? Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
  );
}
