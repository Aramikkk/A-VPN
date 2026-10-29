part of 'avpn_home_body.dart';

/// The home screen's look in use (Settings → Themes → Home), for widgets with no provider reference of their own; the
/// super light mode always has the classic one.
HomeLayout _homeLayoutOf(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    if (container.read(superLightProvider)) return HomeLayout.classic;
    return container.read(Preferences.homeLayout);
  } catch (_) {
    return HomeLayout.classic;
  }
}

/// The Dots style's one colour as chosen (by day or by night), set where the look is: the shell and the backdrop.
Color dotsAccentNow = DotsAccent.fallback.colour;

/// The home screen's look as the backdrop last drew it: for the panel's colour and the connect control, which have no
/// provider reference of their own.
HomeLayout homeLookNow = HomeLayout.classic;

/// Bento's page under the tiles: plain, no stripes.
Color _bentoPage(bool dark) => dark ? const Color(0xFF0E0E10) : const Color(0xFFF2F2F5);

/// The backdrop of a look that has its own (Bento's plain page, Dots' dotted paper), or null for the others.
Widget? lookBackdrop(HomeLayout look, bool dark) => switch (look) {
  HomeLayout.bento => ColoredBox(color: _bentoPage(dark)),
  HomeLayout.dots => CustomPaint(
    painter: _DotGridPainter(paper: _Dots.paper(dark), dot: _Dots.grid(dark)),
  ),
  _ => null,
};

/// A card of another page in a look that has its own (Bento's solid tile, Dots' outlined box on the paper), or null.
Widget? lookCard(
  HomeLayout look,
  bool dark, {
  required Widget child,
  required EdgeInsets padding,
  required double radius,
}) => switch (look) {
  HomeLayout.bento => Container(
    padding: padding,
    decoration: BoxDecoration(color: _Bento.tile(dark), borderRadius: BorderRadius.circular(bentoRadius)),
    child: child,
  ),
  HomeLayout.dots => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _Dots.paper(dark),
      borderRadius: BorderRadius.circular(dotsRadius),
      border: Border.all(color: _Dots.ink(dark).withValues(alpha: .28)),
    ),
    child: child,
  ),
  _ => null,
};

/// The corner every pane of a look has: Bento's round tiles, Dots' nearly square boxes.
const bentoRadius = 26.0;
const dotsRadius = 6.0;

/// the corner of a pane in [look] (null: the look's own as the caller has it)
double? lookRadius(HomeLayout look) => switch (look) {
  HomeLayout.bento => bentoRadius,
  HomeLayout.dots => dotsRadius,
  _ => null,
};

/// the looks whose blocks draw their own tiles (no frosted pane round them)
bool _bareLayout(HomeLayout layout) => layout == HomeLayout.bento || layout == HomeLayout.dots;

// ───────────────────────────── Bento ─────────────────────────────

/// Bento: solid tiles of different sizes, as a phone's widgets; one bright tile in the accent for the ping, a second
/// bright one for the VPN's share, heavy round figures.
abstract final class _Bento {
  static Color tile(bool dark) => dark ? const Color(0xFF2A2A2F) : Colors.white;
  static Color inner(bool dark) => dark ? const Color(0xFF3A3A40) : const Color(0xFFF0F0F2);
  static const orange = Color(0xFFFF6B3D);
  static const orangeInk = Color(0xFF3B1608);
  static const radius = bentoRadius;

  static TextStyle figure(double size, Color colour) => TextStyle(
    fontFamily: 'Unbounded',
    fontWeight: FontWeight.w800,
    fontSize: size,
    height: 1,
    letterSpacing: -size * .045,
    color: colour,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle label(Color colour) =>
      TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 11.5, color: colour, height: 1.2);
}

Widget _bentoTile(
  BuildContext context,
  Widget child, {
  Color? colour,
  EdgeInsets padding = const EdgeInsets.all(14),
  double radius = _Bento.radius,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: padding,
    decoration: BoxDecoration(color: colour ?? _Bento.tile(dark), borderRadius: BorderRadius.circular(radius)),
    child: child,
  );
}

/// The ping's last answers as a thick line, the newest on the right (the hero tile's corner).
class _SparkPainter extends CustomPainter {
  _SparkPainter(this.samples, this.colour);

  final List<int?> samples;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final s in samples.length > 30 ? samples.sublist(samples.length - 30) : samples)
        if (s != null) s.toDouble(),
    ];
    if (values.length < 2) return;
    // from zero to a round number over the highest answer (at least 200 ms): 40 ms and 100 ms sit at different
    // heights, the same on every look (it was drawn from the lowest to the highest answer, so any ping filled it)
    // capped at 400 ms: a few timeouts (1500 ms) must not squash every normal answer into a stripe; they run off the top
    final top = math.min(_niceMax(values.reduce(math.max), least: 200), 400.0);
    final plot = size.width - 22;
    for (final mark in const [100, 200, 400, 800]) {
      if (mark > top) break;
      final y = 3 + (size.height - 6) * (1 - mark / top);
      canvas.drawLine(
        Offset(0, y),
        Offset(plot, y),
        Paint()
          ..color = colour.withValues(alpha: .28)
          ..strokeWidth = 1,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$mark',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: colour.withValues(alpha: .6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(plot + 3, y - label.height / 2));
    }
    final path = Path();
    for (final (i, v) in values.indexed) {
      final x = plot * i / (values.length - 1);
      final y = 3 + (size.height - 6) * (1 - (v / top).clamp(0.0, 1.0));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.samples != samples || old.colour != colour;
}

class _BentoStats extends HookConsumerWidget {
  const _BentoStats({
    required this.connected,
    required this.timeText,
    required this.ping,
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    required this.vpnShare,
    this.slim = false,
  });

  final bool connected;
  final String timeText;
  final int? ping;
  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final double vpnShare;
  final bool slim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final ink = _onAccent(theme.araAccent);
    final live = ref.watch(connectionQualityProvider);
    final kept = useRef<List<int?>>(const []);
    if (connected && live.isNotEmpty) kept.value = live;
    final samples = connected ? live : kept.value;
    Widget heroTile({required bool fill}) => _bentoTile(
      context,
      SizedBox(
        // given a tight height (the page has room to spare) it fills it
        height: fill ? double.infinity : (slim ? 84 : 118),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.avpn.pingNow.toUpperCase()} · $timeText', style: _Bento.label(ink.withValues(alpha: .62))),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(connected && ping != null ? '$ping' : '—', style: _Bento.figure(slim ? 54 : 78, ink)),
                    const Gap(4),
                    if (connected && ping != null) Text('ms', style: _Bento.figure(15, ink)),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 4,
              width: slim ? 90 : 120,
              height: slim ? 36 : 52,
              child: CustomPaint(painter: _SparkPainter(samples, ink)),
            ),
          ],
        ),
      ),
      colour: accent,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    );
    if (slim) return heroTile(fill: false);
    final muted = scheme.onSurfaceVariant;
    final share = (vpnShare * 100).round();
    return LayoutBuilder(
      builder: (context, box) {
        final fill = box.hasTightHeight;
        Widget tilesRow(Widget row) => fill ? Expanded(flex: 2, child: row) : IntrinsicHeight(child: row);
        return Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fill) Expanded(flex: 3, child: heroTile(fill: true)) else heroTile(fill: false),
            const Gap(8),
            tilesRow(
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _bentoTile(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.south_rounded, size: 14, color: accent),
                              const Gap(3),
                              Text(t.avpn.superLightDown, style: _Bento.label(muted)),
                            ],
                          ),
                          const Gap(8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: down.$1),
                                  TextSpan(text: ' ${down.$2}', style: _Bento.label(muted)),
                                ],
                              ),
                              style: _Bento.figure(26, scheme.onSurface),
                            ),
                          ),
                          const Gap(4),
                          Text('↑ ${up.$1} ${up.$2}', style: _Bento.label(muted)),
                        ],
                      ),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _bentoTile(
                      context,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VPN', style: _Bento.label(_Bento.orangeInk)),
                          const Gap(8),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: connected ? '$share' : '—'),
                                if (connected) TextSpan(text: '%', style: _Bento.figure(14, _Bento.orangeInk)),
                              ],
                            ),
                            style: _Bento.figure(30, ink),
                          ),
                          const Gap(4),
                          Text(
                            '${vpn.$1} ${vpn.$2} · ${direct.$1} ${direct.$2}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _Bento.label(_Bento.orangeInk),
                          ),
                        ],
                      ),
                      colour: _Bento.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bento's sites: one tile, the delay check over a grid of small inner tiles (the name, the delay in heavy figures;
