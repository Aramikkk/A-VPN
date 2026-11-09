part of 'avpn_home_body.dart';

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
    final anyCountry = keepSiteLine(entries.any((e) => e.country.isNotEmpty));
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
  Widget? lead,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final accent = theme.araAccent;
  if (lead != null) {
    // the current server: the button at the left, the label, the flag and the country in the middle, the ping at the right
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_Bento.radius),
          onTap: onTap,
          child: _bentoTile(
            context,
            _centeredServer(
              lead: lead,
              reserve: 86,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _Bento.label(scheme.onSurfaceVariant),
                  ),
                  const Gap(3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
              trailing: testing
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: ms),
                          if (measured) TextSpan(text: ' ms', style: _Bento.label(scheme.onSurfaceVariant)),
                        ],
                      ),
                      style: _Bento.figure(selected ? 24 : 20, scheme.onSurface),
                    ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          ),
        ),
      ),
    );
  }
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
