part of 'avpn_home_body.dart';

class _GraphiteRow extends StatelessWidget {
  const _GraphiteRow({
    required this.flag,
    this.profile = 0,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.selected,
    required this.testing,
    required this.first,
    required this.onTap,
    this.networkStyled = false,
    this.mobileNetwork = false,
    this.flooded = false,
    this.lead,
    this.pingShown = true,
  });

  final String? flag;

  /// which subscription the server is from (0: the active profile)
  final int profile;
  final bool group;
  final String title;
  final String subtitle;
  final int delay;
  final bool selected;
  final bool testing;
  final bool first;
  final VoidCallback onTap;

  final bool networkStyled;
  final bool mobileNetwork;

  /// already drawn inside the neon theme override
  final bool flooded;

  /// a button at the left: the server is then in the middle of the row (the current server's one)
  final Widget? lead;

  /// whether the ping is written in the row (the current server's row on the home screen: only for a server chosen by hand)
  final bool pingShown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = theme.araLook.neonFill;
    if (theme.contrastLayout) {
      return _ContrastRow(
        flag: flag,
        profile: profile,
        group: group,
        title: title,
        subtitle: subtitle,
        delay: delay,
        selected: selected,
        networkStyled: networkStyled,
        mobileNetwork: mobileNetwork,
        testing: testing,
        onTap: onTap,
        lead: lead,
        pingShown: pingShown,
      );
    }
    if (selected && fill != null && !flooded) {
      // the neon themes: the chosen row is the neon itself; the text on it white on the deeper neons (red, blue,
      // pink, violet…), black on the light ones (yellow, green, mint, lavender…)
      final ink = AraLook.contrast(Colors.white, fill) >= 2.2 ? Colors.white : Colors.black;
      return Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
          colorScheme: scheme.copyWith(
            primary: ink,
            onSurface: ink,
            onSurfaceVariant: ink,
            surfaceContainerHigh: fill,
            surfaceContainerHighest: Colors.black.withValues(alpha: .14),
          ),
          // the ping in the same ink (its scale would otherwise shift it to read on the neon)
          extensions: [
            AraLook(
              fastPing: ink,
              pingOn: ink == Colors.white ? Colors.black : Colors.white,
              dark: ink == Colors.white,
            ),
          ],
        ),
        child: _GraphiteRow(
          flag: flag,
          group: group,
          title: title,
          subtitle: subtitle,
          delay: delay,
          selected: selected,
          networkStyled: networkStyled,
          mobileNetwork: mobileNetwork,
          testing: testing,
          first: first,
          onTap: onTap,
          flooded: true,
        ),
      );
    }
    final glass = theme.glassLook;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        // the chosen one: a tint of the accent and an accent outline
        // Glass: every row a see-through pane, the chosen one tinted with the scheme's colour
        color: glass != null
            ? (selected
                  ? Color.alphaBlend(glass.tint(scheme.onSurface, glass.dark ? .22 : .5), glass.panel)
                  : glass.panel)
            : flooded
            ? scheme.surfaceContainerHigh
            : selected
            ? Color.alphaBlend(scheme.primary.withValues(alpha: dark ? .1 : .07), scheme.surfaceContainerHigh)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(glass != null ? 22 : 18),
          // a thin frame round every server, so the rows don't run into one; the chosen one's is thicker
          // by day soft grey frames (black ones looked heavy), the chosen one a darker grey and thicker
          side: glass != null
              ? (selected
                    // the chosen one: an outline in the scheme's colour (no tick at the end)
                    ? BorderSide(color: scheme.primary, width: 2)
                    : BorderSide(color: glass.edge, width: 1.2))
              : selected
              ? BorderSide(
                  color: flooded ? (dark ? Colors.white : const Color(0xFF8E8E96)) : scheme.primary,
                  width: 2.2,
                )
              : BorderSide(color: dark ? Colors.white.withValues(alpha: .2) : const Color(0xFFD3D3D9), width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(glass != null ? 22 : 18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                // the flag on its own, larger (a grey tile under it looked dull)
                FlagBadge(
                  profile: group ? -1 : profile,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: group
                          ? AraIconPaint(child: Icon(Icons.auto_awesome_rounded, size: 24, color: scheme.primary))
                          : flagGlyph(flag, emoji: 28, width: 36),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: selected ? 17 : 16.5,
                        ),
                      ),
                      const Gap(1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Auto's "сейчас: 🇵🇱 Польша · БС" a little larger, bolder and darker: it says where it is now
                        style: group
                            ? theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: .82),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              )
                            : theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                _Delay(delay: delay, testing: testing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The status a tap started from, until the core settles somewhere else: the button shows as switching all that
/// time. The call returns at once while the core takes its time (right after turning off, a few seconds before it
/// even says "connecting"), and the button looked off meanwhile. A tap while one is pending is dropped, so off and
/// straight on again don't stack.
final _pendingConnectionProvider = NotifierProvider<_PendingConnection, ConnectionStatus?>(_PendingConnection.new);

class _PendingConnection extends Notifier<ConnectionStatus?> {
  Timer? _timeout;

  @override
  ConnectionStatus? build() {
    ref.onDispose(() => _timeout?.cancel());
    return null;
  }

  void begin(ConnectionStatus current) {
    if (state != null) return;
    state = current;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 30), clear);
  }

  void clear() {
    _timeout?.cancel();
    _timeout = null;
    state = null;
  }
}

