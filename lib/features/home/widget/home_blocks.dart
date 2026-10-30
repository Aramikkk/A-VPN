part of 'avpn_home_body.dart';

/// The home screen's strip map: where today's traffic went, the apps under a megabyte left out.
class _HomeTraffic extends ConsumerWidget {
  const _HomeTraffic({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final units = t.avpn.bytesUnits.split(',');
    // followed only while the home screen is in sight
    final state = visible ? ref.watch(connectionsProvider) : ref.read(connectionsProvider);
    // this session's connections only, as the right panel of the unfolded phone
    // held across the statistics stream's blinks, so the card doesn't flip when the app comes back
    final sessionStart = ref.watch(sessionStartProvider);
    // the VPN off: no session, the picture (the last session's list isn't shown)
    final connected = ref.watch(shownConnectionProvider).isConnected;
    final current = sessionConnections(state, connected: connected, sessionStart: sessionStart);
    final big = {
      for (final g in groupConnections(current, (c) => c.app))
        if (g.total >= smallTraffic) g.key,
    };
    final items = current.where((c) => big.contains(c.app)).toList();
    final servers = groupConnections(
      items.where((c) => c.route == ConnectionRoute.vpn && c.outbound.isNotEmpty && !isHiddenServer(c.outbound)),
      (c) => c.outbound,
    )..sort((a, b) => b.total.compareTo(a.total));
    final theme = Theme.of(context);
    if (theme.contrastLayout) {
      final installed = ref.watch(installedAppsProvider).valueOrNull ?? const {};
      // by traffic on every platform (the time on screen came out empty on most phones)
      List<_AppShare> route(ConnectionRoute r) {
        final groups = groupConnections(current.where((c) => c.route == r && c.app.isNotEmpty), (c) => c.app)
          ..sort((a, b) => b.total.compareTo(a.total));
        return [
          for (final g in groups)
            if (g.total > 0)
              (
                name: connectionAppName(t, installed, g.key),
                bytes: g.total,
                duration: Duration.zero,
                servers: r == ConnectionRoute.vpn ? serverFlags(g.servers.where((s) => !isHiddenServer(s))) : '',
                icon: installed[g.key]?.icon,
              ),
        ];
      }

      // the headline totals are the session's, as in the stats block: from the VPN's switch-on, zero when it is off
      final totals = ref.watch(sessionTotalsProvider);
      final total = connected ? totals.up + totals.down : 0;
      final viaVpn = connected ? ((totals.vpnUp ?? 0) + (totals.vpnDown ?? 0)).clamp(0, total) : 0;
      return _ContrastMosaic(
        vpn: route(ConnectionRoute.vpn),
        direct: route(ConnectionRoute.direct),
        vpnTotal: viaVpn,
        directTotal: total - viaVpn,
      );
    }
    // fixed in place (no scroll) and without a heading, so the strips have the room; what doesn't fit is cut
    final strips = ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrafficStrips(
              items: items,
              weight: (c) => c.total.toDouble(),
              value: (w) => formatBytes(w.round(), units),
              compact: true,
              directLabel: t.avpn.homeBypass,
            ),
            // the computer has the room: the VPN servers this traffic went through, under the strips
            if (PlatformUtils.isDesktop && servers.isNotEmpty) ...[
              const Gap(16),
              Text(
                t.avpn.topoServersTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Gap(4),
              TrafficRanking(
                rows: [for (final g in servers.take(6)) (g.key, g.total.toDouble())],
                total: servers.fold<double>(0, (s, g) => s + g.total),
                value: (w) => formatBytes(w.round(), units),
                colour: theme.araAccent,
              ),
            ],
          ],
        ),
      ),
    );
    // Glass: the strips on a pane of glass, as the rows above them
    final glass = theme.glassLook;
    if (glass == null) return strips;
    // the card always fills its place, empty or not
    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: glass.edge, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: items.isEmpty
            // nothing (or only apps under a megabyte) yet: a picture of strips, half the card high
            ? LayoutBuilder(
                builder: (context, box) => Center(
                  child: TrafficPlaceholder(height: math.min(box.maxHeight / 2, box.maxWidth * .6 * 122 / 200)),
                ),
              )
            // from the top, each part always in its place (the strips keep a fixed height)
            : Align(alignment: Alignment.topCenter, child: strips),
      ),
    );
  }
}

/// Contrast's session tiles: the time, through the VPN and the bypass today, each a see-through tile with its sign
/// in a thin circle, its label and a big tight figure, all centred, over water: the time's level by the day, the
/// two routes' by each other.
class _ContrastStats extends StatelessWidget {
  const _ContrastStats({required this.items});

