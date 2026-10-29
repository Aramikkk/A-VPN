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
  final summary = summarize(session);
  return (ping: on ? summary.ping : null, loss: summary.loss ?? 0);
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
                      colour: on && measured && !busy && loss >= _DotsStats.alertLoss ? _Dots.red : _Dots.ink(dark),
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
              onTap: on && !busy && !testing ? onCheck : null,
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
                  // the servers of this session (what the "Servers VPN" tab over the panel opened)
                  onTap: on ? () => showGlassPopup(context, const _SessionServers()) : null,
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

/// The round button under two arcs, like a speedometer, filled from the top outwards both ways: the outer one the
/// ping (the lower, the fuller), in the
/// accent, the inner one the loss (none: full), in a deep shade of it; the numbers under the arcs' ends.
/// Off, or connected before the first ping, just the button; connecting, a short arc runs along the outer one.
class _GaugeOrb extends HookWidget {
  const _GaugeOrb({
    required this.on,
    required this.busy,
    this.onTap,
    this.size = 74,
    this.ping = 0,
    this.loss = 0,
    this.pingLabel,
    this.lossLabel,
    this.networkLabel,
    this.actualMobile = false,
  });

  /// the button's diameter; the arcs and numbers take about twice that across
  final double size;

  /// how much of each arc is filled, 0 to 1
  final double ping;
  final double loss;

  final String? pingLabel;
  final String? lossLabel;

  final String? networkLabel;
  final bool actualMobile;

  final bool on;
  final bool busy;
  final VoidCallback? onTap;

  /// 50 ms or less fills it all, 800 ms or more a sliver; between, smoothly on a log scale
  static double pingFill(int delay) {
    const best = 50.0;
    const worst = 800.0;
    final f = 1 - (math.log(delay.clamp(best, worst)) - math.log(best)) / (math.log(worst) - math.log(best));
    return .06 + .94 * f;
  }

  /// no loss fills it all, 20% or more a sliver
  static double lossFill(double percent) => .06 + .94 * (1 - percent.clamp(0, 20) / 20);

