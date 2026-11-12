part of 'avpn_home_body.dart';

/// The home screen in Contrast, Glass or Graphite: the state at the top, the servers in the middle, and the connect
/// control at the bottom, under the thumb.
class _StyledHome extends HookConsumerWidget {
  const _StyledHome({required this.testing, required this.onCheck, required this.visible, this.traffic = true});

  final bool traffic;
  final bool visible;

  final bool testing;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final activeOutbound = ref.watch(activeProxyNotifierProvider).valueOrNull;
    // the status as the screen shows it: a blink of "disconnected" while the core's link restarts doesn't show
    final status = ref.watch(shownConnectionProvider);
    final connected = status.isConnected;
    // the pause of the VPN: the screen is drawn again when it begins or ends (the pings turn to dashes and back)
    ref.watch(vpnPauseProvider);
    // The home page listener resolves the physical network under the VPN.
    final networkKind = useListenable(_actualNetworkKind).value;
    final actualMobile = networkKind == NetworkKind.mobile;
    final liveGroup = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    // the servers' list is held for 15 seconds when it goes (a switch of the network, a restart of the core): the page
    // keeps its blocks instead of collapsing to "connect to see the servers" and building up again a moment later
    final heldGroup = useRef<OutboundGroup?>(null);
    final heldExpired = useState(false);
    if (liveGroup != null) heldGroup.value = liveGroup;
    useEffect(() {
      if (liveGroup != null) {
        heldExpired.value = false;
        return null;
      }
      final timer = Timer(const Duration(seconds: 15), () => heldExpired.value = true);
      return timer.cancel;
    }, [liveGroup == null]);
    final group = liveGroup ?? (heldExpired.value ? null : heldGroup.value);
    final autoGroup = group?.items
        .where((i) => i.tag == (group.selected == 'balance' ? 'balance' : 'lowest'))
        .firstOrNull;
    final autoNow = autoGroup == null
        ? null
        : autoPick(autoGroup, group!.items, fallback: group.selected == autoGroup.tag ? activeOutbound : null);
    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    final picked = current != null && current.isGroup
        ? autoPick(current, group!.items, fallback: current.tag == group.selected ? activeOutbound : null)
        : null;
    // with Auto chosen, the country it is on now shows in Auto's own row ("сейчас: Польша"), not again below it
    final servers = [
      for (final item in group?.items ?? <OutboundInfo>[])
        if (item.isVisible && item.tag != 'balance' && item.tag != picked?.tag) item,
    ];
    final serverMode = ref.watch(ConfigOptions.homeNetwork);
    // the super light mode: the servers in a list of their own where the delays were, and nothing else
    final superLight = ref.watch(superLightProvider);
    // the ping, the loss and the sites' delays are asked together every 5 seconds,
    // while the VPN is up, the app is in front and this is the screen on view (they all move at one pace)
    final lifecycle = useAppLifecycleState();
    final live = connected && visible && !superLight && (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    useEffect(() {
      if (!live) return null;
      final quality = ref.read(connectionQualityProvider.notifier);
      final connections = ref.read(connectionsProvider.notifier);
      // one tick for all: the probe of the ping (and so the loss), the round of the sites and the list of the
      // connections start at the same moment, their own timers wait meanwhile
      quality.driven = true;
      connections.driven = true;
      void tick() {
        quality.probeNow();
        connections.pollNow();
        unawaited(ref.read(siteLatencyProvider.notifier).test(quiet: true));
      }

      tick();
      final timer = Timer.periodic(const Duration(seconds: 5), (_) => tick());
      return () {
        timer.cancel();
        quality.driven = false;
        connections.driven = false;
      };
    }, [live]);
    // how the blocks are laid out (the super light mode keeps the look chosen: its own lighter form of it)
    final layout = ref.watch(Preferences.homeLayout);
    // the folded phone (about 960 high) has room to spare: wider gaps and a bigger connect panel; the unfolded one
    // (about 830) keeps everything tight
    final roomy = MediaQuery.sizeOf(context).height >= 900;
    // Auto and two countries folded (three would crowd the strips), Auto and four in the unfolded phone's servers
    // column; the rest a scroll away
    final rowsInSight = traffic ? 3 : 5;
    final currentName = switch (current?.tag) {
      _ when serverMode => '🏠 ${t.avpn.server}',
      'lowest' || 'balance' => picked == null ? t.avpn.auto : '${t.avpn.auto} · ${_withFlag(serverName(picked))}',
      null => null,
      _ => _withFlag(serverName(current!)),
    };

    final hasList = profile != null && servers.isNotEmpty;
    final header = _ServersHeader(profile: profile, testing: testing, onCheck: null, showCheck: false);
    final dock = _GraphiteDock(
      status: status,
      server: connected ? currentName : null,
      actualMobile: actualMobile,
      networkKnown: networkKind != NetworkKind.unknown,
      testing: testing,
      onCheck: onCheck,
      // the bigger connect panel where there's room: a tall screen, or the unfolded phone (no strips under the
      // servers there), so it's the same size folded and unfolded
      large: roomy || !traffic,
    );

    // one gap between every block, folded and unfolded: the session line, the servers, the traffic, the toggles, the
    // connect panel, and under it the same gap again (the panel stands clear of the menu)
    const gap = Gap(12);
    // the unfolded phone (the traffic in its own column) has room to spare under the servers: it goes in equal
    // shares to the three gaps under them, servers to toggles, toggles to the connect panel, the panel to the menu
    final spread = !traffic && profile != null && servers.isNotEmpty;
    Widget share() => spread ? const Spacer() : const SizedBox.shrink();
    if (theme.contrastLayout) {
      return _ContrastHome(
        superLight: superLight,
        header: header,
        banner: const Column(mainAxisSize: MainAxisSize.min, children: [PauseStrip(), UpdateBanner()]),
        // Windows without the administrator's rights: the system proxy instead of the VPN mode chosen, and a way to
        // the full one
        notice: ref.watch(tunDeniedProvider) && ref.watch(ConfigOptions.serviceMode) == ServiceMode.tun
            ? const _NoAdminNote()
            : null,
        status: _StatusBlock(status: status, lastServer: currentName, visible: visible, layout: layout),
        statusSlim: layout == HomeLayout.classic
            ? null
            : _StatusBlock(status: status, lastServer: currentName, visible: visible, layout: layout, slim: true),
        // (the super light mode has no sites: its traffic block is the servers' list)
        trafficSlim: traffic && hasList && !superLight
            ? switch (layout) {
                HomeLayout.pulse => _SiteTiles(visible: visible, compact: true, oneRow: true),
                // the dots: a few lines of names and delays before the sites go off a page too low for them
                HomeLayout.dots => const _SiteDotsCompact(),
                _ => null,
              }
            : null,
        // the vessel and the pulse keep the sites small
        compactTraffic: layout != HomeLayout.classic,
        servers: hasList
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // only the choice in use (Auto, as a rule); a tap on it brings up every country
                  SizedBox(
                    height: 68,
                    child: _StyledServerList(
                      showCurrentServer: true,
                      numberAmong: servers,
                      lead: const _BestButton(),
                      networkStyled: true,
                      mobileNetwork: actualMobile,
                      servers: [
                        servers.firstWhere(
                          (s) => s.tag == group?.selected || (s.tag == 'lowest' && group?.selected == 'balance'),
                          orElse: () => servers.first,
                        ),
                      ],
                      selectedTag: group?.selected,
                      autoNow: autoNow,
                      activeOutbound: activeOutbound,
                      testing: testing,
                      onRowTap: () => showGlassPopup(
                        context,
                        Builder(
                          builder: (popup) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(
                              height: math.min(
                                servers.length * 64.0,
                                (MediaQuery.sizeOf(context).height - 120) * .8 - 16,
                              ),
                              child: _StyledServerList(
                                servers: servers,
                                selectedTag: group?.selected,
                                autoNow: autoNow,
                                activeOutbound: activeOutbound,
                                testing: testing,
                                afterSelect: () => Navigator.of(popup).pop(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const Gap(30),
                  profile == null
                      ? _EmptyCard(text: t.avpn.noProfile)
                      : Text(
                          noServersText(t, ref.watch(vpnPauseProvider)),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                  const Gap(30),
                ],
              ),
        // Contrast: the delay to the sites the user uses most, where the traffic was (that is in Topology)
        traffic: superLight
            ? (hasList
                  ? _StyledServerList(
                      servers: servers,
                      selectedTag: group?.selected,
                      autoNow: autoNow,
                      activeOutbound: activeOutbound,
                      testing: testing,
                    )
                  : null)
            : (traffic && hasList
                  ? switch (layout) {
                      HomeLayout.pulse => _SiteTiles(visible: visible, compact: true),
                      HomeLayout.classic => _SiteTiles(visible: visible),
                      HomeLayout.bento => const _SiteBento(),
                      HomeLayout.dots => const _SiteDots(),
                    }
                  : null),
        toggles: superLight ? null : const _ConnectionsBlock(),
        togglesSlim: superLight || layout != HomeLayout.dots ? null : const _ConnectionsBlock(slim: true),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final content = Padding(
          padding: EdgeInsets.fromLTRB(18, 2, 18, spread ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusBlock(status: status, lastServer: currentName, visible: visible),
              if (hasList) ...[
                gap,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    const Gap(6),
                    SizedBox(
                      // always the same height, however many servers there are: the whitelist has fewer than the regular
                      // list, and switching between them moved everything under it (most on the unfolded phone)
                      height: rowsInSight * (62.0),
                      child: _StyledServerList(
                        servers: servers,
                        selectedTag: group?.selected,
                        autoNow: autoNow,
                        activeOutbound: activeOutbound,
                        testing: testing,
                      ),
                    ),
                  ],
                ),
                gap,
                // where the traffic went, under the servers (as on the Topology tab): always the same place and size,
                // all the room between the servers and the toggles; the unfolded phone has it in a column of its own
                if (traffic) Expanded(child: _HomeTraffic(visible: visible)) else share(),
              ] else ...[
                Gap(roomy ? 20 : 14),
                header,
                Gap(roomy ? 10 : 6),
                Expanded(
                  child: profile == null
                      ? _EmptyCard(text: t.avpn.noProfile)
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              noServersText(t, ref.watch(vpnPauseProvider)),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                ),
              ],
              // (spread: the gap under the servers is already there, before their share)
              if (!spread) gap,
              _CheckRow(onCheck: onCheck, testing: testing, showCheck: false),
              share(),
              gap,
              dock,
              if (spread) ...[share(), gap],
            ],
          ),
        );
        if (box.maxHeight >= 600) return content;
        return SingleChildScrollView(child: SizedBox(height: 600, child: content));
      },
    );
  }
}

/// "Защищено" with the time and the speed, or "Отключено".
class _StatusBlock extends HookConsumerWidget {
  const _StatusBlock({
    required this.status,
    required this.lastServer,
    required this.visible,
    this.layout = HomeLayout.classic,
    this.slim = false,
  });

  /// how the top of the home screen is laid out
  final HomeLayout layout;

  /// the smaller form of a layout's top block (for a screen that is not high enough)
  final bool slim;

  final ConnectionStatus status;
  final String? lastServer;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = status.isConnected;
    final stats = ref.watch(statsNotifierProvider).valueOrNull;
    // The native session survives a network rebuild, including its empty statistics frame.
    final confirmedStart = useRef<DateTime?>(null);
    if (!connected) {
      confirmedStart.value = null;
    } else if (stats?.sessionStartedAt case final DateTime start) {
      confirmedStart.value = start;
    }
    final now = useState(DateTime.now());
    final since = useState<DateTime?>(null);
    useEffect(() {
      if (!connected) {
        since.value = null;
        return null;
      }
      since.value ??= DateTime.now();
      if (!visible) return null;
      now.value = DateTime.now();
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => now.value = DateTime.now());
      return timer.cancel;
    }, [connected, visible]);
    final units = t.avpn.bytesUnits.split(',');
    String speed(int bytes) => '${formatBytes(bytes, units)}${t.avpn.perSecond}';
    final time = _duration(now.value.difference(confirmedStart.value ?? since.value ?? now.value));
    final down = speed(stats?.downlink.toInt() ?? 0);
    final up = speed(stats?.uplink.toInt() ?? 0);
    final waiting = switch (status) {
      Connecting() => t.avpn.connecting,
      Disconnecting() => t.avpn.disconnecting,
      _ => null,
    };

    if (theme.contrastLayout) {
      // Keep collecting daily history for Statistics; the headline uses the VPN session.
      ref.read(trafficHistoryProvider);
      // Native session totals survive configuration reloads; a new native session resets them.
      final totals = ref.watch(sessionTotalsProvider);
      final total = connected ? totals.up + totals.down : 0;
      final viaVpn = connected ? ((totals.vpnUp ?? 0) + (totals.vpnDown ?? 0)).clamp(0, total) : 0;
      (String, String) amount(int bytes, {bool perSecond = false}) {
        final parts = formatBytes(bytes, units).split(' ');
        final unit = parts.length > 1 ? parts.last : '';
        return (parts.first, perSecond ? '$unit/${t.avpn.perSecond}' : unit);
      }

      final vpn = amount(viaVpn);
      final direct = amount(total - viaVpn);
      final sessionLength = now.value.difference(confirmedStart.value ?? since.value ?? now.value);
      // the super light mode: the connection time and the two speeds (what comes in, what goes out), not the totals
      if (ref.watch(superLightProvider)) {
        final inRate = amount(connected ? stats?.downlink.toInt() ?? 0 : 0);
        final outRate = amount(connected ? stats?.uplink.toInt() ?? 0 : 0);
        // Dots: the same three figures on its dotted paper
        if (layout == HomeLayout.dots) {
          return _DotsLightStats(
            connected: connected,
            timeText: connected ? time : (waiting ?? '—'),
            down: '${inRate.$1} ${inRate.$2}/${t.avpn.perSecond}',
            up: '${outRate.$1} ${outRate.$2}/${t.avpn.perSecond}',
          );
        }
        return _ContrastStats(
          items: [
            (
              Icons.access_time_filled_rounded,
              t.avpn.contrastTime,
              connected ? time : (waiting ?? '—'),
              '',
              false,
              connected ? sessionLength.inMinutes / (24 * 60) : 0,
              const Color(0xFF8FA8BD),
            ),
            (
              Icons.south_rounded,
              t.avpn.superLightDown,
              inRate.$1,
              '${inRate.$2}/${t.avpn.perSecond}',
              true,
              0.0,
              theme.araAccent,
            ),
            (
              Icons.north_rounded,
              t.avpn.superLightUp,
              outRate.$1,
              '${outRate.$2}/${t.avpn.perSecond}',
              false,
              0.0,
              const Color(0xFF9AA0A6),
            ),
          ],
        );
      }
      final routed = total == 0 ? 1 : total;
      final vpnShare = viaVpn / routed;
      final quality = _sessionQuality(ref, connected);
      final downFigure = amount(connected ? stats?.downlink.toInt() ?? 0 : 0, perSecond: true);
      final upFigure = amount(connected ? stats?.uplink.toInt() ?? 0 : 0, perSecond: true);
      final timeFigure = connected ? time : (waiting ?? '—');
      final speedLevelNow = connected
          ? _speedLevel(math.max(stats?.downlink.toInt() ?? 0, stats?.uplink.toInt() ?? 0))
          : 0.0;
      if (layout == HomeLayout.bento) {
        return _BentoStats(
          connected: connected,
          timeText: timeFigure,
          ping: quality.ping,
          down: downFigure,
          up: upFigure,
          vpn: vpn,
          direct: direct,
          vpnShare: total == 0 ? 0 : vpnShare,
          slim: slim,
        );
      }
      if (layout == HomeLayout.dots) {
        return _DotsStats(
          connected: connected,
          paused: ref.watch(vpnPauseProvider).paused,
          timeText: timeFigure,
          ping: quality.ping,
          loss: quality.loss,
          down: downFigure,
          up: upFigure,
          vpn: vpn,
          direct: direct,
          slim: slim,
        );
      }
      if (layout == HomeLayout.pulse) {
        return _PulseStats(
          connected: connected,
          timeText: timeFigure,
          ping: quality.ping,
          loss: quality.loss,
          down: downFigure,
          up: upFigure,
          vpn: vpn,
          direct: direct,
          vpnShare: total == 0 ? 0 : vpnShare,
          speedLevel: speedLevelNow,
          slim: slim,
        );
      }
      // the two routes in one tile, the time in the middle, the speeds on the right
      return _HomeStats(
        timeText: connected ? time : (waiting ?? '—'),
        timeLevel: connected ? sessionLength.inMinutes / (24 * 60) : 0,
        vpn: vpn,
        direct: direct,
        vpnShare: total == 0 ? 0 : vpnShare,
        down: amount(connected ? stats?.downlink.toInt() ?? 0 : 0, perSecond: true),
        up: amount(connected ? stats?.uplink.toInt() ?? 0 : 0, perSecond: true),
        // the water of the speeds: from nothing at a trickle (100 КБ/с) to the top at 10 МБ/с, on a log scale
        speedLevel: connected ? _speedLevel(math.max(stats?.downlink.toInt() ?? 0, stats?.uplink.toInt() ?? 0)) : 0,
      );
    }
    if (!connected) {
      return Padding(
        padding: EdgeInsets.zero,
        child: Text(
          waiting ?? t.avpn.stTapBelow,
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
        ),
      );
    }
    final big = theme.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget item(IconData icon, String text, {Color? colour}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AraIconPaint(child: Icon(icon, size: 15, color: colour ?? scheme.onSurfaceVariant)),
        const Gap(3),
        Text(text, style: big?.copyWith(color: colour)),
      ],
    );
    // what moved today, from 03:00 to 03:00: kept across sessions, reconnects and a cleared connection list
    ref.watch(trafficHistoryProvider);
    final today = ref.read(trafficHistoryProvider.notifier).amountFrom(statsDayStart(DateTime.now()));
    final vpn = today.vpn;
    final direct = (today.total - vpn).clamp(0, 1 << 62);
    final accent = theme.araAccent;
    // one line each side, the same size and height: the time against VPN, the speed against direct
    Widget line(Widget left, Widget right) => Row(
      children: [
        Expanded(
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: left),
        ),
        const Gap(10),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: right),
      ],
    );
    return Padding(
      // no space of its own on top: the gap under the title bar matches the one above the servers
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            item(Icons.schedule_rounded, time, colour: scheme.primary),
            item(
              Icons.shield_rounded,
              'VPN ${formatBytes(vpn, units)}',
              colour: AraLook.readableOn(accent, scheme.surface),
            ),
          ),
          line(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [item(Icons.south_rounded, down), const Gap(10), item(Icons.north_rounded, up)],
            ),
            item(Icons.alt_route_rounded, '${t.avpn.homeBypass} ${formatBytes(direct, units)}'),
          ),
        ],
      ),
    );
  }
}

