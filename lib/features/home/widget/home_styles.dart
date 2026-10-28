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
    decoration: BoxDecoration(color: _Bento.tile(dark), borderRadius: BorderRadius.circular(radius)),
    child: child,
  ),
  HomeLayout.dots => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _Dots.paper(dark),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _Dots.ink(dark).withValues(alpha: .28)),
    ),
    child: child,
  ),
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
  static const radius = 26.0;

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
    final lo = values.reduce(math.min);
    final hi = math.max(values.reduce(math.max), lo + 20);
    final path = Path();
    for (final (i, v) in values.indexed) {
      final x = size.width * i / (values.length - 1);
      final y = 3 + (size.height - 6) * (1 - (v - lo) / (hi - lo));
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
    final ink = ContrastPalette.ink;
    final live = ref.watch(connectionQualityProvider);
    final kept = useRef<List<int?>>(const []);
    if (connected && live.isNotEmpty) kept.value = live;
    final samples = connected ? live : kept.value;
    final hero = _bentoTile(
      context,
      SizedBox(
        height: slim ? 84 : 118,
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
    if (slim) return hero;
    final muted = scheme.onSurfaceVariant;
    final share = (vpnShare * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const Gap(8),
        IntrinsicHeight(
          child: Row(
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
    Widget cell(_SiteEntry e) => Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 9),
      decoration: BoxDecoration(color: _Bento.inner(dark), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _Bento.label(scheme.onSurfaceVariant)),
          const Gap(5),
          Text(
            !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
            style: _Bento.figure(20, e.colour == _SiteTiles._good ? scheme.onSurface : e.colour),
          ),
        ],
      ),
    );
    return _bentoTile(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SitesHeader(),
          for (var start = 0; start < entries.length; start += 3) ...[
            if (start > 0) const Gap(6),
            Row(
              children: [
                for (var k = 0; k < 3; k++) ...[
                  if (k > 0) const Gap(6),
                  Expanded(child: start + k < entries.length ? cell(entries[start + k]) : const SizedBox.shrink()),
                ],
              ],
            ),
          ],
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    );
  }
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
                child: Icon(Icons.north_east_rounded, size: 15, color: ContrastPalette.ink),
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
  static const red = Color(0xFFE8231C);

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
      borderRadius: BorderRadius.circular(18),
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
    final p = Paint()..color = dot;
    for (var y = 6.0; y < size.height; y += 10) {
      for (var x = 6.0; x < size.width; x += 10) {
        canvas.drawCircle(Offset(x, y), .9, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.paper != paper || old.dot != dot;
}

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
  };

  @override
  Widget build(BuildContext context) {
    final chars = text.split('').where(_glyphs.containsKey).toList();
    final width = chars.isEmpty ? 0.0 : (chars.length * 6 - 1) * cell;
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
    for (final (i, c) in chars.indexed) {
      final rows = _DotNumber._glyphs[c]!;
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 5; x++) {
          final centre = Offset((i * 6 + x + .5) * cell, (y + .5) * cell);
          canvas.drawCircle(centre, rows[y][x] == '1' ? r : r * .45, rows[y][x] == '1' ? on : off);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotNumberPainter old) =>
      old.chars.join() != chars.join() || old.cell != cell || old.colour != colour || old.faint != faint;
}

/// A line of the dotted sheet: a label in small capitals on the left, the value on the right.
Widget _dotRow(BuildContext context, String label, String value, {Color? valueColour}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
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
        Text(value, style: _Dots.mono(15, valueColour ?? _Dots.ink(dark), weight: FontWeight.w800, spacing: .5)),
      ],
    ),
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
    required this.down,
    required this.up,
    required this.vpn,
    required this.direct,
    this.slim = false,
  });

  final bool connected;
  final String timeText;
  final int? ping;
  final (String, String) down;
  final (String, String) up;
  final (String, String) vpn;
  final (String, String) direct;
  final bool slim;

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
    final top = answers.isEmpty ? 1 : answers.reduce(math.max);
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
          Center(
            child: _DotNumber(
              connected && ping != null ? '$ping' : '—',
              cell: slim ? 6 : 10,
              colour: ink,
              faint: _Dots.grid(dark),
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
            SizedBox(
              height: 34,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, s) in bars.indexed) ...[
                    if (i > 0) const Gap(3),
                    Expanded(
                      child: FractionallySizedBox(
                        heightFactor: s == null ? 1 : (s / top).clamp(.12, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: s == null || (average != null && s > average * 2) ? _Dots.red : ink,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _dotRule(context),
            _dotRow(context, '↓ ${t.avpn.superLightDown}', '${down.$1} ${down.$2}'),
            _dotRow(context, '↑ ${t.avpn.superLightUp}', '${up.$1} ${up.$2}'),
            _dotRow(context, 'VPN / ${t.avpn.connDirect}', '${vpn.$1} / ${direct.$1} ${direct.$2}'),
          ],
        ],
      ),
    );
  }
}