/// a slow one in its colour).
class _SiteBento extends ConsumerWidget {
  const _SiteBento();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) return const SizedBox.shrink();
    final anyCountry = entries.any((e) => e.country.isNotEmpty);
    Widget cell(_SiteEntry e, bool fill) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _Bento.inner(dark), borderRadius: BorderRadius.circular(16)),
      // the fill as in Contrast's tiles: the water rises from the bottom, the faster the site answers the higher, in
      // the delay's colour (green, amber, red)
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _Water(level: e.level, colour: e.colour, dark: dark),
            ),
          ),
          Padding(
            // given room the tile is stretched to the height it is handed, so its padding gives a little
            padding: fill ? const EdgeInsets.fromLTRB(10, 4, 8, 4) : const EdgeInsets.fromLTRB(10, 8, 8, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _Bento.label(scheme.onSurfaceVariant),
                ),
                // the country, between the name and the delay, where the site's server is in another country than the
                // main one (the line is kept in every cell when any has one: the cells of a row stay equal)
                if (anyCountry)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      e.country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _Bento.label(
                        scheme.onSurface,
                      ).copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                  ),
                // given room (the page is tall) the delay sits at the bottom of its tile
                if (fill) const Spacer() else const Gap(3),
                Text(
                  !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
                  style: _Bento.figure(20, e.colour == _SiteTiles._good ? scheme.onSurface : e.colour),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        // a tight height: the page has room to spare, the rows of tiles take it
        final fill = box.hasTightHeight;
        return _bentoTile(
          context,
          Column(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SitesHeader(),
              for (var start = 0; start < entries.length; start += 3) ...[
                if (start > 0) const Gap(6),
                if (fill)
                  Expanded(child: _siteRow(entries, start, cell, fill))
                else
                  _siteRow(entries, start, cell, fill),
              ],
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        );
      },
    );
  }

  Widget _siteRow(List<_SiteEntry> entries, int start, Widget Function(_SiteEntry, bool) cell, bool fill) => Row(
    crossAxisAlignment: fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
    children: [
      for (var k = 0; k < 3; k++) ...[
        if (k > 0) const Gap(6),
        Expanded(child: start + k < entries.length ? cell(entries[start + k], fill) : const SizedBox.shrink()),
      ],
    ],
  );
}

/// Bento's server: a tile with the server's label, the flag and the country, the ping in heavy figures.
Widget _bentoServerRow(
  BuildContext context, {
  required String? flag,
  required bool group,
  required String name,
  required String caption,
  required String ms,
  required bool measured,
  required bool selected,
  required bool testing,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final accent = theme.araAccent;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_Bento.radius),
        onTap: onTap,
        child: _bentoTile(
          context,
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _Bento.label(scheme.onSurfaceVariant),
                    ),
                    const Gap(3),
                    Row(
                      children: [
                        if (group)
                          Icon(Icons.auto_awesome_rounded, size: 17, color: accent)
                        else
                          Text(
                            flag ?? '🌐',
                            style: const TextStyle(fontSize: 17, height: 1, fontFamilyFallback: ['Emoji']),
                          ),
                        const Gap(6),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _Bento.figure(16, scheme.onSurface).copyWith(letterSpacing: -.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),
              if (testing)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
              else
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: ms),
                      if (measured) TextSpan(text: ' ms', style: _Bento.label(scheme.onSurfaceVariant)),
                    ],
                  ),
                  style: _Bento.figure(selected ? 26 : 20, scheme.onSurface),
                ),
              const Gap(10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                child: Icon(Icons.north_east_rounded, size: 15, color: _onAccent(accent)),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
        ),
      ),
    ),
  );
}

/// Bento's connections: a tile with the count in heavy figures and the VPN's share as a split line.
Widget _bentoConnections(
  BuildContext context,
  Translations t, {
  required int open,
  required int vpn,
  required int direct,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final accent = theme.araAccent;
  final total = vpn + direct;
  final left = ((total == 0 ? 0.0 : vpn / total) * 1000).round().clamp(30, 970);
  return _bentoTile(
    context,
    Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.avpn.connBlockTitle, style: _Bento.label(scheme.onSurfaceVariant)),
            const Gap(4),
            Text('$open', style: _Bento.figure(30, scheme.onSurface)),
          ],
        ),
        const Gap(18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: left,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                    const Gap(4),
                    Expanded(
                      flex: 1000 - left,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Text('$vpn ${t.avpn.connViaVpn}', style: _Bento.label(scheme.onSurface)),
                  const Spacer(),
                  Text('$direct ${t.avpn.connDirect}', style: _Bento.label(scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
  );
}

// ───────────────────────────── Dots ─────────────────────────────

/// Dots: paper with a fine dot grid, figures drawn as a matrix of dots, a monospaced face, black and grey with one red.
abstract final class _Dots {
  static Color paper(bool dark) => dark ? const Color(0xFF151515) : const Color(0xFFEAE9E5);
  static Color ink(bool dark) => dark ? const Color(0xFFEDEDE8) : const Color(0xFF111111);
  static Color grid(bool dark) => dark ? const Color(0xFF2C2C2C) : const Color(0xFFCDCCC7);
  static Color soft(bool dark) => dark ? const Color(0xFF9A9A95) : const Color(0xFF6A6A66);

  /// the style's one colour (the owner's choice in Settings → Themes; red until picked)
  static Color get red => dotsAccentNow;

  static TextStyle mono(double size, Color colour, {FontWeight weight = FontWeight.w500, double spacing = 1.4}) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: 1.25,
        color: colour,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// A sheet of the dotted paper with [child] on it.
Widget _dotPaper(BuildContext context, Widget child, {EdgeInsets padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _Dots.paper(dark),
      borderRadius: BorderRadius.circular(dotsRadius),
      border: Border.all(color: _Dots.ink(dark).withValues(alpha: .28)),
    ),
    child: child,
  );
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.paper, required this.dot});

  final Color paper;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    // the whole screen's dots in one call (thousands of separate circles were slow to draw)
    canvas.drawPoints(
      ui.PointMode.points,
      [
        for (var y = 6.0; y < size.height; y += 10)
          for (var x = 6.0; x < size.width; x += 10) Offset(x, y),
      ],
      Paint()
        ..color = dot
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.paper != paper || old.dot != dot;
}

/// The ink that reads on the accent (Bento's hero tile, its chips and its connect button): dark on a light accent,
/// white on a dark one (the OLED palette's accent is black, and the dark ink vanished on it)
Color _onAccent(Color accent) => accent.computeLuminance() > .4 ? ContrastPalette.ink : Colors.white;

/// The "clear" sign of the stats pages: in Dots a small bin of dots (a lid and a body, the body's sides lit), else the
/// sweep sign.
Widget clearIcon({Color? color, double size = 24}) {
  if (homeLookNow != HomeLayout.dots) return Icon(Icons.delete_sweep_rounded, color: color, size: size);
  return Builder(
    builder: (context) => CustomPaint(
      size: Size.square(size),
      painter: _DotsBinPainter(
        color ?? IconTheme.of(context).color ?? _Dots.ink(Theme.of(context).brightness == Brightness.dark),
      ),
    ),
  );
}

class _DotsBinPainter extends CustomPainter {
  _DotsBinPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 8;
    final lit = Paint()..color = colour;
    final dim = Paint()..color = colour.withValues(alpha: .3);
    final r = step * .38;
    Offset at(num i, num j) => Offset((i + .5) * step, (j + .5) * step);
    // the handle and the lid
    for (final i in const [3, 4]) {
      canvas.drawCircle(at(i, 0), r, lit);
    }
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(at(i, 1.6), r, lit);
    }
    // the body: its sides and bottom lit, the middle faint
    for (var j = 3; j < 8; j++) {
      for (var i = 1; i <= 6; i++) {
        final edge = i == 1 || i == 6 || j == 7;
        canvas.drawCircle(at(i, j), edge ? r : r * .55, edge ? lit : dim);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsBinPainter old) => old.colour != colour;
}

/// A shield of dots (the Dots look's shield): a field of dots in the shape of a shield, its edge dots bolder and the
/// inner ones fainter; [hollow]: only its edge (a shield with nothing in it: traffic that goes without the VPN).
void paintDotShield(Canvas canvas, Rect box, Color colour, {bool hollow = false}) {
  const cols = 7;
  const rows = 8;
  final sx = box.width / cols;
  final sy = box.height / rows;
  bool inside(int i, int j) {
    if (i < 0 || i >= cols || j < 0 || j >= rows) return false;
    final u = ((i + .5) / cols) * 2 - 1;
    final v = (j + .5) / rows;
    final w = v < .5 ? 1.0 : math.sqrt(math.max(0.0, 1 - math.pow((v - .5) / .5, 2)));
    return u.abs() <= w * .95;
  }

  final r = math.min(sx, sy) * .42;
  final bold = Paint()..color = colour;
  final soft = Paint()..color = colour.withValues(alpha: .5);
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      if (!inside(i, j)) continue;
      final edge = !inside(i - 1, j) || !inside(i + 1, j) || !inside(i, j - 1) || !inside(i, j + 1);
      if (hollow && !edge) continue;
      canvas.drawCircle(
        Offset(box.left + (i + .5) * sx, box.top + (j + .5) * sy),
        edge ? r : r * .55,
        edge ? bold : soft,
      );
    }
  }
}

