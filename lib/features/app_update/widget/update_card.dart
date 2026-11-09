import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/app_update/ara_changelog.dart';
import 'package:hiddify/features/app_update/update_controller.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show dotsAccentNow;
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Shows the update: the strip on the home screen ([UpdateBanner]) carries it in the look of the theme in use, so the
/// places that used to open a card over what is on screen (the check in Settings, the About page) take the user there.
Future<void> openUpdateCard() async {
  final context = rootNavKey.currentContext;
  if (context == null || !context.mounted) return;
  await showUpdateCard(context);
}

Future<void> showUpdateCard(BuildContext context) async {
  GoRouter.of(context).goNamed('home');
}

/// The program's update in the dot style: the offer with what is new, the download, and the build ready to install.
class UpdateCard extends HookConsumerWidget {
  const UpdateCard({super.key});

  static TextStyle _mono(double size, Color colour, {FontWeight weight = FontWeight.w500, double spacing = 1}) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: 1.3,
        color: colour,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ru = ref.watch(translationsProvider).valueOrNull?.$meta.locale.languageCode == 'ru';
    final state = ref.watch(araUpdateProvider);
    final controller = ref.read(araUpdateProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF181818) : const Color(0xFFF2F2EE);
    final ink = dark ? const Color(0xFFECECE8) : const Color(0xFF151515);
    final soft = dark ? const Color(0xFF9A9A95) : const Color(0xFF6A6A66);
    final line = dark ? const Color(0xFF464644) : const Color(0xFFC8C8C2);
    final accent = dotsAccentNow;
    final expanded = useState(false);
    final info = state.info;
    final points = info == null ? const <String>[] : notePoints(info.notes);
    final shown = expanded.value ? points : points.take(3).toList();