  /// (sign, label, figure, unit, in the accent, water level 0 to 1, water colour)
  final List<(IconData, String, String, String, bool, double, Color)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    Widget water(double level, Color colour) => _Water(level: level, colour: colour, dark: dark);
    // the unfolded phone (or a tablet): half as high, the sign beside the label and the figure
    final compact = MediaQuery.sizeOf(context).width >= 700 || MediaQuery.sizeOf(context).height < 600;
    Widget tile(IconData icon, String label, String figure, String unit, bool lit, double level, Color colour) {
      Widget value(double size, {bool centred = false}) {
        final text = Text.rich(
          TextSpan(
            children: [
              TextSpan(text: figure),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w500,
            letterSpacing: -1,
            color: lit ? scheme.primary : scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        // centred: as much room on the left as the unit takes on the right, so the figure itself is in the middle
        // and the unit is just written after it
        return centred && unit.isNotEmpty
            ? Padding(
                padding: EdgeInsets.only(
                  left: _textWidth(
                    ' $unit',
                    (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
                      fontSize: 11,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: text,
              )
            : text;
      }

      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: water(level, colour)),
            if (compact)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
                      child: Icon(icon, size: 15, color: _SiteTiles._ink(colour)),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value(19)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 9),
                // the height it had by its content: the figure sits in the middle of it, the label at the bottom
                child: SizedBox(
                  height: 78,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
                        child: Icon(icon, size: 15, color: _SiteTiles._ink(colour)),
                      ),
                      // the figure in the middle of what is left, the label at the bottom
                      Expanded(
                        child: Center(
                          child: FittedBox(fit: BoxFit.scaleDown, child: value(22, centred: true)),
                        ),
                      ),
                      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Row(
      children: [
        for (final (i, (icon, label, figure, unit, lit, level, colour)) in items.indexed) ...[
          if (i > 0) const Gap(6),
          // each tile in a layer of its own: the clock's tick doesn't draw the other two again
          Expanded(child: RepaintBoundary(child: tile(icon, label, figure, unit, lit, level, colour))),
        ],
      ],
    );
  }
}

/// An app's part of a route: its name, how much, the servers it went through (flags) and its icon.
typedef _AppShare = ({String name, int bytes, Duration duration, String servers, Uint8List? icon});

/// Contrast's traffic as a mosaic: the session's totals through the VPN and the bypass, under them a tile for each
/// app, as big as its share of the traffic; the VPN's in the accent, the bypass's grey.
class _ContrastMosaic extends ConsumerWidget {
  const _ContrastMosaic({required this.vpn, required this.direct, required this.vpnTotal, required this.directTotal});

  final List<_AppShare> vpn;
  final List<_AppShare> direct;

  /// the session's totals through the VPN and direct (the tiles are only the apps over the limit)
  final int vpnTotal;
  final int directTotal;

  /// the most tiles: the rest in one tile of their own
  static const _most = 11;

  /// the least an app has to have used to get a tile: 10 MB
  static const _least = 10 * 1024 * 1024;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    const grey = Color(0xFF9AA0A6);
    final units = t.avpn.bytesUnits.split(',');
    final vpnBytes = vpnTotal;
    final directBytes = directTotal;
    // one card an app, through the VPN and direct together; only the apps with 10 MB or more (the totals above
    // count everything)
    final merged = <String, ({_AppShare app, int vpnBytes})>{};
    for (final (a, onVpn) in [for (final a in vpn) (a, true), for (final a in direct) (a, false)]) {
      final had = merged[a.name];
      merged[a.name] = (
        app: (
          name: a.name,
          bytes: (had?.app.bytes ?? 0) + a.bytes,
          duration: Duration.zero,
          servers: onVpn ? a.servers : (had?.app.servers ?? ''),
          icon: had?.app.icon ?? a.icon,
        ),
        vpnBytes: (had?.vpnBytes ?? 0) + (onVpn ? a.bytes : 0),
      );
    }
    final all = merged.values.where((m) => m.app.bytes >= _least).toList()
      ..sort((a, b) => b.app.bytes.compareTo(a.app.bytes));
    final shown = all.take(all.length > _most ? _most - 1 : _most).toList();
    final rest = all.skip(shown.length).toList();
    final tiles = <_MosaicTile>[
      for (final m in shown) (app: m.app, vpnShare: m.app.bytes == 0 ? 0.0 : m.vpnBytes / m.app.bytes, more: 0),
      if (rest.isNotEmpty)
        (
          app: (
            name: t.avpn.contrastMore(n: rest.length),
            bytes: rest.fold(0, (s, r) => s + r.app.bytes),
            duration: Duration.zero,
            servers: '',
            icon: null,
          ),
          vpnShare: rest.fold(0, (s, r) => s + r.vpnBytes) / math.max(1, rest.fold(0, (s, r) => s + r.app.bytes)),
          more: rest.length,
        ),
    ];

    Widget total(String label, int bytes, Color colour, CrossAxisAlignment align) {
      final amount = formatBytes(bytes, units).split(' ');
      return Column(
        crossAxisAlignment: align,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: colour, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: amount.first),
                if (amount.length > 1)
                  TextSpan(
                    text: ' ${amount.skip(1).join(' ')}',
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1),
          ),
        ],
      );
    }

    return Column(
      key: const Key('contrast-traffic'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
          child: Row(
            children: [
              Expanded(child: total(t.avpn.statsViaVpn, vpnBytes, accent, CrossAxisAlignment.start)),
              Expanded(child: total(t.avpn.homeBypass, directBytes, scheme.onSurfaceVariant, CrossAxisAlignment.end)),
            ],
          ),
        ),
        Expanded(
          child: tiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.data_usage_rounded, size: 40, color: scheme.outlineVariant),
                      const Gap(8),
                      Text(
                        t.avpn.trafficSmallHidden,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final places = <(Rect, _MosaicTile)>[];
                    _lay(tiles, Offset.zero & box.biggest, places);
                    return Stack(
                      children: [
                        for (final (rect, tile) in places)
                          Positioned.fromRect(
                            rect: rect.deflate(3),
                            child: _MosaicCell(
                              tile: tile,
                              // mostly through the VPN: the accent; mostly direct: grey
                              colour: tile.vpnShare >= .5 ? accent : grey,
                              units: units,
                              direct: t.avpn.statsDirect.toLowerCase(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Lays [tiles] (the biggest first) out on [area]: split in two halves of the traffic across its longer side,
  /// each half laid out the same way.
  static void _lay(List<_MosaicTile> tiles, Rect area, List<(Rect, _MosaicTile)> out) {
    if (tiles.isEmpty) return;
    if (tiles.length == 1) {
      out.add((area, tiles.first));
      return;
    }
    // sizes relative, not proportional: a tile grows with its traffic's 0.35th power, and none is smaller than a
    // quarter of the largest, so the biggest app is a few times the smallest tile, not half the screen, and all fit
    final largest = tiles.fold<double>(0, (m, t) => math.max(m, math.pow(t.app.bytes, .35).toDouble()));
    double weight(_MosaicTile t) => math.max(math.pow(t.app.bytes, .35).toDouble(), largest / 4);
    final sum = tiles.fold<double>(0, (s, t) => s + weight(t));
    var half = weight(tiles.first);
    var k = 1;
    while (k < tiles.length - 1 && half + weight(tiles[k]) <= sum / 2) {
      half += weight(tiles[k]);
      k++;
    }
    final f = half / sum;
    if (area.width >= area.height) {
      final w = area.width * f;
      _lay(tiles.sublist(0, k), Rect.fromLTWH(area.left, area.top, w, area.height), out);
      _lay(tiles.sublist(k), Rect.fromLTWH(area.left + w, area.top, area.width - w, area.height), out);
    } else {
      final h = area.height * f;
      _lay(tiles.sublist(0, k), Rect.fromLTWH(area.left, area.top, area.width, h), out);
      _lay(tiles.sublist(k), Rect.fromLTWH(area.left, area.top + h, area.width, area.height - h), out);
    }
  }
}

/// A mosaic's tile: an app (or the rest of them, [more] apps) and its route.
typedef _MosaicTile = ({_AppShare app, double vpnShare, int more});

/// An app's tile in the mosaic: its icon, name, amount and route; a small one just the icon and the amount.
class _MosaicCell extends StatelessWidget {
  const _MosaicCell({required this.tile, required this.colour, required this.units, required this.direct});

  /// the bypass's word under its tiles
  final String direct;

  final _MosaicTile tile;
  final Color colour;
  final List<String> units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final app = tile.app;
    final amount = formatBytes(app.bytes, units).split(' ');
    return LayoutBuilder(
      builder: (context, box) {
        final small = box.maxWidth < 96 || box.maxHeight < 104;
        final side = small ? 22.0 : 30.0;
        final icon = ClipRRect(
          borderRadius: BorderRadius.circular(side * .3),
          child: app.icon != null && tile.more == 0
              ? appIconView(app.icon!, size: side)
              : Container(
                  width: side,
                  height: side,
                  alignment: Alignment.center,
                  color: colour.withValues(alpha: .25),
                  child: tile.more > 0
                      ? Icon(Icons.more_horiz_rounded, size: side * .6, color: scheme.onSurface)
                      : Text(
                          app.name.isEmpty ? '?' : app.name.characters.first.toUpperCase(),
                          style: TextStyle(fontSize: side * .5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                ),
        );
        // the number as big as the tile allows
        final figure = (box.maxWidth / 6).clamp(16.0, 34.0);
        return Container(
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.all(small ? 6 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colour.withValues(alpha: dark ? .5 : .6)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colour.withValues(alpha: dark ? .14 : .12),
                colour.withValues(alpha: dark ? .3 : .26),
              ],
            ),
          ),
          child: small
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const Gap(3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        amount.join(' '),
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const Gap(6),
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: amount.first),
                            if (amount.length > 1)
                              TextSpan(
                                text: ' ${amount.skip(1).join(' ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: figure,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (tile.more == 0)
                      Text(
                        // both ways: the VPN's share, then direct
                        tile.vpnShare >= 1
                            ? 'VPN ${app.servers}'.trim()
                            : tile.vpnShare <= 0
                            ? direct
                            : '${'VPN ${app.servers}'.trim()} ${(tile.vpnShare * 100).round()}% · $direct',
                        // every country the app's traffic went through, on as many lines as it takes
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tile.vpnShare >= .5 ? (dark ? colour : scheme.onSurface) : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// The VPN servers this session went through, in a see-through card: each with its flag, name, protocol and ping,
/// the traffic through it and its share; the one in use now marked.
class _SessionServers extends ConsumerWidget {
  const _SessionServers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final units = t.avpn.bytesUnits.split(',');
    final start = ref.watch(sessionStartProvider);
    final group = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    final activeOutbound = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    final inUse = current != null && current.isGroup
        ? autoPick(current, group!.items, fallback: current.tag == group.selected ? activeOutbound : null)
        : current;
    final servers = groupConnections([
      for (final c in ref.watch(connectionsProvider).sessionItems)
        if (start != null &&
            (c.session == start.millisecondsSinceEpoch || (c.session == null && !c.start.isBefore(start))) &&
            c.route == ConnectionRoute.vpn &&
            c.outbound.isNotEmpty &&
            !isHiddenServer(c.outbound))
          c,
    ], (c) => c.outbound)..sort((a, b) => b.total.compareTo(a.total));
    final total = servers.fold<int>(0, (s, g) => s + g.total);
    // The connections seen are only a sample (the short ones close between two readings): the servers share the
    // session's VPN traffic from the core, the same number as the tile above, in the proportions seen.
    final totals = ref.watch(sessionTotalsProvider);
    final sessionVpn = (totals.vpnUp ?? 0) + (totals.vpnDown ?? 0);
    final scale = total > 0 && sessionVpn > total ? sessionVpn / total : 1.0;
    final ink = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.4),
                  ),
                  child: Icon(Icons.dns_rounded, size: 16, color: theme.araIcon),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.avpn.contrastServersTab, style: theme.textTheme.titleMedium),
                      Text(
                        t.avpn.contrastThisSession,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${servers.length}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -1),
                ),
              ],
            ),
          ),
          if (servers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: TrafficPlaceholder(height: 60)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: servers.length,
                itemBuilder: (context, i) {
                  final g = servers[i];
                  final info = group?.items.where((s) => s.tag == g.key).firstOrNull;
                  final name = info == null ? serverNameOf(g.key) : serverName(info);
                  final dash = name.title.indexOf(' - ');
                  final title = dash < 0 ? name.title : name.title.substring(dash + 3).trim();
                  final delay = info == null
                      ? 0
                      : displayedHomePingDelay(
                          info,
                          autoNow: inUse,
                          active: activeOutbound,
                          selected: info.tag == group?.selected,
                        );
                  final share = total == 0 ? 0.0 : g.total / total;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: ink.withValues(alpha: .07))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            FlagBadge(profile: name.profile, child: flagGlyph(name.flag, emoji: 20, width: 30)),
                            const Gap(9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: title),
                                        if (info != null && info.tag == inUse?.tag)
                                          TextSpan(
                                            text: ' · ${t.avpn.stNow}',
                                            style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w800),
                                          ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    [
                                      if (info != null) info.type.toUpperCase(),
                                      if (delay > 0 && delay < 65000) '$delay ms',
                                    ].join(' · '),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatBytes((g.total * scale).round(), units),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const Gap(6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: share,
                                  minHeight: 4,
                                  color: accent,
                                  backgroundColor: ink.withValues(alpha: .08),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${(share * 100).round()}%',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The session's traffic by app, as the home screen showed it before the sites took its place: through the VPN and
/// direct, each filled with its apps. Down from the top with a swipe down on the home screen; a swipe up (or Back)
/// takes it away.
class SessionTrafficPage extends ConsumerWidget {
  const SessionTrafficPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    return _LongSwipe(
      onDown: () {},
      onUp: () => context.canPop() ? context.pop() : context.goNamed('home'),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.avpn.trafficPageTitle),
              Text(
                t.avpn.trafficPageSession,
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: _ContrastBlock(expand: true, child: const _HomeTraffic(visible: true)),
          ),
        ),
      ),
    );
  }
}

/// The home screen's connections block: how many are open and where they go; a tap opens the full description.
class _ConnectionsBlock extends ConsumerWidget {
  const _ConnectionsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final open = [
      for (final c in ref.watch(connectionsProvider).items)
        if (c.active) c,
    ];
    var vpn = 0, direct = 0, blocked = 0;
    for (final c in open) {
      switch (c.route) {
        case ConnectionRoute.vpn:
          vpn += c.count;
        case ConnectionRoute.direct:
          direct += c.count;
        case ConnectionRoute.block:
          blocked += c.count;
      }
    }
    // the flask's look: the figure large and thin, the VPN's share against the bypass as a split line
    final look = ref.watch(Preferences.homeLayout);
    if (look == HomeLayout.bento || look == HomeLayout.dots) {
      return Semantics(
        key: const ValueKey('connections-block'),
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showGlassPopup(context, const _ConnectionsDetails()),
          child: look == HomeLayout.bento
              ? _bentoConnections(context, t, open: open.length, vpn: vpn, direct: direct)
              : _dotsConnections(context, t, open: open.length, vpn: vpn, direct: direct),
        ),
      );
    }
    Widget part(Color color, int n, String label) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const Gap(5),
          Text(
            '$n $label',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Semantics(
      key: const ValueKey('connections-block'),
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showGlassPopup(context, const _ConnectionsDetails()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          // in the middle of the block: the sign, the number, then the description a good way off it
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swap_vert_rounded, size: 26, color: theme.araIcon),
              const Gap(12),
              Text('${open.length}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Gap(20),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.avpn.connBlockTitle} · ${t.avpn.connBlockOpen}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Gap(3),
                    Wrap(
                      children: [
                        part(accent, vpn, t.avpn.connViaVpn),
                        part(scheme.onSurfaceVariant, direct, t.avpn.connDirect),
                        if (blocked > 0) part(scheme.error, blocked, t.avpn.connBlocked),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the open connections are: by app, where each goes (the VPN and its server, direct, blocked), and to which
/// sites.
class _ConnectionsDetails extends ConsumerWidget {
  const _ConnectionsDetails();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final open = [
      for (final c in ref.watch(connectionsProvider).items)
        if (c.active) c,
    ];
    final groups = groupConnections(open, (c) => c.app);
    final units = t.avpn.bytesUnits.split(',');

    String where(ConnectionGroup g) {
      final servers = {
        for (final c in g.items)
          if (c.route == ConnectionRoute.vpn && c.outbound.isNotEmpty) c.outbound,
      };
      final parts = <String>[
        if (g.vpn > 0) [t.avpn.connViaVpn, if (servers.isNotEmpty) serverFlags(servers)].join(' '),
        if (g.direct > 0) t.avpn.connDirect,
        if (g.blocked > 0) t.avpn.connBlocked,
      ];
      return parts.join(' · ');
    }

    Widget row(ConnectionGroup g) {
      final hosts = <String, int>{};
      for (final c in g.items) {
        if (c.host.isNotEmpty) hosts[c.host] = (hosts[c.host] ?? 0) + c.count;
      }
      final top = (hosts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList();
      final shown = top.take(3).join(', ');
      final more = top.length > 3 ? ' ${t.avpn.connSitesMore(n: top.length - 3)}' : '';
      final name = connectionAppName(t, apps, g.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConnectionAppIcon(icon: apps[g.key]?.icon, name: name, size: 30),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    where(g),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: g.vpn >= g.direct ? accent : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (shown.isNotEmpty)
                    Text(
                      '$shown$more',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatBytes(g.total, units),
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('${g.open}', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(child: Text(t.avpn.connDetailsTitle, style: theme.textTheme.titleMedium)),
                Text('${open.length}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text(t.avpn.connDetailsNone, style: theme.textTheme.bodyMedium)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: groups.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: scheme.onSurface.withValues(alpha: .07)),
                itemBuilder: (_, i) => row(groups[i]),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.goNamed('connections');
            },
            child: Text(t.avpn.connShowAll),
          ),
        ],
      ),
    );
  }
}

/// The home screen's top row in three tiles: what went through the VPN and what bypassed it (one tile), the time
/// of the session in the middle, and the speeds (in and out) on the right.
class _HomeStats extends ConsumerWidget {
  const _HomeStats({
    required this.timeText,
    required this.timeLevel,
    required this.vpn,
    required this.direct,
    required this.vpnShare,
    required this.down,
    required this.up,
    required this.speedLevel,
  });

  /// how good the speed is, 0 to 1 (the water of its tile)
  final double speedLevel;

  final String timeText;
  final double timeLevel;

  /// (figure, unit)
  final (String, String) vpn;
  final (String, String) direct;
  final double vpnShare;
  final (String, String) down;
  final (String, String) up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araAccent;
    const grey = Color(0xFF9AA0A6);
    const timeColour = Color(0xFF8FA8BD);

    Widget shell(double level, Color colour, Widget child) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _Water(level: level, colour: colour, dark: dark),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 9),
            child: SizedBox(height: 78, child: child),
          ),
        ],
      ),
    );

    TextSpan figure((String, String) value) => TextSpan(
      children: [
        TextSpan(text: value.$1),
        if (value.$2.isNotEmpty)
          TextSpan(
            text: ' ${value.$2}',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    Widget line(IconData icon, Color colour, (String, String) value, {bool lit = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // the same width for every sign, so the two stand in one column
        SizedBox(width: 24, child: Icon(icon, size: 20, color: colour)),
        const Gap(4),
        Text.rich(
          figure(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
            color: lit ? scheme.primary : scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    // two figures one above the other, in the middle
    Widget pair(Widget a, Widget b) => Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [a, const Gap(12), b],
        ),
      ),
    );

    final traffic = shell(
      vpnShare,
      accent,
      pair(line(Icons.shield_rounded, accent, vpn, lit: true), line(Icons.alt_route_rounded, grey, direct)),
    );
    final time = shell(
      timeLevel,
      timeColour,
      // the sign and the figure together in the middle of the tile
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: timeColour),
                child: Icon(Icons.access_time_filled_rounded, size: 15, color: _SiteTiles._ink(timeColour)),
              ),
              const Gap(10),
              Text(
                timeText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final speed = shell(
      speedLevel,
      accent,
      pair(line(Icons.south_rounded, accent, down, lit: true), line(Icons.north_rounded, grey, up)),
    );
    return Row(
      children: [
        Expanded(child: RepaintBoundary(child: traffic)),
        const Gap(6),
        // the time is the one that ticks: in the middle, in a layer of its own
        Expanded(child: RepaintBoundary(child: time)),
        const Gap(6),
        Expanded(child: RepaintBoundary(child: speed)),
      ],
    );
  }
}

/// The servers answering their ping, the fastest first: a tap on one chooses it.
class _AnsweringSheet extends ConsumerWidget {
  const _AnsweringSheet({required this.servers, required this.selected});

  final List<OutboundInfo> servers;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text(
            t.avpn.dockServersAnswering(count: servers.length),
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: servers.length,
            itemBuilder: (context, i) {
              final server = servers[i];
              final name = serverName(server);
              final chosen = server.tag == selected;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(homeLookNow == HomeLayout.dots ? 6 : 14),
                ),
                selected: chosen,
                selectedTileColor: scheme.primary.withValues(alpha: .12),
                leading: flagGlyph(name.flag, emoji: 22, width: 30),
                title: Text(
                  _marked(name.title.contains(' - ') ? name.title.split(' - ').last.trim() : name.title, name.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: chosen ? FontWeight.w800 : FontWeight.w600,
                    color: chosen ? scheme.primary : null,
                  ),
                ),
                trailing: _Delay(delay: server.urlTestDelay, testing: false),
                onTap: () {
                  ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy("select", server.tag);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