class _DotShieldPainter extends CustomPainter {
  _DotShieldPainter(this.colour, this.hollow);

  final Color colour;
  final bool hollow;

  @override
  void paint(Canvas canvas, Size size) => paintDotShield(canvas, Offset.zero & size, colour, hollow: hollow);

  @override
  bool shouldRepaint(_DotShieldPainter old) => old.colour != colour || old.hollow != hollow;
}

/// The shield sign in the Dots look (of dots), as an icon [size] high.
Widget shieldSign({Color? color, double size = 24, bool hollow = false}) => Builder(
  builder: (context) => CustomPaint(
    size: Size(size * .88, size),
    painter: _DotShieldPainter(color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface, hollow),
  ),
);

/// A number drawn as a 5×7 matrix of dots for each figure: the lit dots in the ink, the rest faint.
class _DotNumber extends StatelessWidget {
  const _DotNumber(this.text, {required this.cell, required this.colour, required this.faint});

  final String text;
  final double cell;
  final Color colour;
  final Color faint;

  static const _glyphs = {
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    '—': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
    '.': ['0', '0', '0', '0', '0', '0', '1'],
    '%': ['11001', '11010', '00010', '00100', '01000', '01011', '10011'],
  };

  /// the columns a glyph takes with the gap after it
  static int advance(String c) => _glyphs[c]![0].length + 1;

  @override
  Widget build(BuildContext context) {
    final chars = text.split('').where(_glyphs.containsKey).toList();
    final width = chars.isEmpty ? 0.0 : (chars.fold<int>(0, (n, c) => n + advance(c)) - 1) * cell;
    return CustomPaint(
      size: Size(width, 7 * cell),
      painter: _DotNumberPainter(chars: chars, cell: cell, colour: colour, faint: faint),
    );
  }
}

class _DotNumberPainter extends CustomPainter {
  _DotNumberPainter({required this.chars, required this.cell, required this.colour, required this.faint});

  final List<String> chars;
  final double cell;
  final Color colour;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = colour;
    final off = Paint()..color = faint;
    final r = cell * .42;
    var column = 0;
    for (final c in chars) {
      final rows = _DotNumber._glyphs[c]!;
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < rows[y].length; x++) {
          final centre = Offset((column + x + .5) * cell, (y + .5) * cell);
          canvas.drawCircle(centre, rows[y][x] == '1' ? r : r * .45, rows[y][x] == '1' ? on : off);
        }
      }
      column += _DotNumber.advance(c);
    }
  }

  @override
  bool shouldRepaint(_DotNumberPainter old) =>
      old.chars.join() != chars.join() || old.cell != cell || old.colour != colour || old.faint != faint;
}

/// Ten small dots, [lit] of them in [colour] and the rest faint: the dock's loss and servers answering
Widget _dotMeter(BuildContext context, int lit, Color colour) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 10; i++)
        Container(
          width: 4.5,
          height: 4.5,
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < lit ? colour : _Dots.ink(dark).withValues(alpha: .18),
          ),
        ),
    ],
  );
}

/// A line of the dotted sheet: a label in small capitals on the left, the value on the right.
Widget _dotRow(BuildContext context, String label, String value, {Color? valueColour, String? country}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final row = Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _Dots.mono(11, _Dots.soft(dark)),
        ),
      ),
      const Gap(8),
      // the sites' lines: the country in a column of its own between the name and the delay, where the site's server
      // is in another country than the main one (blank where it is the same), the delay in a column too
      if (country != null) ...[
        SizedBox(
          width: 112,
          child: Text(
            country.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _Dots.mono(10, _Dots.ink(dark), spacing: 1),
          ),
        ),
        SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: _Dots.mono(15, valueColour ?? _Dots.ink(dark), weight: FontWeight.w800, spacing: .5),
            ),
          ),
        ),
      ] else
        Text(value, style: _Dots.mono(15, valueColour ?? _Dots.ink(dark), weight: FontWeight.w800, spacing: .5)),
    ],
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    // a site in another country than the main one: a faint plate under the whole line (name, country, delay)
    child: country != null && country.isNotEmpty
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -6,
                right: -6,
                top: -2,
                bottom: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _Dots.ink(dark).withValues(alpha: dark ? .09 : .07),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              row,
            ],
          )
        : row,
  );
}

Widget _dotRule(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Container(height: 1, color: _Dots.ink(dark).withValues(alpha: .7)),
  );
}

class _DotsStats extends HookConsumerWidget {
  const _DotsStats({
    required this.connected,
    required this.timeText,
    required this.ping,
    required this.loss,
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    this.slim = false,
  });

  final bool connected;
  final String timeText;
  final int? ping;

  /// the share of packets lost, in percent
  final double loss;
  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final bool slim;

  /// the ping this slow or the loss this heavy turns the figures to the accent
  static const alertPing = 300;
  static const alertLoss = 15.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = _Dots.ink(dark);
    final live = ref.watch(connectionQualityProvider);
    final kept = useRef<List<int?>>(const []);
    if (connected && live.isNotEmpty) kept.value = live;
    final samples = connected ? live : kept.value;
    final answers = [
      for (final s in samples)
        if (s != null) s,
    ];
    final average = answers.isEmpty ? null : (answers.reduce((a, b) => a + b) / answers.length).round();
    final bars = samples.length > 24 ? samples.sublist(samples.length - 24) : samples;
    // from zero to a round number over the highest answer (at least 200 ms), marked at 100, 200, 400: a ping of 40 and
    // one of 100 stand at different heights (the bars were scaled to the highest of them, so any ping filled them)
    // capped at 400 ms: a few timeouts (1500 ms) must not squash every normal answer into a stripe; they run off the top
    final scale = math.min(_niceMax(answers.isEmpty ? 1 : answers.reduce(math.max).toDouble(), least: 200), 400.0);
    final style = ref.watch(Preferences.pingGraph);
    return _dotPaper(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('PING / MS', style: _Dots.mono(11, _Dots.soft(dark), spacing: 2.4)),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? _Dots.red : _Dots.soft(dark)),
              ),
              const Gap(6),
              Text(timeText, style: _Dots.mono(12, ink, weight: FontWeight.w800)),
            ],
          ),
          Gap(slim ? 6 : 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: slim ? null : () => unawaited(_pickPingGraph(context, ref, style)),
            child: Center(
              child: _DotNumber(
                connected && ping != null ? '$ping' : '—',
                cell: slim ? 6 : 10,
                // the ordinary colour; the accent when the ping is very high or the loss is heavy
                colour: connected && ((ping ?? 0) >= _DotsStats.alertPing || loss >= _DotsStats.alertLoss)
                    ? _Dots.red
                    : ink,
                faint: _Dots.grid(dark),
              ),
            ),
          ),
          const Gap(8),
          Center(
            child: Text(
              average == null ? ' ' : '${t.avpn.pingAverage.toUpperCase()} $average',
              style: _Dots.mono(11, _Dots.soft(dark), spacing: 3),
            ),
          ),
          if (!slim) ...[
            const Gap(10),
            if (style == PingGraph.bars)
              SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PingGridPainter(
                          scale: scale,
                          line: ink.withValues(alpha: .22),
                          text: _Dots.soft(dark),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (i, s) in bars.indexed) ...[
                              if (i > 0) const Gap(3),
                              Expanded(
                                child: FractionallySizedBox(
                                  heightFactor: s == null ? 1 : (s / scale).clamp(.04, 1.0),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      // a lost probe or a slow answer (250 ms and over) in red
                                      color: s == null || s >= 250 ? _Dots.red : ink,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: switch (style) {
                  PingGraph.equalizer => 58.0,
                  PingGraph.ruler => 40.0,
                  PingGraph.trace => 58.0,
                  _ => 52.0,
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PingDotsPainter(
                    style: style,
                    samples: style == PingGraph.heat ? samples : bars,
                    scale: scale,
                    ping: connected ? ping : null,
                    ink: ink,
                    accent: _Dots.red,
                    faint: _Dots.grid(dark),
                    text: _Dots.soft(dark),
                  ),
                ),
              ),
              if (style == PingGraph.ruler && answers.isNotEmpty) ...[
                const Gap(6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MIN ${answers.reduce(math.min)}', style: _Dots.mono(10, _Dots.soft(dark), spacing: 1.5)),
                    Text(
                      'MAX ${answers.reduce(math.max)}',
                      style: _Dots.mono(
                        10,
                        answers.reduce(math.max) >= _DotsStats.alertPing ? _Dots.red : _Dots.soft(dark),
                        spacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            _dotRule(context),
            // the rows open the traffic (the big ping picks how the answers are drawn)
            for (final row in [
              ('↓ ${t.avpn.superLightDown}', '${down.$1} ${down.$2}'),
              ('↑ ${t.avpn.superLightUp}', '${up.$1} ${up.$2}'),
              ('VPN / ${t.avpn.connDirect}', '${vpn.$1} / ${direct.$1} ${direct.$2}'),
            ])
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.goNamed('traffic'),
                child: _dotRow(context, row.$1, row.$2),
              ),
          ],
        ],
      ),
    );
  }
}