/// "СЕРВЕРЫ · Sigma · 23 дн." with the subscription's refresh, and the ping check.
class _ServersHeader extends ConsumerWidget {
  const _ServersHeader({required this.profile, required this.testing, this.onCheck, this.showCheck = true});

  /// the ping check at the end (Graphite has it in the connect panel)
  final bool showCheck;

  final ProfileEntity? profile;
  final bool testing;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remote = profile is RemoteProfileEntity ? profile! as RemoteProfileEntity : null;
    final sub = remote?.subInfo;
    final info = [
      if (profile != null) sigmaName(profile!.name),
      if (sub != null) sub.isExpired ? t.avpn.expired : t.avpn.daysShort(days: sub.remaining.inDays),
    ].join(' · ');
    final label = theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w800, fontSize: 11);

    final row = Row(
      children: [
        Text(t.avpn.stServers.toUpperCase(), style: label?.copyWith(color: scheme.onSurface)),
        if (info.isNotEmpty)
          Flexible(
            flex: 100,
            child: Text(
              '  ·  ${info.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: label?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        const Spacer(),
        if (showCheck)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: testing ? null : onCheck,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  if (testing)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: scheme.primary),
                    )
                  else
                    Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: onCheck == null ? scheme.onSurfaceVariant : scheme.primary,
                    ),
                  const Gap(4),
                  Text(
                    (t.avpn.stPing).toUpperCase(),
                    style: label?.copyWith(color: onCheck == null ? scheme.onSurfaceVariant : scheme.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return row;
  }
}

class _StyledServerList extends ConsumerWidget {
  const _StyledServerList({
    required this.servers,
    required this.selectedTag,
    required this.autoNow,
    required this.activeOutbound,
    required this.testing,
    this.onRowTap,
    this.afterSelect,
    this.showCurrentServer = false,
    this.networkStyled = false,
    this.mobileNetwork = false,
    this.lead,
    this.numberAmong,
  });

  /// the servers that count when the same country comes more than once (the one-row panel holds one server, the numbers
  /// still go by the whole list)
  final List<OutboundInfo>? numberAmong;

  /// the current server's button, at the left of its row (see [showCurrentServer])
  final Widget? lead;

  /// a tap on a row does this instead of choosing it (Contrast's one row opens the list)
  final VoidCallback? onRowTap;

  /// after a row is chosen (the list in a sheet closes)
  final VoidCallback? afterSelect;

  /// In Contrast's one-row home panel, show the currently used country and protocol instead of "Auto".
  final bool showCurrentServer;

  /// The home panel uses a white Wi-Fi surface and a softly tinted LTE surface.
  final bool networkStyled;
  final bool mobileNetwork;

  final List<OutboundInfo> servers;
  final String? selectedTag;
  final OutboundInfo? autoNow;
  final OutboundInfo? activeOutbound;
  final bool testing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // the marks of the subscriptions (their names are in the rows' captions)
    ref.watch(profileBadgesProvider);
    final list = LayoutBuilder(
      builder: (context, box) {
        // the current server's own row (Dots) is as high as the room it is given, a list's rows are 62
        final base = showCurrentServer ? math.max(62.0, box.maxHeight) : 62.0;
        final room = box.maxHeight;
        final rows = (room / base).floor().clamp(1, 1000);
        // whole rows only: they stretch a little so the last one in view isn't cut in half
        final extent = servers.length <= rows ? base : room / rows;
        return ListView.builder(
          itemExtent: extent,
          padding: EdgeInsets.zero,
          itemCount: servers.length,
          itemBuilder: (context, i) {
            final server = servers[i];
            final selected = server.tag == selectedTag || (server.tag == 'lowest' && selectedTag == 'balance');
            final auto = server.tag == 'lowest' || server.tag == 'balance';
            final currentServer = auto && showCurrentServer ? autoNow : null;
            final displayedServer = currentServer ?? server;
            final name = serverName(displayedServer);
            // "Финляндия" with "VLESS" under it, rather than "Sigma - Финляндия"
            final dash = name.title.indexOf(' - ');
            // a note in brackets at the end ("Финляндия (Тестовый)") goes to the line under: "Тестовый · Sigma · VLESS"
            final full = _marked(dash < 0 ? name.title : name.title.substring(dash + 3).trim(), name.title);
            final note = RegExp(r'\s*\(([^()]*)\)$').firstMatch(full);
            final baseTitle = currentServer != null
                ? (note == null ? full : full.substring(0, note.start).trim())
                // Auto is named as Auto, the server it is on now under it
                : (auto ? t.avpn.auto : (note == null ? full : full.substring(0, note.start).trim()));
            // the same country of one provider more than once: the first is plain, the next ones are 2, 3…
            final ordinal = server.isGroup && currentServer == null
                ? 1
                : _ordinalOf(displayedServer, numberAmong ?? servers);
            final title = ordinal > 1 ? '$baseTitle $ordinal' : baseTitle;
            // with several subscriptions in the work: whose server it is, in a word (SIGMA, CHILL, PHANTOM)
            final provider = _providerWord(displayedServer.tag);
            // the provider's own class word ("Доступ") says nothing next to the provider's name
            final klass = dash > 0 ? name.title.substring(0, dash).trim() : null;
            final showClass = klass != null && !(provider != null && klass.toLowerCase() == 'доступ');
            final subtitle = currentServer != null
                ? [
                    ?provider,
                    if (note != null) note[1]!,
                    if (showClass) klass,
                    currentServer.type.toUpperCase(),
                  ].join(' · ')
                : auto
                ? (autoNow == null ? t.avpn.autoBestHint : '${t.avpn.stNow}: ${_withFlag(serverName(autoNow!))}')
                : [?provider, if (note != null) note[1]!, if (showClass) klass, server.type.toUpperCase()].join(' · ');
            void select() {
              ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy("select", server.tag);
              afterSelect?.call();
            }

            return _GraphiteRow(
              flag: server.isGroup && currentServer == null ? null : name.flag,
              profile: server.isGroup && currentServer == null ? -1 : name.profile,
              group: server.isGroup && currentServer == null,
              title: title,
              subtitle: subtitle,
              delay: displayedHomePingDelay(server, autoNow: autoNow, active: activeOutbound, selected: selected),
              selected: selected,
              networkStyled: networkStyled,
              mobileNetwork: mobileNetwork,
              testing: testing,
              first: i == 0,
              onTap: onRowTap ?? select,
              // the single-row panel always has it, Auto or a server chosen by hand
              lead: showCurrentServer ? lead : null,
              // the home screen's row is the bolt and the country, no ping (it is in the list that opens, and in super light)
              pingShown: !showCurrentServer,
            );
          },
        );
      },
    );
    // the rows on the page itself, no card round them
    return list;
  }
}

