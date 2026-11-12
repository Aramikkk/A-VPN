part of 'avpn_home_body.dart';

/// The delay to the sites the user uses most, in tiles like the session line's: the site's letter in a thin circle,
/// its name and the delay large, over water that rises the faster it answers, green up to 150 ms, amber up to 300,
/// red slower or with no answer. Two rows of three filling the room the traffic had; a tap asks them again.
class _SiteTiles extends HookConsumerWidget {
  const _SiteTiles({required this.visible, this.compact = false, this.oneRow = false});

  /// only the first row of tiles (a smaller block, for a screen that is not high enough)
  final bool oneRow;

  final bool visible;

  /// a lower tile with a bar along its bottom edge instead of the water, in a block that is only as tall as its rows
  final bool compact;

  static const _good = Color(0xFF7CC43A);
  static const _slow = Color(0xFFF0B429);
  static const _bad = Color(0xFFE5483B);

  // the way there and back through the VPN: the server's own ping is ~50-100 ms, a site a little more
  /// The service's logo (Simple Icons' shape) in [colour], its delay's; Yandex, whose logo is its letter, the letter.
  static Widget _sign(LatencySite site, Color colour, {double size = 15}) {
    final path = siteLogoPaths[site.key];
    final hex = colour.toARGB32().toRadixString(16).substring(2);
    final rule = siteLogoEvenOdd.contains(site.key) ? ' fill-rule="evenodd"' : '';
    return path != null
        ? SvgPicture.string(
            '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#$hex"$rule d="$path"/></svg>',
            width: size,
            height: size,
          )
        : Text(
            site.letter,
            style: TextStyle(fontSize: size, height: 1, fontWeight: FontWeight.w900, color: colour),
          );
  }

  /// A server's flag: the first word of its name when that's a flag ("🇵🇱 Польша 2"), else nothing.
  static String _flagOf(String server) {
    final first = server.trim().split(' ').first;
    return first.runes.any((r) => r >= 0x1F1E6 && r <= 0x1F1FF) ? first : '';
  }

  /// the sign on a solid disc: dark on a light colour, white on a dark one
  static Color _ink(Color disc) =>
      ThemeData.estimateBrightnessForColor(disc) == Brightness.dark ? Colors.white : const Color(0xFF11151A);