/// The menu of the ways the ping block draws the answers.
Future<void> _pickPingGraph(BuildContext context, WidgetRef ref, PingGraph now) {
  final ru = ref.read(translationsProvider).requireValue.$meta.locale.languageCode == 'ru';
  return showDialog<void>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(ru ? 'Вид задержки' : 'Ping view'),
      children: [
        for (final g in PingGraph.values)
          ListTile(
            dense: true,
            title: Text(ru ? g.ru : g.en),
            trailing: g == now ? const Icon(Icons.check_rounded) : null,
            onTap: () {
              unawaited(ref.read(Preferences.pingGraph.notifier).update(g));
              Navigator.of(dialog).pop();
            },
          ),
      ],
    ),
  );
}

/// The history of the answers in dots: an equalizer, a ruler with a marker, a dotted trace, a grid.
class _PingDotsPainter extends CustomPainter {
  _PingDotsPainter({
    required this.style,
    required this.samples,
    required this.scale,
    required this.ping,
    required this.ink,
    required this.accent,
    required this.faint,
    required this.text,
  });

  final PingGraph style;
  final List<int?> samples;

  /// the top of the equalizer and of the trace, as the bars have it (the ruler's is always 400)
  final double scale;
  final int? ping;
  final Color ink;
  final Color accent;
  final Color faint;
  final Color text;

  static const _top = 400.0;

  void _dot(Canvas canvas, Offset at, double r, Color c) => canvas.drawCircle(at, r, Paint()..color = c);

  bool _slow(int? s) => s == null || s >= 250;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case PingGraph.equalizer:
        const n = 24;
        const rows = 7;
        final shown = samples.length > n ? samples.sublist(samples.length - n) : samples;
        final gw = size.width / n;
        final rh = (size.height - 6) / (rows - 1);
        for (var i = 0; i < n; i++) {
          final has = i < shown.length;
          final s = has ? shown[i] : null;
          final lit = !has ? 0 : (s == null ? rows : (s / (scale / rows)).round().clamp(1, rows));
          for (var r = 0; r < rows; r++) {
            final at = Offset(gw * i + gw / 2, size.height - 3 - r * rh);
            if (r < lit) {
              _dot(canvas, at, 2.4, _slow(s) ? accent : ink);
            } else {
              _dot(canvas, at, 1.0, faint);
            }
          }
        }
      case PingGraph.ruler:
        const n = 48;
        final gw = size.width / n;
        const y = 16.0;
        for (var k = 0; k < n; k++) {
          final v = k / (n - 1) * _top;
          final on = ping != null && v <= ping!;
          final hot = v >= 300;
          _dot(
            canvas,
            Offset(gw * k + gw / 2, y),
            on ? 3 : 1.4,
            on ? (hot ? accent : ink) : (hot ? accent.withValues(alpha: .35) : faint),
          );
        }
        if (ping != null) {
          final mx = gw / 2 + (size.width - gw) * (ping!.clamp(0, 400) / _top);
          canvas.drawPath(
            Path()
              ..moveTo(mx, y - 6)
              ..lineTo(mx - 4.5, y - 14)
              ..lineTo(mx + 4.5, y - 14)
              ..close(),
            Paint()..color = ping! >= 300 ? accent : ink,
          );
        }
        for (final v in const [0, 100, 200, 300, 400]) {
          final tp = TextPainter(
            text: TextSpan(
              text: v == 400 ? '400+' : '$v',
              style: _Dots.mono(8.5, text, weight: FontWeight.w700, spacing: 0),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final x = gw / 2 + (size.width - gw) * (v / _top);
          tp.paint(canvas, Offset((x - tp.width / 2).clamp(0, size.width - tp.width), y + 11));
        }
      case PingGraph.trace:
        const n = 24;
        final shown = samples.length > n ? samples.sublist(samples.length - n) : samples;
        if (shown.isEmpty) return;
        const top = 6.0;
        final base = size.height - 4;
        Offset at(int i) {
          final v = (shown[i] ?? scale).clamp(0, scale) / scale;
          return Offset(size.width * i / (n - 1), base - (base - top) * v);
        }

        canvas.drawLine(
          Offset(0, base - (base - top) * .25),
          Offset(size.width, base - (base - top) * .25),
          Paint()
            ..color = faint
            ..strokeWidth = 1,
        );
        for (var i = 0; i < shown.length - 1; i++) {
          final a = at(i);
          final b = at(i + 1);
          final steps = math.max(2, ((b - a).distance / 5).floor());
          for (var k = 0; k < steps; k++) {
            _dot(canvas, Offset.lerp(a, b, k / steps)!, 1.4, _slow(shown[i]) ? accent : ink);
          }
        }
        for (var i = 0; i < shown.length; i++) {
          _dot(canvas, at(i), _slow(shown[i]) ? 3 : 2.2, _slow(shown[i]) ? accent : ink);
        }
        canvas.drawCircle(
          at(shown.length - 1),
          7,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case PingGraph.heat:
        const cols = 30;
        const rows = 4;
        final shown = samples.length > cols * rows ? samples.sublist(samples.length - cols * rows) : samples;
        final gw = size.width / cols;
        final rh = (size.height - 6) / (rows - 1);
        // the newest at the bottom right: the grid is filled from the end
        final start = cols * rows - shown.length;
        for (var k = 0; k < cols * rows; k++) {
          final at = Offset(gw * (k % cols) + gw / 2, 3 + rh * (k ~/ cols));
          final i = k - start;
          if (i < 0) {
            _dot(canvas, at, 1.0, faint);
            continue;
          }
          final s = shown[i];
          if (_slow(s)) {
            _dot(canvas, at, 3, accent);
          } else {
            // the slower, the brighter and bigger
            final t = (s! / 150).clamp(0.0, 1.0);
            _dot(canvas, at, 1.6 + t, Color.lerp(faint, ink, .35 + .65 * t)!);
          }
        }
      case PingGraph.bars:
        break;
    }
  }

  @override
  bool shouldRepaint(_PingDotsPainter old) =>
      old.style != style ||
      old.ping != ping ||
      old.scale != scale ||
      old.ink != ink ||
      old.accent != accent ||
      !listEquals(old.samples, samples);
}

/// The marks behind the ping bars: a faint line at 100, 200, 400 ms (as far as the scale goes), its figure at the right.
class _PingGridPainter extends CustomPainter {
  _PingGridPainter({required this.scale, required this.line, required this.text});

  final double scale;
  final Color line;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = size.width - 28;
    for (final mark in const [100, 200, 400, 800]) {
      if (mark > scale) break;
      final y = size.height * (1 - mark / scale);
      canvas.drawLine(
        Offset(0, y),
        Offset(plot, y),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '$mark',
          style: _Dots.mono(8.5, text, weight: FontWeight.w700, spacing: 0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(plot + 5, (y - label.height / 2).clamp(0, size.height - label.height)));
    }
  }