/// Which of the servers of one provider with the same country name this one is (1 for the first): a country comes plain once, and
/// as 1 (plain), 2, 3 in the order the list has them when it comes more than once.
int _ordinalOf(OutboundInfo server, List<OutboundInfo> among) {
  final me = serverName(server);
  var total = 0;
  var seen = 0;
  var position = 1;
  for (final other in among) {
    if (other.isGroup) continue;
    final name = serverName(other);
    if (name.profile != me.profile || name.title.toLowerCase() != me.title.toLowerCase()) continue;
    total++;
    seen++;
    if (other.tag == server.tag) position = seen;
  }
  return total > 1 ? position : 1;
}

/// The word that names the subscription a server is from, when more than one is in the work: the first word of its name,
/// in capitals, at most eight letters (Sigma, ChillGuy, Phantom); null with one subscription.
String? _providerWord(String tag) {
  final index = profileOfTag(tag);
  if (index < 0 || index >= profileBadgesNow.length) return null;
  final words = profileBadgesNow[index].name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return null;
  final word = words.first.toUpperCase();
  return word.length > 8 ? word.substring(0, 8) : word;
}

/// Contrast's home: on the upper zone (its light behind the app bar too: [ContrastGlow]) the session, the servers,
/// the traffic and the toggles, each a block of its own; then a black panel holding the connect control only, with
/// a tab on its top edge that brings the connections in.
class _ContrastHome extends ConsumerWidget {
  const _ContrastHome({
    this.togglesSlim,
    required this.header,
    required this.status,
    required this.servers,
    required this.traffic,
    required this.toggles,
    this.notice,
    this.banner,
    this.superLight = false,
    this.compactTraffic = false,
    this.statusSlim,
    this.trafficSlim,
  });

