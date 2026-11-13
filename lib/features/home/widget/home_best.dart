part of 'avpn_home_body.dart';

/// Set while the best server is being looked for (every server pinged, then the choice made).
final homeBestRunning = ValueNotifier(false);

/// The answering server with the lowest ping among those shown (the countries and networks switched off and the
/// whitelist servers are already left out of [OutboundInfo.isVisible]); null when none answers. The groups (Auto, Smart)
/// are not servers. The priority subscription's margin and Auto's tolerance don't apply: this is a choice made by hand.
///
/// With the servers chosen by network ([network] known) the whitelist servers ("LTE Only", "БС") are the only ones taken on
/// mobile data and the only ones left out on Wi-Fi, as in the config itself.
OutboundInfo? fastestServer(Iterable<OutboundInfo> items, {NetworkKind network = NetworkKind.unknown}) {
  OutboundInfo? best;
  for (final item in items) {
    if (item.isGroup || !item.isVisible || item.tag.contains('§hide§')) continue;
    final mobileOnly = ServerRegionFilter.isMobileOnly(item.tag);
    if (network == NetworkKind.mobile && !mobileOnly) continue;
    if (network == NetworkKind.wifi && mobileOnly) continue;
    final delay = item.urlTestDelay;
    if (delay <= 0 || delay >= 65000) continue;
    if (best == null || delay < best.urlTestDelay) best = item;
  }
  return best;
}

/// Set by each choice of the bolt; a watch of an older choice sees it changed and stops.
int _boltWatch = 0;

/// Pings every server anew and chooses by hand the one with the lowest ping, which the home screen then shows. After it
/// the choice is watched: when that server stops answering or gets slow (as slow as the home screen paints a ping red)
/// three checks running, the choice goes back to Auto, and Auto's rules take over.
Future<void> pingAndChooseBest(WidgetRef ref) async {
  if (homeBestRunning.value) return;
  homeBestRunning.value = true;
  final t = ref.read(translationsProvider).requireValue;
  final tell = ref.read(inAppNotificationControllerProvider);
  try {
    await pingAllServers(ref);
    final group = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    final pick = group == null ? null : fastestServer(group.items, network: _actualNetworkKind.value);
    if (group == null || pick == null) {
      tell.showInfoToast(t.avpn.bestNone);
      return;
    }
    if (group.selected != pick.tag) {
      await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy('select', pick.tag);
    }
    tell.showSuccessToast(t.avpn.bestPicked(name: _withFlag(serverName(pick)), ms: pick.urlTestDelay));
    final autoTag = group.selected == 'balance' ? 'balance' : 'lowest';
    if (group.items.any((i) => i.isGroup && i.tag == autoTag)) unawaited(_watchBolt(ref, pick.tag, autoTag));
  } catch (_) {
    // not connected: nothing to ping
  } finally {
    homeBestRunning.value = false;
  }
}

/// Watches the server the bolt chose; puts the choice back on [autoTag] when it fails (see [pingAndChooseBest]). Stops when
/// the choice is changed by hand, the connection ends, or the bolt chooses again.
Future<void> _watchBolt(WidgetRef ref, String tag, String autoTag) async {
  final id = ++_boltWatch;
  var bad = 0;
  try {
    while (id == _boltWatch) {
      await Future<void>.delayed(const Duration(seconds: 10));
      if (id != _boltWatch) return;
      final group = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
      if (group == null || group.selected != tag) return;
      final ms = group.items.where((i) => i.tag == tag).firstOrNull?.urlTestDelay ?? 0;
      final slow = alertLimits(mobile: _actualNetworkKind.value == NetworkKind.mobile).ping;
      bad = (ms <= 0 || ms >= 65000 || ms >= slow) ? bad + 1 : 0;
      if (bad < 3) continue;
      await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy('select', autoTag);
      ref.read(inAppNotificationControllerProvider).showInfoToast(ref.read(translationsProvider).requireValue.avpn.bestBack);
      return;
    }
  } catch (_) {
    // the screen is gone, or no connection: nothing to watch
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
/// shape (Dots: a bolt of dots, no frame; Bento and the others: the accent or the dark disc).
class _BestButton extends HookConsumerWidget {
  const _BestButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    final running = useValueListenable(homeBestRunning);
    // while the servers are pinged the bolt charges: its dots light from the bottom up, round and round
    final charging = useAnimationController(duration: lightDuration(const Duration(milliseconds: 1300)));
    useEffect(() {
      if (running) {
        charging.repeat();
      } else {
        charging
          ..stop()
          ..value = 0;
      }
      return null;
    }, [running]);
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
          child: dots
              // Dots: the bolt on a plate, drawn as the figures are (dots, solid, in a font); red while the servers are pinged
              ? _SignPlate(
                  child: _DotSign(
                    glyph: '⚡',
                    colour: ink,
                    charge: _Dots.red,
                    progress: running ? () => charging.value : null,
                    repaint: charging,
                  ),
                )
              : Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                  child: running
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: ink))
                      : Icon(Icons.bolt_rounded, size: 22, color: ink),
                ),
        ),
      ),
    );
  }
}