  /// the accent made much deeper, the same hue: the loss's colour
  static Color deep(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness * .55).clamp(.22, .4)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // switching: both arcs fill to the full and back, once every this long
    final spin = useAnimationController(duration: const Duration(milliseconds: 1600));
    // the arcs as last drawn, so switching flows on from the gauge and the gauge from the wave, with no jump to empty
    final drawn = useRef(Offset.zero);
    // where the arcs head: the ping and the loss change every few seconds by a hair, and each change set the arcs
    // gliding again for 0.7 s, so the screen redrew all the time at rest (40 frames a second); they head for a new
    // value only when it's at least 8% of the arc away
    final heading = useRef(Offset.zero);
    // and when they last moved: the ping jumps by 30 ms and more every few seconds, and each jump was 0.7 s of full frame
    // rate (the screen redrew 10 times a second at rest); now a jump moves them once in ten seconds at the most
    final moved = useRef(DateTime.fromMillisecondsSinceEpoch(0));
    useEffect(() {
      if (busy) {
        // the pulse starts bright
        spin.value = .5;
        spin.repeat();
      } else {
        spin.stop();
      }
      return null;
    }, [busy]);
    // the theme's own colour, the same as the chosen server (not the darker one text uses on white)
    final accent = theme.araAccent;
    // the loss's inner frame a deep shade of the accent; Citrus: grey (its deep olive looked muddy)
    // Contrast: the loss in grey on every palette (a deep shade of a light accent looked muddy)
    final lossColor = theme.contrastLayout ? (dark ? const Color(0xFF6B7178) : const Color(0xFF8C939C)) : deep(accent);
    final contrastDay = !dark && theme.contrastLayout;
    // the network's sign on the light button: graphite when the accent is too light to read on it (citrus, lemon)
    // by night on the dark button the accent itself
    final onButton = dark
        ? accent
        : (AraLook.contrast(theme.araIcon, const Color(0xFFF7F5F1)) >= 2.2 ? theme.araIcon : ContrastPalette.ink);
    // the numbers readable: by day a light accent goes to the text colour; the deep shade lifted a little by night
    final pingInk = dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : scheme.onSurface;
    final lossInk = dark ? Color.lerp(lossColor, Colors.white, .35)! : lossColor;
    final width = size * 2.1;
    // Contrast: a rounded-square button in two square frames, the ping outside, the loss inside
    final square = theme.contrastLayout;
    // the square: its numbers inside the button, the frames reaching below it
    final centre = square ? size * .94 : size * .98;
    // There is no secondary mode pill under the button.
    final height = square ? centre + size * .84 : centre + size * .5;
    final outer = square ? size * .74 : size * .86;
    final inner = square ? size * .58 : size * .7;
    // the square's button a little smaller, inside its frames
    final button = square ? size * .92 : size;
    final label = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: size * .15);
    Widget number(String? text, Color ink, bool left) => Positioned(
      // the square's numbers under its frames, at their corners
      top: square ? centre - outer - size * .3 : centre + size * .12,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: (width - size) / 2,
      child: AnimatedOpacity(
        opacity: text == null ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text ?? '', style: label?.copyWith(color: ink)),
        ),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        // the mode pill reaches into the panel's padding under it
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<Offset>(
              // both arcs glide to new values; started over when switching ends, from where the wave was
              key: ValueKey(busy),
              // in steps of 2%: each second's ping doesn't start the arcs gliding again for a hair's change
              tween: Tween(
                begin: drawn.value,
                end: _headingFor(heading, moved, on && !busy ? Offset(_step(ping), _step(loss)) : Offset.zero),
              ),
              duration: lightDuration(const Duration(milliseconds: 500)),
              curve: Curves.easeOutCubic,
              builder: (context, filled, _) {
                // switching: drawn whole (the gauge glides down from the full when it ends)
                drawn.value = busy ? const Offset(1, 1) : filled;
                final gauge = RepaintBoundary(
                  child: CustomPaint(
                    painter: _RainbowPainter(
                      centre: Offset(width / 2, centre),
                      radii: (outer, inner),
                      // by night the empty part leans to the accent: plain grey stood out on the warm themes
                      track: dark
                          ? Color.lerp(scheme.outlineVariant, accent, .3)!.withValues(alpha: .45)
                          : scheme.onSurface.withValues(alpha: .1),
                      colors: (accent, lossColor),
                      fills: busy ? (1, 1) : (filled.dx, filled.dy),
                      busy: false,
                      rotation: 0,
                      stroke: square ? size * .085 : size * .1,
                      square: square,
                    ),
                  ),
                );
                if (!busy) return gauge;
                // the pulse: drawn once, only its opacity changing frame to frame (no repainting the glow)
                return AnimatedBuilder(
                  animation: spin,
                  child: gauge,
                  builder: (context, child) =>
                      Opacity(opacity: .3 + .7 * _RainbowPainter.pulse(spin.value), child: child),
                );
              },
            ),
          ),
          // the square has them inside its button
          if (!square) ...[number(pingLabel, pingInk, true), number(lossLabel, lossInk, false)],
          Positioned(
            left: (width - button) / 2,
            top: centre - button / 2,
            width: button,
            height: button,
            child: GestureDetector(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: square ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: square ? BorderRadius.circular(button * .26) : null,
                  // one colour, no gradient; Contrast's is light on its black panel
                  // Contrast: a plain grey while off, light with a touch of the accent while on
                  color: square
                      ? (on
                            // on: by night dark with a glow of the accent (it was near white on the black panel)
                            ? Color.alphaBlend(
                                accent.withValues(alpha: dark ? .2 : .14),
                                dark ? ContrastColours.of(context).pane(true) : Colors.white,
                              )
                            : (dark ? const Color(0xFF2C2C30) : const Color(0xFFECEAE6)))
                      : dark
                      ? const Color(0xFF16161A)
                      : (contrastDay ? Colors.white : const Color(0xFFF7F5F1)),
                  boxShadow: [
                    if (on && !busy) BoxShadow(color: accent.withValues(alpha: dark ? .45 : .3), blurRadius: 28),
                    // Contrast by day: white on the white panel, lifted off it by a soft shadow
                    if (contrastDay)
                      BoxShadow(color: Colors.black.withValues(alpha: .13), blurRadius: 16, offset: const Offset(0, 5)),
                  ],
                ),
                child: Center(
                  // a computer, on: the computer's sign (it has no LTE or Wi-Fi of its own to tell)
                  child: theme.contrastLayout && (networkLabel != null || (PlatformUtils.isDesktop && on && !busy))
                      // Contrast: the mode under the sign, inside the button
                      // Contrast: the network it runs on, large, instead of the power sign (that only while off)
                      ? Semantics(
                          key: const ValueKey('home-network-indicator'),
                          excludeSemantics: true,
                          label: networkLabel ?? 'ПК',
                          child: networkLabel == null
                              ? Icon(Icons.computer_rounded, size: size * .36, color: onButton)
                              : HomeNetworkIndicator(mobile: actualMobile, iconSize: size * .36, color: onButton),
                        )
                      : Icon(
                          networkLabel == null
                              ? Icons.power_settings_new_rounded
                              : (actualMobile ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded),
                          size: size * .42,
                          // the icon in the accent too; by day a light one (yellow, green) can't be read on white, so
                          // it goes black there, as the chosen server's text does
                          color: on
                              ? (theme.araLook.neonFill == null
                                    ? (dark && !theme.contrastLayout ? Colors.white : scheme.primary)
                                    : (dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : Colors.black))
                              : scheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contrast's connect button, as a tile like the session tiles above: while connected the water of the accent fills it
/// and the network's sign (Wi-Fi, LTE) stands on it; off, an empty tile with the power sign; connecting, the water
/// rises and falls. No frames round it: the ping and the servers are the numbers at its sides.
class _Orb extends StatelessWidget {
  const _Orb({
    required this.on,
    required this.busy,
    this.onTap,
    this.size = 74,
    this.ping = 0,
    this.loss = 0,
    this.pingLabel,
    this.lossLabel,
    this.networkLabel,
    this.actualMobile = false,
  });

  final double size;
  final double ping;
  final double loss;
  final String? pingLabel;
  final String? lossLabel;
  final String? networkLabel;
  final bool actualMobile;
  final bool on;
  final bool busy;
  final VoidCallback? onTap;

  /// the old gauge's scales, still used by the other themes
  static double pingFill(int delay) => _GaugeOrb.pingFill(delay);
  static double lossFill(double percent) => _GaugeOrb.lossFill(percent);

  @override
  Widget build(BuildContext context) {
    if (!Theme.of(context).contrastLayout) {
      return _GaugeOrb(
        on: on,
        busy: busy,
        onTap: onTap,
        size: size,
        ping: ping,
        loss: loss,
        pingLabel: pingLabel,
        lossLabel: lossLabel,
        networkLabel: networkLabel,
        actualMobile: actualMobile,
      );
    }
    // Bento and Dots: their own connect control
    if (homeLookNow == HomeLayout.bento) {
      return _BentoButton(on: on, busy: busy, size: size, label: networkLabel, onTap: onTap);
    }
    if (homeLookNow == HomeLayout.dots) {
      return _DotsButton(on: on, busy: busy, size: size, label: networkLabel, onTap: onTap);
    }
    return _WaterButton(
      on: on,
      busy: busy,
      onTap: onTap,
      size: size,
      level: ping,
      networkLabel: networkLabel,
      actualMobile: actualMobile,
    );
  }
}

class _WaterButton extends HookWidget {
  const _WaterButton({
    required this.on,
    required this.busy,
    required this.size,
    required this.level,
    required this.networkLabel,
    required this.actualMobile,
    this.onTap,
  });

  final bool on;
  final bool busy;
  final double size;

  /// the water's height while connected: the ping's fill (0 = not measured yet, half a tile)
  final double level;
  final String? networkLabel;
  final bool actualMobile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    // connecting: the water rises and falls, back and forth
    final wave = useAnimationController(duration: const Duration(milliseconds: 1300));
    final heading = useRef<double?>(null);
    useEffect(() {
      if (busy) {
        wave.repeat(reverse: true);
      } else {
        wave.stop();
      }
      return null;
    }, [busy]);
    final side = size * 1.35;
    final tile = dark ? const Color(0xFF1F2227) : const Color(0xFFF1EFEA);
    const ink = Color(0xFF14171C);
    final lit = on && !busy;
    Widget water(double level) => Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: level.clamp(0.0, 1.0),
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: .82), accent.withValues(alpha: .46)],
            ),
            border: Border(top: BorderSide(color: accent, width: 1.5)),
          ),
        ),
      ),
    );
    // where the water heads: the ping shifts by a hair every few seconds, and each shift set it gliding again for 0.9 s,
    // so the screen redrew nonstop at rest; it heads for a new level only when that is 8% or more away
    final target = on ? (level > 0 ? .1 + .85 * level : .5) : 0.0;
    final prior = heading.value;
    if (prior == null || (target - prior).abs() >= .08 || (target == 0) != (prior == 0)) heading.value = target;
    final fill = busy
        ? AnimatedBuilder(
            animation: wave,
            builder: (context, _) => water(.22 + .5 * Curves.easeInOut.transform(wave.value)),
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(end: heading.value),
            duration: lightDuration(const Duration(milliseconds: 900)),
            curve: Curves.easeOutCubic,
            builder: (context, level, _) => level < .005 ? const SizedBox.shrink() : water(level),
          );
    final showNetwork = networkLabel != null || (PlatformUtils.isDesktop && on && !busy);
    final signColour = lit ? ink : (busy ? scheme.onSurface : scheme.onSurfaceVariant);
    final sign = showNetwork
        ? Semantics(
            key: const ValueKey('home-network-indicator'),
            excludeSemantics: true,
            label: networkLabel ?? 'ПК',
            child: networkLabel == null
                ? Icon(Icons.computer_rounded, size: size * .42, color: signColour)
                : HomeNetworkIndicator(mobile: actualMobile, iconSize: size * .42, color: signColour),
          )
        : Icon(Icons.power_settings_new_rounded, size: size * .46, color: signColour);
    return SizedBox(
      width: size * 2.1,
      height: side + 10,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: side,
            height: side,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: tile,
              borderRadius: BorderRadius.circular(side * .28),
              border: Border.all(color: on || busy ? accent.withValues(alpha: .6) : scheme.outlineVariant),
              boxShadow: [if (lit) BoxShadow(color: accent.withValues(alpha: dark ? .35 : .25), blurRadius: 24)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: RepaintBoundary(child: fill)),
                sign,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RainbowPainter extends CustomPainter {
  /// the switching pulse's brightness at [t] (0 to 1 round the loop): up to the full and back down, smoothly
  static double pulse(double t) => Curves.easeInOut.transform(t < .5 ? t * 2 : 2 - t * 2);

  _RainbowPainter({
    required this.centre,
    required this.radii,
    required this.track,
    required this.colors,
    required this.fills,
    required this.busy,
    required this.rotation,
    required this.stroke,
    this.square = false,
  });

  /// rounded-square frames all round, filled from the bottom's middle up both ways, instead of the upper half-circles
  final bool square;

  final Offset centre;

  /// the ping's arc, outside, and the loss's, inside
  final (double, double) radii;
  final (Color, Color) colors;
  final (double, double) fills;
  final Color track;
  final bool busy;
  final double rotation;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    Paint pen(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = c;
    // the upper half, left to right
    Rect circle(double r) => Rect.fromCircle(center: centre, radius: r);
    // connecting or disconnecting: both arcs fill from nothing to the full and back, over and over, the inner one a
    // little behind
    // connecting or disconnecting: both drawn whole, pulsing (brighter and dimmer), not running back and forth
    final (ping, loss) = busy ? (1.0, 1.0) : fills;
    // the arcs fade in as the ping's fill grows from nothing (a ping always fills at least .06); the pulse
    final shown = busy ? .3 + .7 * pulse(rotation) : (ping / .06).clamp(0.0, 1.0);
    if (shown == 0) return;
    if (square) {
      for (final (r, c, f) in [(radii.$1, colors.$1, ping), (radii.$2, colors.$2, loss)]) {
        final frame = _frame(r);
        final metric = frame.computeMetrics().first;
        final length = metric.length;
        canvas.drawPath(frame, pen(track.withValues(alpha: track.a * shown)));
        if (f < .001) continue;
        // from the bottom's middle both ways at once: the start of the path and its end
        final half = length * f.clamp(0.0, 1.0) / 2;
        final fill = Path()
          ..addPath(metric.extractPath(0, half), Offset.zero)
          ..addPath(metric.extractPath(length - half, length), Offset.zero);
        canvas.drawPath(
          fill,
          pen(c.withValues(alpha: .5 * shown))..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * .7),
        );
        canvas.drawPath(fill, pen(c.withValues(alpha: shown)));
      }
      return;
    }
    for (final (r, c, f) in [(radii.$1, colors.$1, ping), (radii.$2, colors.$2, loss)]) {
      canvas.drawArc(circle(r), math.pi, math.pi, false, pen(track.withValues(alpha: track.a * shown)));
      if (f < .001) continue;
      // filled from the top outwards, the same both ways: a worse value shrinks it from both ends at once
      final from = math.pi * 1.5 - math.pi * f / 2;
      // a soft neon glow under the fill, then the fill itself
      canvas.drawArc(
        circle(r),
        from,
        math.pi * f,
        false,
        pen(c.withValues(alpha: .5 * shown))..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * .7),
      );
      canvas.drawArc(circle(r), from, math.pi * f, false, pen(c.withValues(alpha: shown)));
    }
  }

  /// a rounded square [half] from the centre to each side, as one path from the bottom's middle round clockwise:
  /// filled from both its ends, the frame fills from the bottom up both ways, a worse value opening it at the top
  Path _frame(double half) {
    final l = centre.dx - half;
    final t = centre.dy - half;
    final r = centre.dx + half;
    final b = centre.dy + half;
    final round = Radius.circular(half * .42);
    final k = half * .42;
    return Path()
      ..moveTo(centre.dx, b)
      ..lineTo(l + k, b)
      ..arcToPoint(Offset(l, b - k), radius: round)
      ..lineTo(l, t + k)
      ..arcToPoint(Offset(l + k, t), radius: round)
      ..lineTo(r - k, t)
      ..arcToPoint(Offset(r, t + k), radius: round)
      ..lineTo(r, b - k)
      ..arcToPoint(Offset(r - k, b), radius: round)
      ..lineTo(centre.dx, b);
  }

  @override
  bool shouldRepaint(_RainbowPainter old) =>
      old.square != square ||
      old.rotation != rotation ||
      old.fills != fills ||
      old.busy != busy ||
      old.colors != colors ||
      old.track != track ||
      old.centre != centre;
}