  /// smaller forms of the top block and of the sites' block, taken in turn when the whole ones don't fit the height
  final Widget? statusSlim;

  /// the connections block in one line (Dots), taken before the block goes off a page that is too low
  final Widget? togglesSlim;
  final Widget? trafficSlim;

  /// the traffic block holds only what it needs (the rest of the room is left under it)
  final bool compactTraffic;

  /// "Серверы · Sigma · 23 дн. · Обновить", over the blocks
  final Widget header;

  /// a note over the blocks (Windows without the administrator's rights)
  final Widget? notice;

  /// the program's update, a thin strip over the blocks
  final Widget? banner;
  final Widget status;
  final Widget servers;
  final Widget? traffic;
  final Widget? toggles;

  /// the super light mode: no swipes to the pages that are off
  final bool superLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // the big ping block opens the session's traffic (it came down from the top with a swipe); the swipe down now pings
    // every server, as the check button does (Settings are on the cog; the super light mode keeps its swipe to them)
    Widget opensTraffic(Widget block) => superLight || homeLookNow == HomeLayout.dots
        ? block
        : GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => context.goNamed('traffic'), child: block);
    return _LongSwipe(
      // down: a ping of everything; up: the day's connections come up from the panel
      onDown: () => superLight ? context.goNamed('settings') : unawaited(pingAllServers(ref)),
      onUp: () {
        if (!superLight) context.goNamed('connections');
      },
      child: LayoutBuilder(
        // a short screen: no room for the traffic block (it's on the Statistics tab)
        builder: (context, box) {
          // the super light mode: the time and the speed on top, the servers with their pings in all the room there is, and the way
          // back to everything at the bottom
          if (superLight) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: header),
                  if (banner != null) banner!,
                  if (notice != null) ...[_ContrastBlock(child: notice!), const Gap(10)],
                  _ContrastBlock(child: opensTraffic(status)),
                  const Gap(10),
                  Expanded(
                    child: traffic == null ? const SizedBox.shrink() : _ContrastBlock(expand: true, child: traffic!),
                  ),
                  const Gap(10),
                  const _SuperLightOff(),
                ],
              ),
            );
          }
          final minimum = ContrastShellDock.sideways(context) ? 520.0 : (box.maxWidth > box.maxHeight ? 380.0 : 440.0);
          // the compact layouts: what room is left is shared in equal gaps between the blocks, and the last block's
          // distance from the panel's tab is one of them (the tab's top edge is where the page ends)
          final evenly = compactTraffic && traffic != null;
          // a wide low screen (a car's, the phone turned): two columns that always fit, the ping on the left, the servers
          // and the sites' delays on the right, the connect control at the side (nothing to scroll to)
          if (evenly && ContrastShellDock.sideways(context) && box.maxWidth >= 520) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 6), child: header),
                  if (banner != null) banner!,
                  if (notice != null) ...[_ContrastBlock(child: notice!), const Gap(8)],
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: FitBlocks(
                            minGap: 8,
                            steps: [
                              if (statusSlim != null) (group: 1, rank: 1),
                              if (toggles != null) (group: 2, rank: -1),
                            ],
                            children: [
                              FitSlot(group: 0, child: const SizedBox.shrink()),
                              FitSlot(group: 1, child: _ContrastBlock(child: opensTraffic(status))),
                              if (statusSlim != null)
                                FitSlot(group: 1, rank: 1, child: _ContrastBlock(child: opensTraffic(statusSlim!))),
                              if (toggles != null) FitSlot(group: 2, child: _ContrastBlock(child: toggles!)),
                            ],
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          flex: 6,
                          child: FitBlocks(
                            minGap: 8,
                            steps: [
                              if (trafficSlim != null) (group: 2, rank: 1),
                              if (trafficSlim != null) (group: 2, rank: 2),
                              (group: 2, rank: -1),
                            ],
                            children: [
                              FitSlot(group: 0, child: const SizedBox.shrink()),
                              if (!superLight) FitSlot(group: 1, child: _ContrastBlock(child: servers)),
                              FitSlot(group: 2, child: _ContrastBlock(child: traffic!)),
                              if (trafficSlim != null)
                                FitSlot(group: 2, rank: 1, child: _ContrastBlock(child: trafficSlim!)),
                              if (trafficSlim != null) FitSlot(group: 2, rank: 2, child: const _SiteStrip()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          if (evenly) {
            // the blocks always fit: when they don't all, the connections go, then the sites get down to one row, then the
            // top block loses its second row, and last the sites go too; the room left is shared in equal gaps
            final withToggles = toggles != null && !ContrastShellDock.sideways(context);
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: LayoutBuilder(
                builder: (context, fit) => FitBlocks(
                  minGap: homeLookNow == HomeLayout.dots ? 6 : 10,
                  // Bento on a tall screen: the gaps stay slim, the hero and the sites tiles grow into the room
                  maxGap: homeLookNow == HomeLayout.bento ? 18 : null,
                  steps: const [
                    (group: 4, rank: 1),
                    (group: 4, rank: -1),
                    (group: 3, rank: 1),
                    (group: 1, rank: 1),
                    (group: 3, rank: 2),
                    (group: 3, rank: -1),
                  ],
                  children: [
                    FitSlot(
                      group: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: header),
                          if (banner != null) banner!,
                          if (notice != null) ...[_ContrastBlock(child: notice!), const Gap(10)],
                        ],
                      ),
                    ),
                    FitSlot(
                      group: 1,
                      grow: homeLookNow == HomeLayout.bento ? 3 : 0,
                      child: _ContrastBlock(child: opensTraffic(status)),
                    ),
                    if (statusSlim != null)
                      FitSlot(group: 1, rank: 1, child: _ContrastBlock(child: opensTraffic(statusSlim!))),
                    if (!superLight) FitSlot(group: 2, child: _ContrastBlock(child: servers)),
                    FitSlot(
                      group: 3,
                      grow: homeLookNow == HomeLayout.bento ? 2 : 0,
                      child: _ContrastBlock(child: traffic!),
                    ),
                    if (trafficSlim != null) FitSlot(group: 3, rank: 1, child: _ContrastBlock(child: trafficSlim!)),
                    if (trafficSlim != null) FitSlot(group: 3, rank: 2, child: const _SiteStrip()),
                    if (withToggles) FitSlot(group: 4, child: _ContrastBlock(child: toggles!)),
                    if (withToggles && togglesSlim != null)
                      FitSlot(group: 4, rank: 1, child: _ContrastBlock(child: togglesSlim!)),
                  ],
                ),
              ),
            );
          }
          Widget between() => evenly ? const Spacer() : const Gap(14);
          final content = Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, evenly ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: header),
                // the blocks a little apart (14, was 8)
                if (banner != null) banner!,
                if (notice != null) ...[_ContrastBlock(child: notice!), const Gap(14)],
                _ContrastBlock(child: opensTraffic(status)),
                between(),
                // the super light mode: the servers' list below holds the one in use, so not twice
                if (!superLight) ...[_ContrastBlock(child: servers), between()],
                if (traffic != null && compactTraffic)
                  _ContrastBlock(child: traffic!)
                else if (traffic != null)
                  Expanded(child: _ContrastBlock(expand: true, child: traffic!))
                else
                  const Spacer(),
                // a short screen (the phone turned): the toggles are under the connect control at the side
                if (toggles != null && !ContrastShellDock.sideways(context)) ...[
                  between(),
                  _ContrastBlock(child: toggles!),
                ],
                if (evenly) const Spacer(),
              ],
            ),
          );
          if (box.maxHeight >= minimum) return content;
          return SingleChildScrollView(
            child: SizedBox(height: minimum, child: content),
          );
        },
      ),
    );
  }
}