/// Dots' sites: a line for each, the name on the left and the delay on the right, red when it is slow.
class _SiteDots extends ConsumerWidget {
  const _SiteDots();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) return const SizedBox.shrink();
    return _dotPaper(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SitesHeader(),
          for (final e in entries)
            _dotRow(
              context,
              e.name,
              !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
              valueColour: e.measured && e.colour != _SiteTiles._good ? _Dots.red : null,
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    );
  }
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
            if (group)
              Icon(Icons.auto_awesome_rounded, size: 20, color: ink)
            else
              Text(flag ?? '🌐', style: const TextStyle(fontSize: 20, height: 1, fontFamilyFallback: ['Emoji'])),
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
    final ink = lit ? ContrastPalette.ink : theme.colorScheme.onSurface;
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

/// Dots' connect control: a black disc (light by night) with a red dot that glows while connected.
class _DotsButton extends StatelessWidget {
  const _DotsButton({required this.on, required this.busy, required this.size, this.label, this.onTap});

  final bool on;
  final bool busy;
  final double size;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final disc = _Dots.ink(dark);
    final paper = _Dots.paper(dark);
    final dot = on ? _Dots.red : (busy ? _Dots.red.withValues(alpha: .45) : _Dots.soft(dark));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: disc),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: size * .2,
              height: size * .2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                boxShadow: [if (on) BoxShadow(color: _Dots.red.withValues(alpha: .8), blurRadius: 12)],
              ),
            ),
            if (label != null) ...[
              const Gap(5),
              Text(label!.toUpperCase(), style: _Dots.mono(9, paper.withValues(alpha: .8), spacing: 1.6)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A pill over the sites (the delay check, the multi-server switch) in a look that has its own: Bento's solid chip,
/// the accent when on; Dots' square-cornered box in small capitals, filled with the ink when on. Null for the others.
({BoxDecoration box, Color ink, TextStyle? text})? lookPill(HomeLayout look, BuildContext context, {required bool on}) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  switch (look) {
    case HomeLayout.bento:
      final ink = on ? ContrastPalette.ink : theme.colorScheme.onSurface;
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
          border: Border.all(color: _Dots.ink(dark).withValues(alpha: .7)),
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
          border: Border.all(color: _Dots.ink(dark).withValues(alpha: .7)),
        ),
        child: child,
      ),
    ),
    _ => null,
  };
}

/// The whole screen in a look that has its own (the pages, the menu, the panel): Dots in its monospaced face with the
/// ink for the accent of the text and a square-cornered outlined tab; Bento its heavy round face for the titles and a
/// solid tab in the accent. The others as they are.
ThemeData lookTheme(ThemeData theme, HomeLayout look) {
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
        colorScheme: theme.colorScheme.copyWith(primary: ink, onPrimary: _Dots.paper(dark)),
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
          checkmarkColor: ContrastPalette.ink,
          secondaryLabelStyle: TextStyle(color: ContrastPalette.ink, fontWeight: FontWeight.w800),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            side: const WidgetStatePropertyAll(BorderSide.none),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? theme.araAccent : _Bento.tile(dark),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? ContrastPalette.ink : theme.colorScheme.onSurface,
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
              color: states.contains(WidgetState.selected) ? ContrastPalette.ink : theme.colorScheme.onSurfaceVariant,
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
  HomeLayout.bento => RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  HomeLayout.dots => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
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
      ink: on ? ContrastPalette.ink : theme.colorScheme.onSurface,
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
      final ink = bento ? (on ? ContrastPalette.ink : soft) : (on ? _Dots.paper(dark) : _Dots.ink(dark));
      final sign = IconTheme(
        data: IconThemeData(color: ink, size: 22),
        child: on ? (d.selectedIcon ?? d.icon) : d.icon,
      );
      final label = bento
          ? _Bento.label(on ? ContrastPalette.ink : soft).copyWith(fontSize: 12, fontWeight: FontWeight.w800)
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
      decoration: BoxDecoration(
        color: contrastPanelColor(dark),
        border: bento ? null : Border(top: BorderSide(color: _Dots.ink(dark).withValues(alpha: .25))),
      ),
      child: SafeArea(top: false, child: Row(children: [for (var i = 0; i < destinations.length; i++) item(i)])),
    );
  }
}