  @override
  bool shouldRepaint(_PingGridPainter old) => old.scale != scale || old.line != line || old.text != text;
}

/// Dots' sites: a line for each, the name on the left and the delay on the right, red when it is slow.
class _SiteDots extends HookConsumerWidget {
  const _SiteDots();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // the delays are asked again every minute while the VPN is up and the block is on the screen (quietly: no ring)
    final up = ref.watch(connectionNotifierProvider.select((v) => v.valueOrNull?.isConnected ?? false));
    useEffect(() {
      if (!up) return null;
      final timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(ref.read(siteLatencyProvider.notifier).test(quiet: true)),
      );
      return timer.cancel;
    }, [up]);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) return const SizedBox.shrink();
    final style = ref.watch(Preferences.siteGraph);
    final ink = _Dots.ink(dark);
    final soft = _Dots.soft(dark);
    final faint = _Dots.grid(dark);
    return _dotPaper(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SitesHeader(),
          switch (style) {
            SiteGraph.list => Column(
              children: [
                for (final e in entries)
                  _dotRow(
                    context,
                    e.name,
                    !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
                    valueColour: e.measured && e.colour != _SiteTiles._good ? _Dots.red : null,
                    country: e.country,
                  ),
              ],
            ),
            SiteGraph.scales => Column(
              children: [
                for (final e in entries)
                  _sitePlate(
                    dark,
                    e,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _flaggedText(e, e.name.toUpperCase(), _Dots.mono(11, soft)),
                              ),
                            ),
                            _siteFigure(e, ink),
                          ],
                        ),
                        const Gap(3),
                        SizedBox(
                          height: 8,
                          child: CustomPaint(
                            painter: _SitePainter(
                              kind: SiteGraph.scales,
                              ms: e.measured ? e.ms : null,
                              ink: ink,
                              accent: _Dots.red,
                              faint: faint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SiteGraph.digits => Column(
              children: [
                for (var i = 0; i < entries.length; i += 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        for (var k = i; k < i + 3; k++)
                          Expanded(
                            child: k < entries.length
                                ? _flagPlate(dark, entries[k], _siteDigits(entries[k], ink, soft, faint))
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            SiteGraph.columns => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  for (final e in entries)
                    Expanded(
                      child: _flagPlate(
                        dark,
                        e,
                        Column(
                          children: [
                            SizedBox(
                              height: 7 * 14.0,
                              width: 16,
                              child: CustomPaint(
                                painter: _SitePainter(
                                  kind: SiteGraph.columns,
                                  ms: e.measured ? e.ms : null,
                                  ink: ink,
                                  accent: _Dots.red,
                                  faint: faint,
                                ),
                              ),
                            ),
                            const Gap(6),
                            // a site with a server of its own: its flag over the name (the line is kept for all)
                            if (entries.any((x) => x.flag.isNotEmpty))
                              SizedBox(
                                height: 14,
                                child: e.flag.isEmpty ? null : Center(child: _flagMark(e.flag, width: 18)),
                              ),
                            // the same gap between the flag, the name and the figure
                            const Gap(5),
                            // the whole name, as small as it takes to fit its column
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: SizedBox(
                                height: 13,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    e.name.toUpperCase(),
                                    maxLines: 1,
                                    style: _Dots.mono(9, soft, spacing: 0),
                                  ),
                                ),
                              ),
                            ),
                            const Gap(5),
                            _siteFigure(e, ink, size: 11, align: Alignment.center),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SiteGraph.lanes => Column(
              children: [
                for (final e in entries)
                  _sitePlate(
                    dark,
                    e,
                    SizedBox(
                      height: 22,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _flaggedText(e, _shortName(e.name), _Dots.mono(10, soft, spacing: .4)),
                            ),
                          ),
                          Expanded(
                            child: CustomPaint(
                              size: const Size.fromHeight(22),
                              painter: _SitePainter(
                                kind: SiteGraph.lanes,
                                ms: e.measured ? e.ms : null,
                                ink: ink,
                                accent: _Dots.red,
                                faint: faint,
                              ),
                            ),
                          ),
                          SizedBox(width: 52, child: _siteFigure(e, ink)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          },
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    );
  }
}

/// A country's flag as a small grid of square pixels (Dots): the stripes, crosses and discs of the commonest countries;
/// any other country keeps its emoji.
Widget _flagMark(String? flag, {double width = 26}) {
  if (flag == null || flag.isEmpty) {
    return Text(
      '🌐',
      style: TextStyle(fontSize: width * .66, height: 1, fontFamilyFallback: const ['Emoji']),
    );
  }
  return _FlagMark(flag, width);
}

/// A flag in pixels: the pattern drawn by hand when there is one, else the country's emoji of the bundled font turned
/// into the same grid (drawn to a picture once, each cell the average of its block), so every country has a pixel flag.
class _FlagMark extends StatefulWidget {
  const _FlagMark(this.flag, this.width);

  final String flag;
  final double width;

  @override
  State<_FlagMark> createState() => _FlagMarkState();
}

class _FlagMarkState extends State<_FlagMark> {
  List<List<Color>>? _grid;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_FlagMark old) {
    super.didUpdateWidget(old);
    if (old.flag != widget.flag) _resolve();
  }

  void _resolve() {
    final flag = widget.flag;
    _grid = _PixelFlag.of(flag) ?? _PixelFlag.pixelated[flag];
    _failed = false;
    if (_grid != null) return;
    unawaited(
      _PixelFlag.pixelate(flag).then((grid) {
        if (!mounted || widget.flag != flag) return;
        setState(() {
          _grid = grid;
          _failed = grid == null;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    if (grid != null) {
      return CustomPaint(size: Size(widget.width, widget.width * 2 / 3), painter: _PixelFlag(grid));
    }
    if (_failed) {
      return Text(
        widget.flag,
        style: TextStyle(fontSize: widget.width * .66, height: 1, fontFamilyFallback: const ['Emoji']),
      );
    }
    // while the picture is made: the room of the flag
    return SizedBox(width: widget.width, height: widget.width * 2 / 3);
  }
}

/// A site's name with its flag before it (when its server is in another country), the name cut by an ellipsis.
Widget _flaggedText(_SiteEntry e, String text, TextStyle style, {String suffix = ''}) {
  final label = Text('$text$suffix', maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  if (e.flag.isEmpty) return label;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _flagMark(e.flag, width: 15),
      const Gap(5),
      Flexible(child: label),
    ],
  );
}

class _PixelFlag extends CustomPainter {
  _PixelFlag(this.grid);

  final List<List<Color>> grid;

  static const cols = 12;
  static const rows = 8;

  static const _k = Color(0xFF151515);
  static const _w = Color(0xFFF2F2EE);
  static const _r = Color(0xFFD52B1E);
  static const _bl = Color(0xFF0057B8);
  static const _y = Color(0xFFFFD500);
  static const _g = Color(0xFF1FA34A);
  static const _o = Color(0xFFFF883E);
  static const _mar = Color(0xFF9E3039);
  static const _sky = Color(0xFF00AFCA);

  static Color Function(int, int) _hs(List<(Color, int)> parts) {
    final rowsOf = [
      for (final (c, n) in parts)
        for (var i = 0; i < n; i++) c,
    ];
    return (x, y) => rowsOf[y];
  }

  static Color Function(int, int) _vs(Color a, Color b, Color c) =>
      (x, y) => x < 4 ? a : (x < 8 ? b : c);

  static Color Function(int, int) _cross(Color bg, Color cross) =>
      (x, y) => (x == 3 || x == 4 || y == 3 || y == 4) ? cross : bg;

  static double _dist(int x, int y) => math.sqrt(math.pow(x - 5.5, 2) + math.pow(y - 3.5, 2));

  static final Map<String, Color Function(int, int)> _flags = {
    'DE': _hs([(_k, 3), (_r, 2), (_y, 3)]),
    'NL': _hs([(_r, 3), (_w, 2), (_bl, 3)]),
    'PL': _hs([(_w, 4), (_r, 4)]),
    'LV': _hs([(_mar, 3), (_w, 2), (_mar, 3)]),
    'LT': _hs([(_y, 3), (_g, 2), (_r, 3)]),
    'EE': _hs([(_bl, 3), (_k, 2), (_w, 3)]),
    'RU': _hs([(_w, 3), (_bl, 2), (_r, 3)]),
    'UA': _hs([(_bl, 4), (_y, 4)]),
    'AT': _hs([(_r, 3), (_w, 2), (_r, 3)]),
    'HU': _hs([(_r, 3), (_w, 2), (_g, 3)]),
    'BG': _hs([(_w, 3), (_g, 2), (_r, 3)]),
    'ES': _hs([(_r, 2), (_y, 4), (_r, 2)]),
    'SG': _hs([(_r, 4), (_w, 4)]),
    'FR': _vs(_bl, _w, _r),
    'IT': _vs(_g, _w, _r),
    'BE': _vs(_k, _y, _r),
    'RO': _vs(_bl, _y, _r),
    'IE': _vs(_g, _w, _o),
    'FI': _cross(_w, _bl),
    'SE': _cross(_bl, _y),
    'DK': _cross(_r, _w),
    'NO': _cross(_r, _w),
    'CH': (x, y) => ((x >= 5 && x <= 6 && y >= 1 && y <= 6) || (y >= 3 && y <= 4 && x >= 3 && x <= 8)) ? _w : _r,
    'GB': (x, y) =>
        (x >= 5 && x <= 6) || (y >= 3 && y <= 4) ? _r : ((x >= 4 && x <= 7) || (y >= 2 && y <= 5) ? _w : _bl),
    'US': (x, y) => (x < 5 && y < 4) ? _bl : (y.isEven ? _r : _w),
    'TR': (x, y) => _dist(x, y) < 1.9 ? _w : _r,
    'JP': (x, y) => _dist(x, y) < 2.3 ? _r : _w,
    'KZ': (x, y) => _dist(x, y) < 2.0 ? _y : _sky,
    'CZ': (x, y) => (x <= 4 && (y - 3.5).abs() <= (4.6 - x) * .85) ? _bl : (y < 4 ? _w : _r),
    'PT': (x, y) => x < 5 ? _g : _r,
    'CA': (x, y) => (x >= 5 && x <= 6 && y >= 2 && y <= 5) ? _r : ((x < 3 || x >= 9) ? _r : _w),
  };

  static final _cache = <String, List<List<Color>>?>{};

  /// the flags made from the emoji, by the emoji (kept: a flag is drawn once)
  static final pixelated = <String, List<List<Color>>?>{};
  static final _making = <String, Future<List<List<Color>>?>>{};

  /// The country's emoji drawn to a picture and cut to the grid; null when the font has no picture for it.
  static Future<List<List<Color>>?> pixelate(String flag) => _making.putIfAbsent(flag, () async {
    try {
      final painter = TextPainter(
        text: TextSpan(
          text: flag,
          style: const TextStyle(fontSize: 120, height: 1, fontFamily: 'Emoji', color: Color(0xFF000000)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = painter.width.ceil();
      final h = painter.height.ceil();
      if (w < 8 || h < 8) return null;
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), Offset.zero);
      final image = await recorder.endRecording().toImage(w, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return null;
      final px = data.buffer.asUint8List();
      // the box the flag takes in the picture
      var x0 = w, y0 = h, x1 = -1, y1 = -1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (px[(y * w + x) * 4 + 3] > 40) {
            if (x < x0) x0 = x;
            if (x > x1) x1 = x;
            if (y < y0) y0 = y;
            if (y > y1) y1 = y;
          }
        }
      }
      if (x1 - x0 < 8 || y1 - y0 < 8) return null;
      final bw = (x1 - x0 + 1) / cols;
      final bh = (y1 - y0 + 1) / rows;
      final grid = <List<Color>>[];
      for (var cy = 0; cy < rows; cy++) {
        final row = <Color>[];
        for (var cx = 0; cx < cols; cx++) {
          var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
          final xa = (x0 + cx * bw).floor(), xb = (x0 + (cx + 1) * bw).ceil();
          final ya = (y0 + cy * bh).floor(), yb = (y0 + (cy + 1) * bh).ceil();
          for (var y = ya; y < yb && y < h; y++) {
            for (var x = xa; x < xb && x < w; x++) {
              final i = (y * w + x) * 4;
              final alpha = px[i + 3] / 255;
              r += px[i] * alpha;
              g += px[i + 1] * alpha;
              b += px[i + 2] * alpha;
              a += alpha;
            }
          }
          row.add(
            a < 1 ? const Color(0xFF808080) : Color.fromARGB(255, (r / a).round(), (g / a).round(), (b / a).round()),
          );
        }
        grid.add(row);
      }
      return pixelated[flag] = grid;
    } catch (_) {
      return null;
    }
  });

  /// the pixels of a flag emoji's country, null when there is no pattern for it
  static List<List<Color>>? of(String flag) => _cache.putIfAbsent(flag, () {
    final letters = flag.runes.where((r) => r >= 0x1F1E6 && r <= 0x1F1FF).toList();
    if (letters.length < 2) return null;
    final code = String.fromCharCodes([letters[0] - 0x1F1E6 + 65, letters[1] - 0x1F1E6 + 65]);
    final cell = _flags[code];
    if (cell == null) return null;
    return [
      for (var y = 0; y < rows; y++) [for (var x = 0; x < cols; x++) cell(x, y)],
    ];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cols;
    final side = cell * .88;
    // a thin frame, so a white stripe does not melt into the paper
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0x66808080)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell + (cell - side) / 2, y * cell + (cell - side) / 2, side, side),
          Paint()..color = grid[y][x],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelFlag old) => !identical(old.grid, grid);
}

/// (the sites with a server of their own are marked by the flag alone, no plate under them)
Widget _flagPlate(bool dark, _SiteEntry e, Widget child) => child;

/// A site's name cut to what fits a narrow column.
String _shortName(String name) {
  final first = name.split(' ').first.toUpperCase();
  return first.length > 7 ? first.substring(0, 7) : first;
}

/// A site's delay in big dots with its name under it (a second and a half is 1.5, in seconds).
Widget _siteDigits(_SiteEntry e, Color ink, Color soft, Color faint) {
  final slow = e.measured && e.colour != _SiteTiles._good;
  final ms = e.ms;
  final text = !e.measured || ms == null ? '—' : (ms >= 1000 ? (ms / 1000).toStringAsFixed(1) : '$ms');
  return Column(
    children: [
      _DotNumber(text, cell: 4.2, colour: slow ? _Dots.red : ink, faint: faint),
      const Gap(5),
      _flaggedText(
        e,
        _shortName(e.name),
        _Dots.mono(9, soft, spacing: .6),
        suffix: ms != null && ms >= 1000 ? ' · С' : '',
      ),
    ],
  );
}

/// The figure of a site's delay, the accent when it is slow.
Widget _siteFigure(_SiteEntry e, Color ink, {double size = 15, Alignment align = Alignment.centerRight}) => Align(
  alignment: align,
  child: Text(
    !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
    style: _Dots.mono(
      size,
      e.measured && e.colour != _SiteTiles._good ? _Dots.red : ink,
      weight: FontWeight.w800,
      spacing: .5,
    ),
  ),
);

/// A line of the sites' block (the flag before the name says that its server is another one).
Widget _sitePlate(bool dark, _SiteEntry e, Widget row) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: row);

/// The dots of a site: a row filled up to the delay (scales), a column of them (columns), a runner on a track (lanes).
class _SitePainter extends CustomPainter {
  _SitePainter({required this.kind, required this.ms, required this.ink, required this.accent, required this.faint});

  final SiteGraph kind;
  final int? ms;
  final Color ink;
  final Color accent;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    void dot(Offset at, double r, Color c) => canvas.drawCircle(at, r, Paint()..color = c);
    final slow = ms != null && ms! >= 240;
    switch (kind) {
      case SiteGraph.columns:
        const rows = 7;
        final lit = ms == null ? 0 : (ms! / (400 / rows)).round().clamp(1, rows);
        final rh = size.height / rows;
        for (var r = 0; r < rows; r++) {
          final at = Offset(size.width / 2, size.height - rh / 2 - r * rh);
          if (r < lit) {
            dot(at, 4.2, slow ? accent : ink);
          } else {
            dot(at, 1.4, faint);
          }
        }
      case SiteGraph.lanes:
        const n = 26;
        final gw = size.width / n;
        final y = size.height / 2;
        for (var k = 0; k < n; k++) {
          dot(Offset(gw * k + gw / 2, y), 1.2, faint);
        }
        if (ms != null) {
          // the faster, the nearer the finish on the right
          final run = 1 - (ms!.clamp(0, 400) / 400);
          final head = size.width * run;
          for (var t = 0; t < 5; t++) {
            dot(Offset(math.max(3.0, head - t * 7), y), 3.4 - t * .5, slow ? accent : ink);
          }
        }
        canvas.drawLine(
          Offset(size.width - 1, y - 8),
          Offset(size.width - 1, y + 8),
          Paint()
            ..color = faint
            ..strokeWidth = 1,
        );
      case _:
        const n = 36;
        final gw = size.width / n;
        for (var k = 0; k < n; k++) {
          final v = k / (n - 1) * 400;
          final on = ms != null && v <= ms!;
          final hot = v >= 240;
          dot(Offset(gw * k + gw / 2, size.height / 2), on ? 2.4 : 1.1, on ? (hot ? accent : ink) : faint);
        }
    }
  }

  @override
  bool shouldRepaint(_SitePainter old) =>
      old.kind != kind || old.ms != ms || old.ink != ink || old.accent != accent || old.faint != faint;
}

/// The menu of the ways the sites' block shows the delays.
Future<void> _pickSiteGraph(BuildContext context, WidgetRef ref, SiteGraph now) {
  final ru = ref.read(translationsProvider).requireValue.$meta.locale.languageCode == 'ru';
  return showDialog<void>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(ru ? 'Вид сайтов' : 'Sites view'),
      children: [
        for (final g in SiteGraph.values)
          ListTile(
            dense: true,
            title: Text(ru ? g.ru : g.en),
            trailing: g == now ? const Icon(Icons.check_rounded) : null,
            onTap: () {
              unawaited(ref.read(Preferences.siteGraph.notifier).update(g));
              Navigator.of(dialog).pop();
            },
          ),
      ],
    ),
  );
}

/// Dots' server: the flag, the protocol in small capitals over the country, the ping in dots.
Widget _dotsServerRow(
  BuildContext context, {
  required String? flag,
  required bool group,
  required String name,
  required String caption,
  required String ms,
  required bool testing,
  required VoidCallback onTap,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ink = _Dots.ink(dark);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _dotPaper(
        context,
        Row(
          children: [
            // the flag as tall as the ping's dots on the right (seven cells of 4)
            if (group)
              SizedBox(width: 42, child: Icon(Icons.auto_awesome_rounded, size: 28, color: ink))
            else
              _flagMark(flag, width: 42),
            const Gap(12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Dots.mono(10, _Dots.soft(dark)),
                  ),
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Dots.mono(15, ink, weight: FontWeight.w800, spacing: 1),
                  ),
                ],
              ),
            ),
            if (testing)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
            else
              _DotNumber(ms == '×' ? '—' : ms, cell: 4, colour: ink, faint: _Dots.grid(dark)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      ),
    ),
  );
}

/// Dots' connections: the count in dots, the VPN and the bypass on a line under it.
Widget _dotsConnections(
  BuildContext context,
  Translations t, {
  required int open,
  required int vpn,
  required int direct,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ink = _Dots.ink(dark);
  return _dotPaper(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(t.avpn.connBlockTitle.toUpperCase(), style: _Dots.mono(11, _Dots.soft(dark)))),
            _DotNumber('$open', cell: 4, colour: ink, faint: _Dots.grid(dark)),
          ],
        ),
        const Gap(6),
        _dotRow(context, 'VPN / ${t.avpn.connDirect}', '$vpn / $direct'),
      ],
    ),
  );
}