  /// the delay's colour by the method's own marks (HTTPS reads higher than HTTP)
  static Color _colour(int? ms, SiteGrade grade) =>
      ms == null || ms >= grade.slow ? _bad : (ms < grade.good ? _good : _slow);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final sites = ref.watch(siteLatencyProvider);
    // the sites' last delays, for the pulse behind a compact tile
    final history = compact ? ref.watch(siteHistoryProvider) : const <String, List<int?>>{};
    // the pulse behind the tiles moves every 30 seconds (a round of the sites) while the block is on screen, and a
    // new round slides it one step to the left over 0.8 s
    final slide = useAnimationController(duration: const Duration(milliseconds: 800));
    useEffect(() {
      if (!compact) return null;
      slide.forward(from: 0);
      return null;
    }, [history]);
    useEffect(() {
      if (!compact || !visible) return null;
      final timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(ref.read(siteLatencyProvider.notifier).test(quiet: true)),
      );
      return timer.cancel;
    }, [compact, visible]);
    // the tiles: the apps marked in Settings → Sites (their own icons and names)
    final shown = ref.watch(homeSitesProvider);
    final installed = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    // the marks of a good delay, by the method (HTTPS is higher by nature)
    final grade = siteGrade(ref.watch(ConfigOptions.pingHttps));
    // each site's own server (Settings → Ping → Sites, beta): its flag in the tile's corner
    final siteServers = ref.watch(siteServersProvider).valueOrNull ?? const {};
    // the server everything else goes through: a site's flag shows only when its own one is another
    final mainServer = ref.watch(proxiesOverviewNotifierProvider.select((v) => SiteLatency.mainServer(v.valueOrNull)));

    Widget tile(LatencySite site) {
      // an app that isn't a known service: its own icon and name
      final app = site.key.startsWith('app:') ? installed[site.key.substring(4)] : null;
      final measured = sites.ms.containsKey(site.key);
      final ms = sites.ms[site.key];
      final colour = !measured ? scheme.outlineVariant : _colour(ms, grade);
      // the logo and its ring in the delay's colour too (green, amber, red); grey until the first round
      final sign = !measured ? scheme.onSurfaceVariant : colour;
      // the faster, the fuller; no answer or 450 ms and slower: a sliver
      final level = !measured ? 0.0 : (ms == null ? .08 : (1 - ms / grade.scale).clamp(.08, 1.0));
      final server = siteServers[site.key];
      // no flag when the site goes through the main server, or one of the same country (the same flag would read as
      // the same server)
      final own = server == null || server == mainServer ? '' : _flagOf(server);
      final flag = own == _flagOf(mainServer ?? '') ? '' : own;
      // the country's name: the server's name without the provider's prefix and its number
      var country = '';
      if (flag.isNotEmpty && server != null) {
        final title = serverNameOf(server).title;
        final dash = title.indexOf(' - ');
        country = (dash < 0 ? title : title.substring(dash + 3)).replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
      }
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
        ),
        child: Stack(
          children: [
            if (!compact)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: level),
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
                                border: l > .97
                                    ? null
                                    : Border(top: BorderSide(color: colour.withValues(alpha: .6), width: 1.5)),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            // the site's own server's flag as a soft blur of its colours over the whole tile (not the main server's country)
            if (flag.isNotEmpty)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16, tileMode: TileMode.decal),
                      child: Opacity(
                        opacity: dark ? .5 : .6,
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          maxHeight: double.infinity,
                          child: Text(
                            flag,
                            style: const TextStyle(fontSize: 120, height: 1, fontFamilyFallback: ['Emoji']),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (compact)
              // the delay's last rounds as a soft curve across the tile's lower part, in the delay's colour
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: slide,
                    builder: (context, _) => CustomPaint(
                      painter: _TilePulsePainter(
                        history: history[site.key] ?? const [],
                        colour: colour,
                        shift: 1 - Curves.easeOutCubic.transform(slide.value),
                      ),
                    ),
                  ),
                ),
              ),
            // the same on the folded and the unfolded phone: the logo and the flag on top, the delay in the middle, the
            // name at the bottom; every size by the tile's height (the unfolded phone's tiles are lower)
            LayoutBuilder(
              builder: (context, box) {
                final k = (box.maxHeight / 118).clamp(.7, 1.0);
                final disc = 28 * k;
                // the service's logo as ink on a solid disc of the delay's colour (every one filled alike)
                final ring = Container(
                  width: disc,
                  height: disc,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: sign),
                  child: app?.icon != null
                      ? Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: ClipOval(
                            child: Image.memory(
                              app!.icon!,
                              width: disc,
                              height: disc,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        )
                      : _sign(site, _ink(sign), size: (site.key == 'claude' ? 17 : 15) * k),
                );
                final name = Text(
                  app?.name ?? site.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.8 * k,
                  ),
                );
                // the country of the site's server, small, top right
                final corner = country.isEmpty
                    ? null
                    : Text(
                        country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10 * k, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                      );
                final unitStyle = TextStyle(
                  fontSize: 13.8 * k,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                );
                return Padding(
                  padding: EdgeInsets.all(11 * k),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ring,
                          const Gap(6),
                          Expanded(
                            child: Align(alignment: Alignment.topRight, child: corner ?? const SizedBox.shrink()),
                          ),
                        ],
                      ),
                      // the delay in the middle of the tile, the name at the bottom
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              // the room of " ms" on the left: the figure is in the middle, " ms" is written after it
                              padding: EdgeInsets.only(
                                left: measured && ms != null
                                    ? _textWidth(
                                        ' ms',
                                        (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
                                          fontSize: 13.8 * k,
                                          letterSpacing: 0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : 0,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: !measured ? '…' : (ms == null ? '—' : '$ms')),
                                    if (measured && ms != null) TextSpan(text: ' ms', style: unitStyle),
                                  ],
                                ),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 36.8 * k,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -1.5 * k,
                                  color: scheme.onSurface,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(child: name),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    Widget line(Iterable<LatencySite> row) {
      final cells = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, site) in row.indexed) ...[if (i > 0) const Gap(8), Expanded(child: tile(site))],
        ],
      );
      return compact ? SizedBox(height: 82, child: cells) : Expanded(child: cells);
    }

    return GestureDetector(
      key: const Key('contrast-sites'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(pingAllServers(ref)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const _SitesHeader(),
          // rows of three; none marked: where to mark them
          if (shown.isEmpty)
            (compact ? (Widget w) => w : (Widget w) => Expanded(child: w))(
              Center(
                child: Text(
                  t.avpn.sitesHomeEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (var start = 0; start < (oneRow ? math.min(shown.length, 3) : shown.length); start += 3) ...[
              if (start > 0) const Gap(8),
              line(shown.skip(start).take(3)),
            ],
        ],
      ),
    );
  }
}

/// Set while a ping of every server runs (from the home screen or the panel), so the lists can show spinners.
final homePingTesting = ValueNotifier(false);

/// Pings every server, unless that's already running.
Future<void> pingAllServers(WidgetRef ref) async {
  if (homePingTesting.value) return;
  homePingTesting.value = true;
  try {
    // the ping, the delays to the sites and the servers' pings together
    await refreshHomeIndicators(read: ref.read);
    await Future<void>.delayed(const Duration(seconds: 4));
  } catch (_) {
    // not connected: nothing to ping
  } finally {
    homePingTesting.value = false;
  }
}

/// The subscription's refresh, by the app's name in the title bar: a sign that turns while the servers are fetched.
class ProfileRefreshButton extends ConsumerWidget {
  const ProfileRefreshButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    if (profile is! RemoteProfileEntity) return const SizedBox.shrink();
    final updating = ref.watch(updateProfileNotifierProvider(profile.id)).isLoading;
    return Tooltip(
      message: t.avpn.stUpdateServers,
      child: InkWell(
        key: const ValueKey('profile-refresh'),
        borderRadius: BorderRadius.circular(12),
        onTap: updating
            ? null
            : () => ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: updating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurfaceVariant),
                )
              : Icon(Icons.sync_rounded, size: 20, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The sites block's head: the delay check and the multi-server switch of the network in use.
class _SitesHeader extends HookConsumerWidget {
  const _SitesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.araAccent;
    final sites = ref.watch(siteLatencyProvider);
    final onMobile = useListenable(_actualNetworkKind).value == NetworkKind.mobile;
    final multiPref = onMobile ? ConfigOptions.siteGroupsMobile : ConfigOptions.siteGroups;
    final multiOn = ref.watch(multiPref);
    final shown = ref.watch(homeSitesProvider);
    // Bento and Dots: their own pills
    final look = ref.watch(Preferences.homeLayout);
    final delayPill = lookPill(look, context, on: sites.testing);
    final multiPill = lookPill(look, context, on: multiOn);
    final hopsOn = ref.watch(ConfigOptions.minHops);
    final hopsPill = lookPill(look, context, on: hopsOn);
    final upper = look == HomeLayout.dots;
    // Dots: the two pills are signs without words (the check; the multi-server switch with the network it is for)
    final signs = look == HomeLayout.dots;
    // a small round button on the left, the block's name beside it; while the sites are asked a ring of the
    // accent fills round it, a site at a time, closes when they have all answered and fades
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dots: the block's name in the middle of the block
          if (signs)
            IgnorePointer(
              // while the sites are asked, a dot for each fills in as it answers
              child: sites.testing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var k = 0; k < shown.length; k++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: k < sites.done
                                    ? _Dots.ink(theme.brightness == Brightness.dark)
                                    : _Dots.grid(theme.brightness == Brightness.dark),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      t.avpn.multiServersTitle.toUpperCase(),
                      maxLines: 1,
                      style: _Dots.mono(10, _Dots.soft(theme.brightness == Brightness.dark), spacing: 1.6),
                    ),
            ),
          Row(
            children: [
              // the delay check, a pill like the multi-server one beside it: the sign and the name; while the sites are
              // asked the sign is a small ring of the accent that fills a site at a time
              // Dots: no check button here, the swipe down on the home screen refreshes
              if (!signs)
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration:
                      delayPill?.box ??
                      BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: sites.testing ? accent.withValues(alpha: .16) : Colors.transparent,
                        border: Border.all(color: sites.testing ? accent : scheme.outlineVariant),
                      ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      sites.testing
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(end: (.08 + .92 * sites.done / math.max(1, shown.length)).clamp(0.0, 1.0)),
                              duration: lightDuration(const Duration(milliseconds: 500)),
                              curve: Curves.easeOutCubic,
                              builder: (context, fill, _) => SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  value: fill,
                                  strokeWidth: 2,
                                  strokeCap: StrokeCap.round,
                                  color: accent,
                                  backgroundColor: scheme.outlineVariant,
                                ),
                              ),
                            )
                          : Icon(Icons.refresh_rounded, size: 15, color: delayPill?.ink ?? scheme.onSurfaceVariant),
                      if (!signs) const Gap(6),
                      if (!signs)
                        Text(
                          upper ? t.avpn.sitesTitle.toUpperCase() : t.avpn.sitesTitle,
                          style:
                              delayPill?.text ??
                              theme.textTheme.labelSmall?.copyWith(
                                color: sites.testing ? scheme.onSurface : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
                              ),
                        ),
                    ],
                  ),
                ),
              if (!signs) const Spacer(),
              // the multi-server switch, for the network in use (Wi-Fi or LTE): a tap turns it on or off
              GestureDetector(
                key: const Key('multi-servers'),
                behavior: HitTestBehavior.opaque,
                // a tap says what the switch is and lets the user turn it on or off
                onTap: () => unawaited(
                  showFeatureDialog(
                    context,
                    title: '${t.avpn.multiServersTitle} · ${onMobile ? 'LTE' : 'Wi-Fi'}',
                    body: t.avpn.multiServersInfo,
                    stateText: multiOn ? t.avpn.featureStateOn : t.avpn.featureStateOff,
                    on: multiOn,
                    onLabel: t.avpn.featureOn,
                    offLabel: t.avpn.featureOff,
                    closeLabel: t.avpn.featureClose,
                    onChoose: (on) => ref.read(multiPref.notifier).update(on),
                  ),
                ),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration:
                      multiPill?.box ??
                      BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: multiOn ? accent.withValues(alpha: .16) : Colors.transparent,
                        border: Border.all(color: multiOn ? accent : scheme.outlineVariant),
                      ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alt_route_rounded,
                        size: 15,
                        color: multiPill?.ink ?? (multiOn ? accent : scheme.onSurfaceVariant),
                      ),
                      // Dots: the network the switch is for, beside the sign
                      if (signs) ...[
                        const Gap(5),
                        Icon(
                          onMobile ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded,
                          size: 15,
                          color: multiPill?.ink ?? (multiOn ? accent : scheme.onSurfaceVariant),
                        ),
                      ] else ...[
                        const Gap(6),
                        Text(
                          upper
                              ? '${t.avpn.multiServers} · ${onMobile ? 'LTE' : 'Wi-Fi'}'.toUpperCase()
                              : '${t.avpn.multiServers} · ${onMobile ? 'LTE' : 'Wi-Fi'}',
                          style:
                              multiPill?.text ??
                              theme.textTheme.labelSmall?.copyWith(
                                color: multiOn ? scheme.onSurface : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // the fewer-hops mode: the server chosen stays while it is steady; a tap says what it is and turns it on or off
              if (signs) const Spacer() else const Gap(8),
              GestureDetector(
                key: const Key('min-hops'),
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(
                  showFeatureDialog(
                    context,
                    title: t.avpn.minHops,
                    body: t.avpn.minHopsInfo,
                    stateText: hopsOn ? t.avpn.featureStateOn : t.avpn.featureStateOff,
                    on: hopsOn,
                    onLabel: t.avpn.featureOn,
                    offLabel: t.avpn.featureOff,
                    closeLabel: t.avpn.featureClose,
                    onChoose: (on) => ref.read(ConfigOptions.minHops.notifier).update(on),
                  ),
                ),
                child: Container(
                  height: 30,
                  width: 34,
                  decoration:
                      hopsPill?.box ??
                      BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: hopsOn ? accent.withValues(alpha: .16) : Colors.transparent,
                        border: Border.all(color: hopsOn ? accent : scheme.outlineVariant),
                      ),
                  child: Icon(
                    Icons.anchor_rounded,
                    size: 15,
                    color: hopsPill?.ink ?? (hopsOn ? accent : scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