Future<void> _toggleConnection(WidgetRef ref) async {
  final pending = ref.read(_pendingConnectionProvider.notifier);
  if (ref.read(_pendingConnectionProvider) != null) return;
  if (ref.read(activeProfileProvider).valueOrNull == null) {
    await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
    ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
    return;
  }
  pending.begin(ref.read(connectionNotifierProvider).valueOrNull ?? const Disconnected());
  // the button pressed: the backdrop laid out anew, faded in over the old one (only then and when the app starts,
  // not on a reconnect by itself)
  ref.read(contrastBackdropLayoutProvider.notifier).next();
  try {
    await ref.read(connectionNotifierProvider.notifier).toggleConnection();
  } catch (_) {
    pending.clear();
    rethrow;
  }
}

/// Ping and loss through the VPN, measured every three seconds (the probes the Statistics tab shows; the tunnel's warm-up
/// is left out there already), this connection's only. Null ping until there's an answer.
({int? ping, double loss}) _sessionQuality(WidgetRef ref, bool on) {
  final samples = ref.watch(connectionQualityProvider);
  final quality = ref.read(connectionQualityProvider.notifier);
  final session = samples.sublist(samples.length - math.min(quality.sinceConnect, samples.length));
  // the loss of the last five minutes (100 probes), not of the whole connection: one lost probe early on would stay in
  // the figure for as long as the VPN is up
  final summary = summarize(session.length > 100 ? session.sublist(session.length - 100) : session);
  // under a minute of probes (20) one lost probe is a fifth of them: the figure waits, as after a restart it read 20%
  return (ping: on ? summary.ping : null, loss: session.length < 20 ? 0 : summary.loss ?? 0);
}

String _lossText(double loss) => loss == 0 ? '0%' : '${loss.toStringAsFixed(loss < 10 ? 1 : 0)}%';

/// Graphite's connect panel: the glowing ring button, the state and server, and a pill button.
class _GraphiteDock extends HookConsumerWidget {
  const _GraphiteDock({
    required this.status,
    required this.server,
    required this.actualMobile,
    required this.networkKnown,
    required this.testing,
    required this.onCheck,
    this.large = false,
  });

  final bool large;