/// Contrast's server row: a white tile (dark grey by night) with the flag in a thin circle, the ping in big
/// figures and a black arrow button; the chosen one filled with a soft gradient of the accent.
class _ContrastRow extends StatelessWidget {
  const _ContrastRow({
    required this.flag,
    this.profile = 0,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.selected,
    required this.networkStyled,
    required this.mobileNetwork,
    required this.testing,
    required this.onTap,
  });

  final String? flag;

  /// which subscription the server is from (0: the active profile)
  final int profile;
  final bool group;
  final String title;
  final String subtitle;
  final int delay;
  final bool selected;
  final bool networkStyled;
  final bool mobileNetwork;
  final bool testing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    final ink = scheme.onSurface;
    final accentFill = networkStyled ? mobileNetwork : selected;
    final softNetworkTint = networkStyled && mobileNetwork;
    final decoration = accentFill
        // The chosen server is only lightly tinted with the theme accent, the same on Wi-Fi and mobile data.
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: dark ? .12 : (softNetworkTint ? .035 : .07)),
                accent.withValues(alpha: dark ? .16 : (softNetworkTint ? .06 : .11)),
                accent.withValues(alpha: dark ? .2 : (softNetworkTint ? .085 : .15)),
              ],
              stops: const [0, .6, 1],
            ),
            border: Border.all(color: accent.withValues(alpha: dark ? .2 : (softNetworkTint ? .12 : .18))),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: softNetworkTint ? .035 : .08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          )
        : BoxDecoration(
            // white (dark by night) as chosen, but see-through again: the backdrop shows through, as in every block
            color: dark ? scheme.surfaceContainerHigh.withValues(alpha: .72) : Colors.white.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(22),
            // see-through: the zone's light shows through
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: .1) : scheme.outlineVariant.withValues(alpha: .25),
            ),
          );
    final ms = delay <= 0 ? '—' : (delay > 65000 ? '×' : '$delay');
    // Auto: the country it's on now right after its name ("Авто 🇵🇱 Польша"), no line under it
    final now = group ? subtitle.indexOf(': ') : -1;
    final nowOn = now < 0 ? null : subtitle.substring(now + 2);
    // a test server's note ("Финляндия (Тестовый)") goes to a second line under the name, not cut off at the end
    final note = nowOn == null ? null : RegExp(r'\s*\(([^()]*)\)').firstMatch(nowOn);
    final country = note == null ? nowOn : nowOn!.replaceRange(note.start, note.end, '').trim();
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: ink);
    final look = _homeLayoutOf(context);
    if (look == HomeLayout.bento || look == HomeLayout.dots) {
      final nameText = group ? (country ?? subtitle) : title;
      final caption = group ? title : subtitle;
      return look == HomeLayout.bento
          ? _bentoServerRow(
              context,
              flag: flag,
              group: group,
              name: nameText,
              caption: caption,
              ms: ms,
              measured: delay > 0 && delay <= 65000,
              selected: selected,
              testing: testing,
              onTap: onTap,
            )
          : _dotsServerRow(
              context,
              flag: flag,
              group: group,
              name: nameText,
              caption: caption,
              ms: ms,
              testing: testing,
              onTap: onTap,
            );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Row(
                children: [
                  FlagBadge(
                    profile: group ? -1 : profile,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? accent : scheme.outlineVariant, width: 1.3),
                      ),
                      child: group
                          ? Icon(Icons.auto_awesome_rounded, size: 18, color: selected ? theme.araIcon : ink)
                          : flagGlyph(flag, emoji: 18, width: 24),
                    ),
                  ),
                  const Gap(11),
                  Expanded(
                    child: group
                        // The home row shows the pending hint once, without a redundant "Server" prefix.
                        ? Row(
                            children: [
                              if (!networkStyled) Text(title, style: titleStyle?.copyWith(fontWeight: FontWeight.w700)),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      country ?? subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: titleStyle?.copyWith(color: ink.withValues(alpha: .8)),
                                    ),
                                    if (note != null)
                                      Text(
                                        note[1]!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: ink.withValues(alpha: .7),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: selected ? ink.withValues(alpha: .75) : scheme.onSurfaceVariant,
                                  fontWeight: group ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Gap(8),
                  if (testing)
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                  else
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: ms),
                          if (delay > 0 && delay <= 65000)
                            TextSpan(
                              text: ' ms',
                              style: TextStyle(
                                fontSize: selected ? 12 : 10,
                                letterSpacing: 0,
                                color: ink.withValues(alpha: .65),
                              ),
                            ),
                        ],
                      ),
                      // the server in use: a bigger figure; the others the size of the name, in the text's colour
                      style: titleStyle?.copyWith(fontWeight: FontWeight.w700, fontSize: selected ? 24 : null),
                    ),
                  const Gap(10),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark ? const Color(0xFFF3F1EC) : const Color(0xFF111111),
                    ),
                    child: Icon(
                      Icons.north_east_rounded,
                      size: 15,
                      color: dark ? const Color(0xFF111111) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile's water. Its level glides, but only to a level 8% or more from where it is heading: the traffic shifting a
/// few percent between the VPN and direct every second kept the water gliding (900 ms each time) and the screen
/// redrew nonstop at rest.
class _Water extends HookWidget {
  const _Water({required this.level, required this.colour, required this.dark});

  final double level;
  final Color colour;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final heading = useRef<double?>(null);
    final next = level.clamp(0.0, 1.0);
    final now = heading.value;
    if (now == null || (next - now).abs() >= .08 || (next == 0) != (now == 0)) heading.value = next;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: heading.value),
      duration: lightDuration(const Duration(milliseconds: 900)),
      curve: Curves.easeOutCubic,
      builder: (context, l, _) => l < .005
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: l,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colour.withValues(alpha: dark ? .25 : .19),
                        colour.withValues(alpha: dark ? .4 : .3),
                      ],
                    ),
                    border: l > .97 ? null : Border(top: BorderSide(color: colour.withValues(alpha: .6), width: 1.5)),
                  ),
                ),
              ),
            ),
    );
  }
}

/// How good a speed is as the water of a tile: nothing at 100 КБ/с or less, full at 10 МБ/с or more, between on a
/// log scale.
double _speedLevel(int bytesPerSecond) {
  const low = 100 * 1024;
  const high = 10 * 1024 * 1024;
  if (bytesPerSecond <= low) return 0;
  return (math.log(bytesPerSecond / low) / math.log(high / low)).clamp(0.0, 1.0);
}