/// The super light mode's plaque at the bottom of the home screen: one tap and everything is back.
class _SuperLightOff extends ConsumerWidget {
  const _SuperLightOff();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final dots = ref.watch(Preferences.homeLayout) == HomeLayout.dots;
    final dark = theme.brightness == Brightness.dark;
    final row = Row(
      children: [
        Icon(Icons.eco_rounded, size: 22, color: dots ? _Dots.ink(dark) : theme.araAccent),
        const Gap(12),
        Expanded(
          child: Text(
            dots ? t.avpn.superLightOff.toUpperCase() : t.avpn.superLightOff,
            style: dots
                ? _Dots.mono(13, _Dots.ink(dark), weight: FontWeight.w800, spacing: 1.2)
                : theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Icon(
          Icons.power_settings_new_rounded,
          size: 22,
          color: dots ? _Dots.soft(dark) : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
    return Semantics(
      key: const ValueKey('super-light-off'),
      button: true,
      label: t.avpn.superLightOff,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(Preferences.superLight.notifier).update(false),
        child: dots
            ? _dotPaper(context, row, padding: const EdgeInsets.fromLTRB(16, 14, 16, 14))
            : _ContrastBlock(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), child: row),
              ),
      ),
    );
  }
}

/// Windows without the administrator's rights: the VPN mode (a TUN adapter) can't start, so the system proxy runs
/// instead; the button starts the app again with the rights (Windows asks).
class _NoAdminNote extends ConsumerWidget {
  const _NoAdminNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, size: 22, color: theme.araIcon),
          const Gap(10),
          Expanded(child: Text(t.avpn.noAdminNote, style: theme.textTheme.bodySmall?.copyWith(height: 1.3))),
          const Gap(8),
          FilledButton.tonal(
            onPressed: () async {
              if (await WindowsElevation.relaunchElevated()) await ref.read(windowNotifierProvider.notifier).exit();
            },
            child: Text(t.avpn.noAdminRestart),
          ),
        ],
      ),
    );
  }
}

