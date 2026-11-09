part of 'avpn_home_body.dart';

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
    this.lead,
  });

  /// a button at the left, the server in the middle (the current server's row)
  final Widget? lead;

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
              lead: lead,
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
              lead: lead,
            );
    }
    if (lead != null && !group) {
      // the current server: the button at the left, the flag and the country in the middle, the ping at the right
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
                child: _centeredServer(
                  lead: lead!,
                  reserve: 82,
                  center: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FlagBadge(
                        profile: profile,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? accent : scheme.outlineVariant, width: 1.3),
                          ),
                          child: flagGlyph(flag, emoji: 18, width: 24),
                        ),
                      ),
                      const Gap(11),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: ink.withValues(alpha: .75)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: testing
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: ms),
                              if (delay > 0 && delay <= 65000)
                                TextSpan(
                                  text: ' ms',
                                  style: TextStyle(fontSize: 11, letterSpacing: 0, color: ink.withValues(alpha: .65)),
                                ),
                            ],
                          ),
                          style: titleStyle?.copyWith(fontWeight: FontWeight.w700, fontSize: 24),
                        ),
                ),
              ),
            ),
          ),
        ),
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