  final ConnectionStatus status;
  final String? server;
  final bool actualMobile;
  final bool networkKnown;
  final bool testing;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final on = status.isConnected;
    final pendingFrom = ref.watch(_pendingConnectionProvider);
    // the tap's done once the core has settled on another status (on, off, or a failure)
    ref.listen(shownConnectionProvider, (_, next) {
      if (pendingFrom != null && !next.isSwitching && next != pendingFrom) {
        ref.read(_pendingConnectionProvider.notifier).clear();
      }
    });
    if (pendingFrom != null && !status.isSwitching && status != pendingFrom) {
      Future.microtask(() => ref.read(_pendingConnectionProvider.notifier).clear());
    }
    final busy = status.isSwitching || pendingFrom != null;
    final glass = theme.glassLook;
    // Contrast: tight, on its black panel
    final padding = theme.contrastLayout
        ? const EdgeInsets.fromLTRB(12, 4, 12, 2)
        : (large ? const EdgeInsets.fromLTRB(12, 16, 12, 16) : const EdgeInsets.fromLTRB(10, 10, 12, 10));
    // the servers answering their ping right now (a test that timed out or never ran doesn't count)
    final group = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    final answeringServers = [
      for (final item in group?.items ?? <OutboundInfo>[])
        if (!item.isGroup && item.isVisible && item.urlTestDelay > 0 && item.urlTestDelay < 65000) item,
    ]..sort((a, b) => a.urlTestDelay.compareTo(b.urlTestDelay));
    final answering = answeringServers.length;
    final shownServers = [
      for (final item in group?.items ?? <OutboundInfo>[])
        if (!item.isGroup && item.isVisible) item,
    ].length;
    final dotsLook = homeLookNow == HomeLayout.dots;
    final (:ping, :loss) = _sessionQuality(ref, on);
    final measured = ping != null;
    final lossText = _lossText(loss);
    // Keep the server type and physical network distinct: both can be shown during a handoff.
    final networkLabel = !on || busy || !networkKnown || PlatformUtils.isDesktop
        ? null
        : (actualMobile ? 'LTE' : 'Wi‑Fi');
    final accent = theme.araAccent;
    // the side icons and the ping in the accent (by day a light accent goes to the text colour); grey while off
    final ink = on
        ? (theme.araLook.fill != null
              ? theme.araIcon
              : (dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : scheme.onSurface))
        : scheme.onSurfaceVariant;
    // Contrast: the side figures and captions a little bigger
    final sideFigure = theme.contrastLayout ? 25.0 : null;
    final caption = (theme.contrastLayout ? theme.textTheme.labelLarge : theme.textTheme.labelMedium)?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
      // Bento and Dots: their own faces
      fontFamily: switch (homeLookNow) {
        HomeLayout.dots => 'JetBrains Mono',
        _ => null,
      },
      letterSpacing: homeLookNow == HomeLayout.dots ? 1.6 : null,
      fontSize: homeLookNow == HomeLayout.dots ? 12 : null,
    );
    final figureFace = switch (homeLookNow) {
      HomeLayout.bento => 'Unbounded',
      HomeLayout.dots => 'JetBrains Mono',
      _ => null,
    };
    final iconSize = (large ? 28.0 : 26.0) * (theme.contrastLayout ? 1.05 : 1);
    // no plates: an icon (or a number) over a small caption, pressed as one
    // on a barely-there plate, as the toggles above
    // Contrast: the ping and the servers' figures in the ping frame's colour (their signs in the text colour), the
    // loss in its frame's grey
    final contrastOn = theme.contrastLayout && on;
    final gaugeInk = contrastOn ? (homeLookNow == HomeLayout.dots ? _Dots.ink(dark) : accent) : ink;
    final lossInk = dark ? const Color(0xFFA3A9B0) : const Color(0xFF8C939C);
    Widget side({required Widget top, required String label, VoidCallback? onTap, Color? labelColor, Widget? meter}) =>
        Material(
          // Contrast: no plate, right on its black panel
          color: theme.contrastLayout ? Colors.transparent : scheme.onSurface.withValues(alpha: dark ? .06 : .045),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              // shrinks rather than overflows on the narrowest screens
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: iconSize + 2,
                      child: Center(child: top),
                    ),
                    const Gap(4),
                    Text(
                      homeLookNow == HomeLayout.dots ? label.toUpperCase() : label,
                      style: labelColor == null ? caption : caption?.copyWith(color: labelColor),
                    ),
                    if (meter != null) ...[const Gap(6), meter],
                  ],
                ),
              ),
            ),
          ),
        );
    // the glowing gauge in the middle; the ping check on its left and the servers answering on its right
    final content = Row(
      children: [
        Expanded(
          // Contrast: the ping button a little to the left of its half's middle
          child: Align(
            alignment: theme.contrastLayout ? const Alignment(-.45, 0) : Alignment.center,
            child: side(
              top: on && testing
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: ink))
                  : dotsLook
                  // Dots: the figure in the dot matrix, as the ping above
                  ? _DotNumber(
                      on && measured && !busy ? lossText : '—',
                      cell: 3.6,
                      colour: on && measured && !busy && loss >= _DotsStats.limits.loss ? _Dots.red : _Dots.ink(dark),
                      faint: _Dots.ink(dark).withValues(alpha: .14),
                    )
                  : theme.contrastLayout
                  // Contrast: the loss here, as the servers answering are on the right: the sign and the figure (the ping is
                  // in the top block; a tap here still pings)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_down_rounded, size: iconSize, color: contrastOn ? scheme.onSurface : ink),
                        const Gap(6),
                        Text(
                          on && measured && !busy ? lossText : '—',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1,
                            fontSize: sideFigure,
                            fontFamily: figureFace,
                            color: contrastOn && measured && !busy ? gaugeInk : null,
                          ),
                        ),
                      ],
                    )
                  : Icon(Icons.network_ping_rounded, size: iconSize, color: ink),
              // Contrast: the loss's name under it
              label: theme.contrastLayout ? t.avpn.dockLossLabel : t.avpn.stPingButton,
              labelColor: theme.contrastLayout && on && measured && !busy ? lossInk : null,
              // the servers of this session (what the "Servers VPN" tab over the panel opened)
              onTap: on ? () => showGlassPopup(context, const _SessionServers()) : null,
              // Dots: ten dots, a tenth lit for each tenth of the packets lost
              meter: dotsLook
                  ? _dotMeter(context, on && measured && !busy ? (loss / 10).ceil().clamp(0, 10) : 0, _Dots.red)
                  : null,
            ),
          ),
        ),
        _Orb(
          on: on,
          // connected but no ping yet: the arcs keep filling and emptying until the first one comes, so switching
          // flows straight into the gauge
          // (only for a connection just started: one found up when the app opened shows its gauge straight away)
          busy: busy || (on && !measured && ref.read(connectionQualityProvider.notifier).warmUp),
          // Contrast: a fifth smaller
          size: (large ? 88.0 : 76.0) * (theme.contrastLayout ? .8 : 1),
          ping: measured ? _Orb.pingFill(ping) : 0,
          loss: measured ? _Orb.lossFill(loss) : 0,
          pingLabel: measured && !busy ? '$ping ms' : null,
          lossLabel: measured && !busy ? lossText : null,
          networkLabel: networkLabel,
          actualMobile: actualMobile,
          onTap: busy ? null : () => _toggleConnection(ref),
        ),
        Expanded(
          child: Center(
            child: Semantics(
              label: t.avpn.dockServersAnswering(count: answering),
              child: ExcludeSemantics(
                child: side(
                  top: dotsLook
                      ? _DotNumber(
                          on ? '$answering' : '—',
                          cell: 3.6,
                          colour: _Dots.ink(dark),
                          faint: _Dots.ink(dark).withValues(alpha: .14),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.dns_rounded, size: iconSize - 2, color: contrastOn ? scheme.onSurface : ink),
                            const Gap(6),
                            Text(
                              on ? '$answering' : '—',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1,
                                fontSize: sideFigure,
                                fontFamily: figureFace,
                                color: contrastOn ? gaugeInk : null,
                              ),
                            ),
                          ],
                        ),
                  label: t.avpn.dockActive,
                  // Dots: ten dots, as many lit as the share of the servers answering
                  meter: dotsLook
                      ? _dotMeter(
                          context,
                          on && shownServers > 0 ? (answering * 10 / shownServers).round().clamp(0, 10) : 0,
                          _Dots.ink(dark),
                        )
                      : null,
                  // the servers answering their ping, the fastest first; one tapped is chosen
                  onTap: on && answering > 0
                      ? () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .6),
                          builder: (_) => _AnsweringSheet(servers: answeringServers, selected: group?.selected),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    // Contrast: right on its black panel, no card round it
    if (theme.contrastLayout) return Padding(padding: padding, child: content);
    // Glass: floating over the backdrop, what's behind it blurred
    if (glass != null) {
      return GlassPane(look: glass, radius: large ? 40 : 32, padding: padding, child: content);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: dark ? .85 : 1),
        borderRadius: BorderRadius.circular(large ? 40 : 32),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: dark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: content,
    );
  }
}