/// A short vertical swipe, down or up: past a twelfth of the height, or a flick. Down it is drawn as a pull to refresh:
/// the page follows the finger a little way down, a refresh sign over it turns as it is pulled, and once it takes the
/// sign spins while the page waits, then both go back.
class _LongSwipe extends HookWidget {
  const _LongSwipe({required this.child, required this.onDown, required this.onUp});

  final Widget child;
  final VoidCallback onDown;
  final VoidCallback onUp;

  /// how far the page may be pulled down (a share of the screen's height), and how much of the finger's way it follows
  static const _reachShare = .30;
  static const _follow = .9;

  @override
  Widget build(BuildContext context) {
    final drag = useRef(0.0);
    final pull = useState(0.0);
    final dragging = useState(false);
    final refreshing = useState(false);
    final spin = useAnimationController(duration: const Duration(milliseconds: 800));
    // a computer goes by its menu, not by dragging the mouse; the super light mode has no swipes at all
    if (PlatformUtils.isDesktop || superLightNow) return child;
    final need = MediaQuery.sizeOf(context).height / 12;
    final reach = MediaQuery.sizeOf(context).height * _reachShare;
    final progress = refreshing.value ? 1.0 : (drag.value / need).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final lit = refreshing.value || (dragging.value && drag.value > need);
    final signColour = lit
        ? (homeLookNow == HomeLayout.dots ? _Dots.red : theme.colorScheme.primary)
        : theme.colorScheme.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) {
        drag.value = 0;
        dragging.value = true;
      },
      onVerticalDragUpdate: (d) {
        drag.value += d.primaryDelta ?? 0;
        if (!refreshing.value) pull.value = (drag.value * _follow).clamp(0.0, reach);
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        dragging.value = false;
        if (drag.value > need || (drag.value > 16 && velocity > 700)) {
          onDown();
          // the page waits a moment under the turning sign, then goes back
          refreshing.value = true;
          pull.value = reach * .55;
          spin.repeat();
          Future<void>.delayed(const Duration(milliseconds: 1400), () {
            if (!context.mounted) return;
            spin.stop();
            refreshing.value = false;
            pull.value = 0;
          });
        } else {
          pull.value = 0;
          if (drag.value < -need || (drag.value < -16 && velocity < -700)) onUp();
        }
        drag.value = 0;
      },
      onVerticalDragCancel: () {
        dragging.value = false;
        if (!refreshing.value) pull.value = 0;
        drag.value = 0;
      },
      child: Stack(
        // the page keeps the size it had (tight to the screen)
        fit: StackFit.expand,
        children: [
          // the sign in the room the page leaves at the top (under the status bar)
          Positioned(
            top: MediaQuery.paddingOf(context).top + pull.value * .35 - 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: pull.value <= 0 ? 0 : (pull.value / 30).clamp(0.0, 1.0),
                  child: AnimatedBuilder(
                    animation: spin,
                    builder: (context, _) => Transform.rotate(
                      angle: refreshing.value ? spin.value * 2 * math.pi : progress * math.pi * 1.6,
                      child: Icon(Icons.refresh_rounded, size: 26, color: signColour),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            // following the finger it is immediate; let go, it settles
            duration: dragging.value ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, pull.value, 0),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// The arcs' target: [next] when the arcs are to move to it (off, or switching, or a change of at least 10% of the arc
/// in either and ten seconds since they last moved), else where they already head.
Offset _headingFor(ObjectRef<Offset> heading, ObjectRef<DateTime> moved, Offset next) {
  final now = heading.value;
  final far = (next.dx - now.dx).abs() >= .1 || (next.dy - now.dy).abs() >= .1;
  final due = DateTime.now().difference(moved.value) >= const Duration(seconds: 10);
  if (next == Offset.zero || now == Offset.zero || (far && due)) {
    heading.value = next;
    moved.value = DateTime.now();
  }
  return heading.value;
}

/// [v] in steps of 2% (0 to 1).
double _step(double v) => v.isFinite ? (v * 50).round() / 50 : 0;

/// 70% of how wide [text] is in [style]: the room given on the left to a figure with a unit written after it. Fully
/// centred without the unit the figure looked pushed to the right (the unit's weight is on that side); with the
/// unit counted too it sat plainly to the left; a little left of the middle looks centred.
double _textWidth(String text, TextStyle style) =>
    (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout()).width *
    .7;
