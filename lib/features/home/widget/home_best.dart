part of 'avpn_home_body.dart';

/// Set while the best server is being looked for (every server pinged, then the choice made).
final homeBestRunning = ValueNotifier(false);

/// Pings every server anew and puts the choice on Auto. The core's own pick then follows every rule of the app (the
/// countries and networks switched off, the whitelist servers, the priority subscription and its margin), so "the
/// best" is the best by those rules and not just the lowest number. Tells which server it came to.
Future<void> pingAndChooseBest(WidgetRef ref) async {
  if (homeBestRunning.value) return;
  homeBestRunning.value = true;
  final t = ref.read(translationsProvider).requireValue;
  final tell = ref.read(inAppNotificationControllerProvider);
  try {
    await pingAllServers(ref);
    var group = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    final autoTag = group?.selected == 'balance' ? 'balance' : 'lowest';
    final hasAuto = group?.items.any((i) => i.isGroup && i.tag == autoTag) ?? false;
    if (hasAuto && group?.selected != autoTag) {
      await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy('select', autoTag);
      // the core says which server the choice came to a moment later
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      group = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    }
    final auto = group?.items.where((i) => i.isGroup && i.tag == autoTag).firstOrNull;
    final pick = auto == null ? null : autoPick(auto, group!.items);
    if (pick == null || pick.urlTestDelay <= 0 || pick.urlTestDelay >= 65000) {
      tell.showInfoToast(t.avpn.bestNone);
    } else {
      tell.showSuccessToast(t.avpn.bestPicked(name: _withFlag(serverName(pick)), ms: pick.urlTestDelay));
    }
  } catch (_) {
    // not connected: nothing to ping
  } finally {
    homeBestRunning.value = false;
  }
}

/// The server row with [lead] at the left, the server itself in the middle and [trailing] at the right: the sides take the
/// same room, so the middle is the row's own middle.
Widget _centeredServer({required Widget lead, required Widget center, required Widget trailing, double reserve = 60}) {
  return Stack(
    alignment: Alignment.center,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: reserve),
        child: Center(child: center),
      ),
      Align(alignment: AlignmentDirectional.centerStart, child: lead),
      Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
    ],
  );
}

/// The button at the left of the current server: every server is pinged and the best one chosen. In each look its own
/// shape (Dots: an inked frame; Bento and the others: the accent or the dark disc).
class _BestButton extends HookConsumerWidget {
  const _BestButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    final running = useValueListenable(homeBestRunning);
    final look = homeLookNow;
    final dots = look == HomeLayout.dots;
    final bento = look == HomeLayout.bento;
    final ink = dots ? _Dots.ink(dark) : (bento ? _onAccent(accent) : (dark ? const Color(0xFF111111) : Colors.white));
    final fill = dots
        ? Colors.transparent
        : (bento ? accent : (dark ? const Color(0xFFF3F1EC) : const Color(0xFF111111)));
    const size = 40.0;
    return Semantics(
      button: true,
      label: t.avpn.bestServerHint,
      child: Tooltip(
        message: t.avpn.bestServerHint,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: running ? null : () => unawaited(pingAndChooseBest(ref)),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: dots ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: dots ? BorderRadius.circular(6) : null,
              border: dots ? Border.all(color: ink, width: 1.2) : null,
            ),
            child: running
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: ink))
                : Icon(Icons.bolt_rounded, size: 22, color: ink),
          ),
        ),
      ),
    );
  }
}