/// Bento's connect control: a rounded tile, the accent when connected, the sign and the network in it.
class _BentoButton extends StatelessWidget {
  const _BentoButton({required this.on, required this.busy, required this.size, this.label, this.onTap});

  final bool on;
  final bool busy;
  final double size;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    final lit = on || busy;
    final ink = lit ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: lightDuration(const Duration(milliseconds: 300)),
        width: size * 1.25,
        height: size,
        decoration: BoxDecoration(
          color: lit ? accent.withValues(alpha: busy && !on ? .55 : 1) : _Bento.inner(dark),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new_rounded, size: size * .38, color: ink),
            if (label != null) Text(label!, style: _Bento.label(ink).copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Dots' connect control: a toggle of dots right on the paper, a track of small dots with a square thumb of nine
/// dots; off, the thumb sits at the left, faint; on, at the right, lit in the accent and glowing; connecting, it runs
/// back and forth. The network is named under it.
class _DotsButton extends HookWidget {
  const _DotsButton({required this.on, required this.busy, required this.size, this.label, this.onTap});

  final bool on;
  final bool busy;
  final double size;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final run = useAnimationController(duration: const Duration(milliseconds: 900));
    useEffect(() {
      busy ? run.repeat(reverse: true) : run.stop();
      return null;
    }, [busy]);
    final ink = _Dots.ink(dark);
    final soft = _Dots.soft(dark);
    final width = size * 1.15;
    Widget toggle(double position) => CustomPaint(
      size: Size(width, width * 2 / 10),
      painter: _ToggleDotsPainter(
        position: position,
        thumb: on || busy ? _Dots.red : soft,
        track: ink.withValues(alpha: .2),
        glow: on && !busy,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? AnimatedBuilder(
                    animation: run,
                    builder: (context, _) => toggle(Curves.easeInOut.transform(run.value)),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(end: on ? 1.0 : 0.0),
                    duration: lightDuration(const Duration(milliseconds: 260)),
                    curve: Curves.easeOutCubic,
                    builder: (context, position, _) => toggle(position),
                  ),
            // the line stays when there is no network to name, so the panel does not change height
            const Gap(10),
            Text((label ?? ' ').toUpperCase(), style: _Dots.mono(10, on ? ink : soft, spacing: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _ToggleDotsPainter extends CustomPainter {
  _ToggleDotsPainter({required this.position, required this.thumb, required this.track, required this.glow});

  /// 0 at the left end, 1 at the right
  final double position;
  final Color thumb;
  final Color track;
  final bool glow;

  static const _columns = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / (_columns - 1);
    final row = size.height / 2;
    final small = step * .17;
    final big = step * .4;
    final trackPaint = Paint()..color = track;
    for (var j = 0; j < 3; j++) {
      for (var i = 0; i < _columns; i++) {
        canvas.drawCircle(Offset(i * step, row * j), small, trackPaint);
      }
    }
    final left = position * (_columns - 3);
    final lit = Paint()..color = thumb;
    for (var j = 0; j < 3; j++) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset((left + i) * step, row * j), big, lit);
      }
    }
    if (glow) {
      canvas.drawCircle(
        Offset((left + 1) * step, row),
        step * 1.6,
        Paint()
          ..color = thumb.withValues(alpha: .35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
  }

  @override
  bool shouldRepaint(_ToggleDotsPainter old) =>
      old.position != position || old.thumb != thumb || old.track != track || old.glow != glow;
}

/// A pill over the sites (the delay check, the multi-server switch) in a look that has its own: Bento's solid chip,
/// the accent when on; Dots' square-cornered box in small capitals, filled with the ink when on. Null for the others.
({BoxDecoration box, Color ink, TextStyle? text})? lookPill(HomeLayout look, BuildContext context, {required bool on}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  switch (look) {
    case HomeLayout.bento:
      final ink = on ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface;
      return (
        box: BoxDecoration(color: on ? theme.araAccent : _Bento.inner(dark), borderRadius: BorderRadius.circular(15)),
        ink: ink,
        text: _Bento.label(ink).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
      );
    case HomeLayout.dots:
      final ink = on ? _Dots.paper(dark) : _Dots.ink(dark);
      return (
        box: BoxDecoration(
          color: on ? _Dots.ink(dark) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Dots.ink(dark).withValues(alpha: .35)),
        ),
        ink: ink,
        text: _Dots.mono(11, ink, weight: FontWeight.w700),
      );
    default:
      return null;
  }
}

/// A round button over the page (the modes, the leaf, the cog) in a look that has its own: Bento's solid tile,
/// Dots' outlined circle on the paper. Null for the others.
Widget? lookPlate(HomeLayout look, BuildContext context, Widget child) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (look) {
    HomeLayout.bento => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _Bento.tile(dark), borderRadius: BorderRadius.circular(15)),
        child: IconTheme.merge(
          data: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          child: child,
        ),
      ),
    ),
    HomeLayout.dots => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _Dots.paper(dark),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _Dots.ink(dark).withValues(alpha: .35)),
        ),
        child: child,
      ),
    ),
    _ => null,
  };
}

