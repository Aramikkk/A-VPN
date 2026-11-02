part of 'avpn_home_body.dart';

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