    Widget label(String text) => Text(text, style: _mono(13, soft, weight: FontWeight.w700, spacing: 2));
    Widget big(String text) => Text(text, style: _mono(34, ink, weight: FontWeight.w800, spacing: 0));
    Widget small(String text, {Color? colour}) => Text(text, style: _mono(12.5, colour ?? soft, spacing: .4));
    Widget button(String text, VoidCallback onTap, {bool primary = false}) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? ink : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary ? ink : line, width: 1.5),
          ),
          child: Text(text, style: _mono(14, primary ? paper : ink, weight: FontWeight.w700, spacing: 1.5)),
        ),
      ),
    );
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1.5, thickness: 1.5, color: line),
    );

    final children = <Widget>[];
    switch (state.phase) {
      case UpdatePhase.offer when info != null:
        children
          ..addAll([
            Row(
              children: [
                Expanded(child: label(ru ? 'ОБНОВЛЕНИЕ' : 'UPDATE')),
                _Dot(accent, 9),
              ],
            ),
            const SizedBox(height: 8),
            big(info.version),
            const SizedBox(height: 4),
            small(
              [ru ? 'доступна новая версия' : 'a new version', if (info.size > 0) _megabytes(info.size)].join(' · '),
            ),
          ])
          ..add(divider());
        if (points.isNotEmpty) {
          children.add(label(ru ? 'ЧТО НОВОГО' : 'WHAT IS NEW'));
          children.add(const SizedBox(height: 10));
          for (final point in shown) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 6, right: 10), child: _Dot(accent, 6)),
                    Expanded(child: Text(point, style: _mono(13.5, ink, spacing: .2))),
                  ],
                ),
              ),
            );
          }
          if (points.length > 3) {
            children.add(
              GestureDetector(
                onTap: () => expanded.value = !expanded.value,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: small(
                    expanded.value
                        ? (ru ? 'свернуть  ‹' : 'less  ‹')
                        : (ru ? '+ ещё ${points.length - 3}  ›' : '+ ${points.length - 3} more  ›'),
                  ),
                ),
              ),
            );
          }
          children.add(const SizedBox(height: 14));
        }
        children.add(
          Row(
            children: [
              button(ru ? 'ПОЗЖЕ' : 'LATER', () {
                controller.dismiss();
                Navigator.of(context).pop();
              }),
              const SizedBox(width: 12),
              button(ru ? 'ПОСТАВИТЬ' : 'UPDATE', controller.download, primary: true),
            ],
          ),
        );
      case UpdatePhase.downloading when info != null:
        final percent = (state.progress * 100).round();
        final done = (info.size * state.progress).round();
        final left = state.speed > 0 ? ((info.size - done) / state.speed).ceil() : null;
        children.addAll([
          label(ru ? 'СКАЧИВАЮ ${info.version}' : 'DOWNLOADING ${info.version}'),
          const SizedBox(height: 8),
          big('$percent%'),
          const SizedBox(height: 16),
          _DotRow(filled: (state.progress * 13).round(), total: 13, colour: accent, off: line),
          const SizedBox(height: 16),
          Text(
            info.size > 0 ? '${_megabytes(done, bare: true)} / ${_megabytes(info.size)}' : '$percent%',
            style: _mono(16, ink, weight: FontWeight.w700, spacing: .4),
          ),
          const SizedBox(height: 4),
          small(
            [
              if (state.speed > 0) '${_megabytes(state.speed.round(), bare: true)} ${ru ? 'МБ/с' : 'MB/s'}',
              if (left != null) (ru ? 'осталось $left с' : '$left s left'),
            ].join(' · '),
          ),
          divider(),
          small(
            ru ? 'Можно свернуть приложение: загрузка продолжится.' : 'You can leave the app: the download goes on.',
          ),
        ]);
      case UpdatePhase.ready when info != null:
        children.addAll([
          label(ru ? 'ГОТОВО К УСТАНОВКЕ' : 'READY TO INSTALL'),
          const SizedBox(height: 8),
          big(info.version),
          const SizedBox(height: 16),
          _DotRow(filled: 13, total: 13, colour: ink, off: line),
          const SizedBox(height: 16),
          small(
            state.problem == 'permission'
                ? (ru
                      ? 'Разрешите установку из A-VPN в настройках и нажмите «Установить» ещё раз.'
                      : 'Allow installs from A-VPN in settings, then press Install again.')
                : state.problem == 'install'
                ? (ru
                      ? 'Не удалось запустить установку. Попробуйте ещё раз.'
                      : 'Could not start the install. Try again.')
                : (ru ? 'Откроется системное окно: нажмите «Установить».' : 'The system window opens: press Install.'),
            colour: state.problem == null ? soft : accent,
          ),
          const SizedBox(height: 16),
          Row(children: [button(ru ? 'УСТАНОВИТЬ' : 'INSTALL', controller.install, primary: true)]),
        ]);
      case UpdatePhase.failed:
        children.addAll([
          label(ru ? 'ОБНОВЛЕНИЕ' : 'UPDATE'),
          const SizedBox(height: 10),
          Text(switch (state.problem) {
            'download' => ru ? 'Не удалось скачать обновление' : 'Could not download the update',
            'folder' => ru ? 'Не задана папка с обновлениями' : 'No update folder set',
            _ => ru ? 'Не удалось проверить обновления' : 'Could not check for updates',
          }, style: _mono(15, ink, weight: FontWeight.w700, spacing: .2)),
          const SizedBox(height: 18),
          Row(
            children: [
              button(ru ? 'ЗАКРЫТЬ' : 'CLOSE', () => Navigator.of(context).pop()),
              if (info != null) ...[
                const SizedBox(width: 12),
                button(ru ? 'ПОВТОРИТЬ' : 'RETRY', controller.download, primary: true),
              ],
            ],
          ),
        ]);
      default:
        children.addAll([
          label(ru ? 'ПРОВЕРЯЮ…' : 'CHECKING…'),
          const SizedBox(height: 14),
          _DotRow(filled: 3, total: 13, colour: accent, off: line),
        ]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line, width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// "49 МБ" (or "49" when [bare]): bytes in the biggest unit that keeps a number above one.
String _megabytes(int bytes, {bool bare = false}) {
  final mb = bytes / (1024 * 1024);
  final text = mb >= 10 ? mb.toStringAsFixed(0) : mb.toStringAsFixed(1);
  return bare ? text : '$text МБ';
}

class _Dot extends StatelessWidget {
  const _Dot(this.colour, this.size);

  final Color colour;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 2,
    height: size * 2,
    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
  );
}

/// A row of dots, the first [filled] lit: the download's bar.
class _DotRow extends StatelessWidget {
  const _DotRow({required this.filled, required this.total, required this.colour, required this.off});

  final int filled;
  final int total;
  final Color colour;
  final Color off;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [for (var i = 0; i < total; i++) _Dot(i < filled ? colour : off, 8)],
  );
}
