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

/// Pings every server anew and chooses the fastest one (see [fastestServer]); the choice stays on it until Auto is
/// chosen again in the list. Tells which server it came to.
Future<void> pingAndChooseBest(WidgetRef ref) async {
  if (homeBestRunning.value) return;
  homeBestRunning.value = true;
  final t = ref.read(translationsProvider).requireValue;
  final tell = ref.read(inAppNotificationControllerProvider);
  try {
    await pingAllServers(ref);
    final group = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    final network = ref.read(ConfigOptions.serversByNetwork) ? _actualNetworkKind.value : NetworkKind.unknown;
    final pick = fastestServer(group?.items ?? const <OutboundInfo>[], network: network);
    if (pick == null) {
      tell.showInfoToast(t.avpn.bestNone);
    } else {
      if (group?.selected != pick.tag) {
        await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy('select', pick.tag);
      }
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
              // Dots: no frame, the bolt in the dots of the ping figures beside it (red while the servers are pinged)
              ? SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: CustomPaint(
                      size: Size(7 * 3.6, 9 * 3.6),
                      painter: _DotBoltPainter(
                        cell: 3.6,
                        colour: ink,
                        charge: _Dots.red,
                        faint: _Dots.grid(dark),
                        progress: running ? () => charging.value : null,
                        repaint: charging,
                      ),
                    ),
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