/// The ping's marks in Dots: the ink for what is well, the style's colour from [slowAt] ms on. The pages' theme keeps the
/// palette's accent (a neon one chosen once); Dots' one colour is the chosen one, so these carry it.
class _DotsLook extends AraLook {
  const _DotsLook({
    required this.ink,
    required this.accent,
    required super.fastPing,
    super.gradient,
    super.onGradient,
    super.border,
    super.data,
    super.dark,
    super.graphDown,
    super.graphUp,
    super.pingOn,
  }) : super(fill: accent);

  final Color ink;
  final Color accent;

  static const slowAt = 300;

  @override
  List<Color> get pingColors => [ink, ink, ink, accent];

  @override
  Color pingColor(int ms, Color muted) => ms >= slowAt ? accent : ink;
}

/// [theme] (a page's) with the Dots look's colours: the chosen accent where the page draws the theme's accent (the VPN
/// routes, the loss, the lit things), the ping's marks in the ink and the accent. Kept for the same input.
ThemeData dotsPageColours(ThemeData theme, DotsAccent accent) {
  final key = (theme, accent);
  final kept = _dotsPageThemes[key];
  if (kept != null) return kept;
  if (_dotsPageThemes.length > 8) _dotsPageThemes.clear();
  final dark = theme.brightness == Brightness.dark;
  final look = theme.extension<AraLook>();
  final result = theme.copyWith(
    extensions: [
      for (final e in theme.extensions.values)
        if (e is! AraLook) e,
      _DotsLook(
        ink: _Dots.ink(dark),
        accent: accent.on(dark: dark),
        fastPing: _Dots.ink(dark),
        gradient: look?.gradient,
        onGradient: look?.onGradient ?? Colors.white,
        border: look?.border,
        data: look?.data,
        dark: dark,
        graphDown: look?.graphDown,
        graphUp: look?.graphUp,
        pingOn: look?.pingOn,
      ),
    ],
  );
  return _dotsPageThemes[key] = result;
}

final _dotsPageThemes = <(ThemeData, DotsAccent), ThemeData>{};

/// The whole screen in a look that has its own (the pages, the menu, the panel): Dots in its monospaced face with the
/// ink for the accent of the text and a square-cornered outlined tab; Bento its heavy round face for the titles and a
/// solid tab in the accent. The others as they are.
ThemeData lookTheme(ThemeData theme, HomeLayout look, [DotsAccent accent = DotsAccent.fallback]) {
  // the same theme for the same input: a new one at every build of the shell (a tab switched) told the whole app its
  // theme had changed and rebuilt it all, a stall of a tenth of a second at each switch
  final key = (theme, look, look == HomeLayout.dots ? accent : DotsAccent.fallback);
  final kept = _lookThemes[key];
  if (kept != null) return kept;
  if (_lookThemes.length > 8) _lookThemes.clear();
  return _lookThemes[key] = _lookTheme(theme, look, accent);
}

final _lookThemes = <(ThemeData, HomeLayout, DotsAccent), ThemeData>{};

ThemeData _lookTheme(ThemeData theme, HomeLayout look, DotsAccent accent) {
  final dark = theme.brightness == Brightness.dark;
  switch (look) {
    case HomeLayout.dots:
      final ink = _Dots.ink(dark);
      final soft = _Dots.soft(dark);
      // the accent is the ink: no palette fill (by day a light palette fills the lit things in its colour)
      final araLook = theme.extension<AraLook>();
      return theme.copyWith(
        extensions: [
          for (final e in theme.extensions.values)
            if (e is! AraLook) e,
          if (araLook != null)
            AraLook(
              gradient: araLook.gradient,
              onGradient: araLook.onGradient,
              fastPing: araLook.fastPing,
              border: araLook.border,
              data: araLook.data,
              dark: araLook.dark,
              graphDown: araLook.graphDown,
              graphUp: araLook.graphUp,
              pingOn: araLook.pingOn,
            ),
        ],
        textTheme: theme.textTheme.apply(fontFamily: 'JetBrains Mono'),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)?.copyWith(
            fontFamily: 'JetBrains Mono',
          ),
        ),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'JetBrains Mono'),
        // (the chosen colour rides in the scheme's tertiary: a change of it is a change of the theme, so the screens
        // drawing it are built again)
        colorScheme: theme.colorScheme.copyWith(
          primary: ink,
          onPrimary: _Dots.paper(dark),
          tertiary: accent.on(dark: dark),
        ),
        // the settings' signs and every other icon in the ink
        iconTheme: theme.iconTheme.copyWith(color: ink),
        listTileTheme: theme.listTileTheme.copyWith(iconColor: ink),
        chipTheme: theme.chipTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: ink.withValues(alpha: .6)),
          ),
          side: BorderSide(color: ink.withValues(alpha: .6)),
          backgroundColor: Colors.transparent,
          selectedColor: ink,
          checkmarkColor: _Dots.paper(dark),
          labelStyle: _Dots.mono(12, ink, weight: FontWeight.w700, spacing: .6),
          secondaryLabelStyle: _Dots.mono(12, _Dots.paper(dark), weight: FontWeight.w700, spacing: .6),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            side: WidgetStatePropertyAll(BorderSide(color: ink.withValues(alpha: .6))),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? ink : Colors.transparent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? _Dots.paper(dark) : ink,
            ),
          ),
        ),
        sliderTheme: theme.sliderTheme.copyWith(
          activeTrackColor: ink,
          thumbColor: ink,
          inactiveTrackColor: soft.withValues(alpha: .4),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? _Dots.paper(dark) : soft,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? ink : Colors.transparent,
          ),
          trackOutlineColor: WidgetStatePropertyAll(ink.withValues(alpha: .6)),
        ),
        bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          backgroundColor: _Dots.paper(dark),
          modalBackgroundColor: _Dots.paper(dark),
          shape: lookPopupShape(HomeLayout.dots, dark),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: _Dots.paper(dark),
          shape: lookPopupShape(HomeLayout.dots, dark),
        ),
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          indicatorColor: ink.withValues(alpha: .08),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: ink.withValues(alpha: .7)),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(color: states.contains(WidgetState.selected) ? ink : soft),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => _Dots.mono(
              11,
              states.contains(WidgetState.selected) ? ink : soft,
              weight: FontWeight.w700,
              spacing: .6,
            ),
          ),
        ),
      );
    case HomeLayout.bento:
      final t = theme.textTheme;
      TextStyle? heavy(TextStyle? style) => style?.copyWith(fontFamily: 'Unbounded', letterSpacing: -.2);
      return theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: heavy(theme.appBarTheme.titleTextStyle ?? t.titleLarge),
        ),
        textTheme: t.copyWith(
          displayLarge: heavy(t.displayLarge),
          displayMedium: heavy(t.displayMedium),
          displaySmall: heavy(t.displaySmall),
          headlineLarge: heavy(t.headlineLarge),
          headlineMedium: heavy(t.headlineMedium),
          headlineSmall: heavy(t.headlineSmall),
          titleLarge: heavy(t.titleLarge),
        ),
        chipTheme: theme.chipTheme.copyWith(
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: _Bento.tile(dark),
          selectedColor: theme.araAccent,
          checkmarkColor: _onAccent(theme.araAccent),
          secondaryLabelStyle: TextStyle(color: _onAccent(theme.araAccent), fontWeight: FontWeight.w800),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            side: const WidgetStatePropertyAll(BorderSide.none),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? theme.araAccent : _Bento.tile(dark),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface,
            ),
          ),
        ),
        bottomSheetTheme: theme.bottomSheetTheme.copyWith(
          backgroundColor: _Bento.tile(dark),
          modalBackgroundColor: _Bento.tile(dark),
          shape: lookPopupShape(HomeLayout.bento, dark),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: _Bento.tile(dark),
          shape: lookPopupShape(HomeLayout.bento, dark),
        ),
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          indicatorColor: theme.araAccent,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _onAccent(theme.araAccent)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    default:
      return theme;
  }
}

/// A popup's card in a look that has its own: Bento's solid tile, Dots' paper with an inked edge. Null for the others.
Color? lookPopupColour(HomeLayout look, bool dark) => switch (look) {
  HomeLayout.bento => _Bento.tile(dark),
  HomeLayout.dots => _Dots.paper(dark),
  _ => null,
};

ShapeBorder? lookPopupShape(HomeLayout look, bool dark) => switch (look) {
  HomeLayout.bento => RoundedRectangleBorder(borderRadius: BorderRadius.circular(bentoRadius)),
  HomeLayout.dots => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(dotsRadius),
    side: BorderSide(color: _Dots.ink(dark).withValues(alpha: .7)),
  ),
  _ => null,
};

/// A mode's square in the modes' popup in a look that has its own: Bento's solid tile, the accent when on; Dots' inked
/// box, filled with the ink when on. Null for the others.
({BoxDecoration box, Color ink})? lookSquare(HomeLayout look, BuildContext context, {required bool on}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return switch (look) {
    HomeLayout.bento => (
      box: BoxDecoration(color: on ? theme.araAccent : _Bento.inner(dark), borderRadius: BorderRadius.circular(24)),
      ink: on ? _onAccent(theme.araAccent) : theme.colorScheme.onSurface,
    ),
    HomeLayout.dots => (
      box: BoxDecoration(
        color: on ? _Dots.ink(dark) : null,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _Dots.ink(dark).withValues(alpha: .7)),
      ),
      ink: on ? _Dots.paper(dark) : _Dots.ink(dark),
    ),
    _ => null,
  };
}

/// The menu under the panel in a look that has its own. Bento: a row on the panel, the page in use a pill in the accent
/// with its sign and name, the others their sign over a small name. Dots: small capitals, the page in use its sign on
/// an inked square.
class LookNavBar extends StatelessWidget {
  const LookNavBar({
    super.key,
    required this.look,
    required this.destinations,
    required this.selected,
    required this.onSelect,
  });

  final HomeLayout look;
  final List<NavigationDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bento = look == HomeLayout.bento;
    final soft = bento ? theme.colorScheme.onSurfaceVariant : _Dots.soft(dark);
    Widget item(int i) {
      final d = destinations[i];
      final on = i == selected;
      final ink = bento ? (on ? _onAccent(theme.araAccent) : soft) : (on ? _Dots.paper(dark) : _Dots.ink(dark));
      final sign = IconTheme(
        data: IconThemeData(color: ink, size: 22),
        child: on ? (d.selectedIcon ?? d.icon) : d.icon,
      );
      final label = bento
          ? _Bento.label(on ? _onAccent(theme.araAccent) : soft).copyWith(fontSize: 12, fontWeight: FontWeight.w800)
          : _Dots.mono(10, on ? _Dots.ink(dark) : soft, weight: FontWeight.w700, spacing: 1.2);
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          child: Center(
            child: bento
                ? AnimatedContainer(
                    duration: lightDuration(const Duration(milliseconds: 220)),
                    padding: EdgeInsets.symmetric(horizontal: on ? 14 : 6, vertical: 9),
                    decoration: BoxDecoration(
                      color: on ? theme.araAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: on
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              sign,
                              const Gap(6),
                              Text(d.label, style: label),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              sign,
                              const Gap(2),
                              Text(d.label, style: label.copyWith(fontSize: 10)),
                            ],
                          ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? _Dots.ink(dark) : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: sign,
                      ),
                      const Gap(4),
                      Text(d.label.toUpperCase(), style: label),
                    ],
                  ),
          ),
        ),
      );
    }

    return Container(
      height: 64,
      // of a piece with the panel over it: no line between them
      decoration: BoxDecoration(color: contrastPanelColor(dark)),
      child: SafeArea(top: false, child: Row(children: [for (var i = 0; i < destinations.length; i++) item(i)])),
    );
  }
}
