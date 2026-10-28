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
    // how the blocks are laid out (the super light mode has its own look)
    final layout = superLight ? HomeLayout.classic : ref.watch(Preferences.homeLayout);
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
        // Windows without the administrator's rights: the system proxy instead of the VPN mode chosen, and a way to
        // the full one
        notice: ref.watch(tunDeniedProvider) && ref.watch(ConfigOptions.serviceMode) == ServiceMode.tun
            ? const _NoAdminNote()
            : null,
        status: _StatusBlock(status: status, lastServer: currentName, visible: visible, layout: layout),
        // the vessel and the pulse keep the sites small
        compactTraffic: layout == HomeLayout.vessel || layout == HomeLayout.pulse,
        servers: hasList
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // only the choice in use (Auto, as a rule); a tap on it brings up every country
                  SizedBox(
                    height: 64,
                    child: _StyledServerList(
                      showCurrentServer: true,
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
                          t.avpn.connectToSeeServers,
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
                      HomeLayout.vessel => const _SiteBars(),
                      HomeLayout.pulse => _SiteTiles(visible: visible, compact: true),
                      HomeLayout.classic => _SiteTiles(visible: visible),
                    }
                  : null),
        toggles: superLight ? null : const _ConnectionsBlock(),
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
                              t.avpn.connectToSeeServers,
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
  });

  /// how the top of the home screen is laid out
  final HomeLayout layout;

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
            (Icons.south_rounded, t.avpn.superLightDown, inRate.$1, '${inRate.$2}/${t.avpn.perSecond}', true, 0.0, theme.araAccent),
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
      final speedLevelNow = connected ? _speedLevel(math.max(stats?.downlink.toInt() ?? 0, stats?.uplink.toInt() ?? 0)) : 0.0;
      if (layout == HomeLayout.vessel) {
        return _VesselStats(
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
  });

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
    final list = LayoutBuilder(
      builder: (context, box) {
        final base = 62.0;
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
            final title = currentServer != null
                ? (note == null ? full : full.substring(0, note.start).trim())
                : (auto ? t.avpn.server : (note == null ? full : full.substring(0, note.start).trim()));
            final subtitle = currentServer != null
                ? [
                    if (note != null) note[1]!,
                    if (dash > 0) name.title.substring(0, dash).trim(),
                    currentServer.type.toUpperCase(),
                  ].join(' · ')
                : auto
                ? (autoNow == null ? t.avpn.autoBestHint : '${t.avpn.stNow}: ${_withFlag(serverName(autoNow!))}')
                : [
                    if (note != null) note[1]!,
                    if (dash > 0) name.title.substring(0, dash).trim(),
                    server.type.toUpperCase(),
                  ].join(' · ');
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
            );
          },
        );
      },
    );
    // the rows on the page itself, no card round them
    return list;
  }
}

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
                          : Text(flag ?? '🌐', style: const TextStyle(fontSize: 28, fontFamilyFallback: ['Emoji'])),
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
    );
    final iconSize = (large ? 28.0 : 26.0) * (theme.contrastLayout ? 1.05 : 1);
    // no plates: an icon (or a number) over a small caption, pressed as one
    // on a barely-there plate, as the toggles above
    // Contrast: the ping and the servers' figures in the ping frame's colour (their signs in the text colour), the
    // loss in its frame's grey
    final contrastOn = theme.contrastLayout && on;
    final gaugeInk = contrastOn ? accent : ink;
    final lossInk = dark ? const Color(0xFFA3A9B0) : const Color(0xFF8C939C);
    Widget side({required Widget top, required String label, VoidCallback? onTap, Color? labelColor}) => Material(
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
                Text(label, style: labelColor == null ? caption : caption?.copyWith(color: labelColor)),
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
                  : theme.contrastLayout
                  // Contrast: the ping here, as the servers answering are on the right: the sign and the figure
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.network_ping_rounded, size: iconSize, color: contrastOn ? scheme.onSurface : ink),
                        const Gap(6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: on && measured && !busy ? '$ping' : '—'),
                              if (on && measured && !busy)
                                TextSpan(
                                  text: ' ms',
                                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1,
                            fontSize: sideFigure,
                            color: contrastOn && measured && !busy ? gaugeInk : null,
                          ),
                        ),
                      ],
                    )
                  : Icon(Icons.network_ping_rounded, size: iconSize, color: ink),
              // Contrast: the loss under it while measured
              label: theme.contrastLayout && on && measured && !busy
                  ? t.avpn.dockLoss(loss: lossText)
                  : t.avpn.stPingButton,
              labelColor: theme.contrastLayout && on && measured && !busy ? lossInk : null,
              onTap: on && !busy && !testing ? onCheck : null,
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
                  top: Row(
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
                          color: contrastOn ? gaugeInk : null,
                        ),
                      ),
                    ],
                  ),
                  label: t.avpn.dockActive,
                  // the answering servers in a compact list, the fastest first; one tapped is chosen
                  onTap: on && answering > 0
                      ? () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          // 30% lower than it was
                          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .42),
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

/// The servers answering their ping, the fastest first, compact: a flag, the name and the ping on one line each.
/// Tapping one chooses it (the Auto group stops choosing for you) and closes the list.
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
          // at the top of the list, a pull down anywhere on it closes the sheet
          child: NotificationListener<OverscrollNotification>(
            onNotification: (n) {
              if (n.overscroll < -4 && n.dragDetails != null && n.metrics.pixels <= n.metrics.minScrollExtent) {
                Navigator.of(context).maybePop();
                return true;
              }
              return false;
            },
            child: ListView.builder(
              shrinkWrap: true,
              // the pull down at its top reaches the listener above (no bouncing on any platform)
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: servers.length,
              itemBuilder: (context, i) {
                final server = servers[i];
                final name = serverName(server);
                final chosen = server.tag == selected;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  selected: chosen,
                  selectedTileColor: scheme.primary.withValues(alpha: .12),
                  leading: FlagBadge(
                    profile: name.profile,
                    child: Text(name.flag ?? '🌐', style: const TextStyle(fontSize: 22, fontFamilyFallback: ['Emoji'])),
                  ),
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
        ),
      ],
    );
  }
}

/// Contrast's home: on the upper zone (its light behind the app bar too: [ContrastGlow]) the session, the servers,
/// the traffic and the toggles, each a block of its own; then a black panel holding the connect control only, with
/// a tab on its top edge that brings the connections in.
class _ContrastHome extends StatelessWidget {
  const _ContrastHome({
    required this.header,
    required this.status,
    required this.servers,
    required this.traffic,
    required this.toggles,
    this.notice,
    this.superLight = false,
    this.compactTraffic = false,
  });

  /// the traffic block holds only what it needs (the rest of the room is left under it)
  final bool compactTraffic;

  /// "Серверы · Sigma · 23 дн. · Обновить", over the blocks
  final Widget header;

  /// a note over the blocks (Windows without the administrator's rights)
  final Widget? notice;
  final Widget status;
  final Widget servers;
  final Widget? traffic;
  final Widget? toggles;

  /// the super light mode: no swipes to the pages that are off
  final bool superLight;

  @override
  Widget build(BuildContext context) {
    return _LongSwipe(
      // down: the session's traffic comes down from the top (Settings are on the cog); up: the day's connections
      // come up from the panel
      onDown: () => superLight ? context.goNamed('settings') : context.goNamed('traffic'),
      onUp: () {
        if (!superLight) context.goNamed('connections');
      },
      child: LayoutBuilder(
        // a short screen: no room for the traffic block (it's on the Statistics tab)
        builder: (context, box) {
          final minimum = box.maxWidth > box.maxHeight ? 380.0 : 440.0;
          // the compact layouts: what room is left is shared in equal gaps between the blocks, and the last block's
          // distance from the panel's tab is one of them (the tab's top edge is where the page ends)
          final evenly = compactTraffic && traffic != null;
          Widget between() => evenly ? const Spacer() : const Gap(14);
          final content = Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, evenly ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: header),
                // the blocks a little apart (14, was 8)
                if (notice != null) ...[_ContrastBlock(child: notice!), const Gap(14)],
                _ContrastBlock(child: status),
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
                if (toggles != null && !ContrastShellDock.sideways(context)) ...[between(), _ContrastBlock(child: toggles!)],
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

/// A short vertical swipe, down or up: past a twelfth of the height, or a flick.
class _LongSwipe extends HookWidget {
  const _LongSwipe({required this.child, required this.onDown, required this.onUp});

  final Widget child;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final drag = useRef(0.0);
    // a computer goes by its menu, not by dragging the mouse; the super light mode has no swipes at all
    if (PlatformUtils.isDesktop || superLightNow) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => drag.value = 0,
      onVerticalDragUpdate: (d) => drag.value += d.primaryDelta ?? 0,
      onVerticalDragEnd: (details) {
        final need = MediaQuery.sizeOf(context).height / 12;
        final velocity = details.primaryVelocity ?? 0;
        if (drag.value > need || (drag.value > 16 && velocity > 700)) {
          onDown();
        } else if (drag.value < -need || (drag.value < -16 && velocity < -700)) {
          onUp();
        }
        drag.value = 0;
      },
      child: child,
    );
  }
}

/// Contrast's panel at the bottom of every page (the shell keeps it): white by day, black by night, the connect
/// control on it and the "Серверы VPN" tab on its top edge.
class ContrastShellDock extends HookConsumerWidget {
  const ContrastShellDock({super.key, this.side = false});

  /// a column at the right of the page (a short screen: the phone turned), not a panel under it
  final bool side;

  /// a screen too low for the panel under the page (the folded phone turned)
  static bool sideways(BuildContext context) => MediaQuery.sizeOf(context).height < 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final testing = useValueListenable(homePingTesting);
    final status = ref.watch(shownConnectionProvider);
    final networkKind = useListenable(_actualNetworkKind).value;
    final dock = _GraphiteDock(
      status: status,
      server: null,
      actualMobile: networkKind == NetworkKind.mobile,
      networkKnown: networkKind != NetworkKind.unknown,
      testing: testing,
      onCheck: () => pingAllServers(ref),
      large: !side && MediaQuery.sizeOf(context).height >= 900,
    );
    if (side) {
      // a column at the right: the tab at its top, the connect control in the middle
      return Theme(
        data: contrastPanelTheme(theme),
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          decoration: BoxDecoration(
            color: contrastPanelColor(dark),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
            border: dark ? Border(left: BorderSide(color: Colors.white.withValues(alpha: .08))) : null,
            boxShadow: dark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 30, offset: const Offset(-6, 0))],
          ),
          child: Column(
            children: [
              _SeamTab(label: t.avpn.contrastServersTab),
              Expanded(child: Center(child: dock)),
              // the home screen's toggles, here where there's room
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: _CheckRow(onCheck: () => pingAllServers(ref), testing: testing, showCheck: false),
              ),
            ],
          ),
        ),
      );
    }
    return Theme(
      data: contrastPanelTheme(theme),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(top: _SeamTab.overhang),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            decoration: BoxDecoration(
              color: contrastPanelColor(dark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: dark ? Border(top: BorderSide(color: Colors.white.withValues(alpha: .08))) : null,
              boxShadow: dark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .07),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                    ],
            ),
            child: dock,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(child: _SeamTab(label: t.avpn.contrastServersTab)),
          ),
        ],
      ),
    );
  }
}

/// Contrast's backdrop behind a page, behind the app bar too: the kind and the colours chosen in Settings →
/// Themes, laid out at random once when the app starts (the same on every page until it's closed). Inside another
/// one it draws nothing of its own.
class ContrastGlow extends ConsumerStatefulWidget {
  const ContrastGlow({super.key, required this.child, this.page = '', this.own = false, this.muted = false});

  final Widget child;

  /// a page with text right on the backdrop (the settings' sections, the profiles): the backdrop toned down under
  /// a veil of the page colour, so the text reads over the bright stripes
  final bool muted;

  /// the veil over a muted page's backdrop
  static Color veil(bool dark) => ContrastColours.active.page(dark).withValues(alpha: .78);

  /// draws its own backdrop inside another one too: a page sliding over another carries its own, so the one under
  /// it doesn't show through
  final bool own;

  /// the page it's behind (the backdrop is the same on every page)
  final String page;

  @override
  ConsumerState<ContrastGlow> createState() => _ContrastGlowState();
}

class _ContrastGlowState extends ConsumerState<ContrastGlow> {
  @override
  Widget build(BuildContext context) {
    if (!widget.own && context.findAncestorStateOfType<_ContrastGlowState>() != null) return widget.child;
    final brightness = Theme.of(context).brightness;
    final palette = ref.watch(contrastColoursProvider);
    // the light look: no picture behind, the page's colour (nothing to draw, nothing kept in memory)
    if (ref.watch(lightLookProvider)) {
      return _GlowAnchor(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: ColoredBox(color: palette.page(brightness == Brightness.dark))),
            widget.child,
          ],
        ),
      );
    }
    final layout = ref.watch(contrastBackdropLayoutProvider);
    // the settings not read yet (the first frames): the defaults
    final ready = ref.watch(sharedPreferencesProvider).hasValue;
    final (warm, cool) = palette.backdrop(brightness);
    final area = contrastImageArea(MediaQuery.sizeOf(context));
    // the picture at the screen's sharpness, two pixels a point at most (blurrier lines aren't seen, memory is)
    final scale = math.min(MediaQuery.devicePixelRatioOf(context), PlatformUtils.isDesktop ? 1.25 : 2.0);
    ui.Image picture(int seed) => ContrastBackdropImage.of(
      kind: ready ? ref.watch(Preferences.contrastBackdrop) : ContrastBackdrop.fallback,
      warm: warm,
      cool: cool,
      dark: brightness == Brightness.dark,
      // laid out on the screen, so every page's lines up with the rest
      area: area,
      scale: scale,
      seed: seed,
      page: palette.page(brightness == Brightness.dark),
      glass: palette.glass(brightness),
    );
    final image = picture(layout.seed);
    final previous = layout.previous == layout.seed ? null : picture(layout.previous);
    return _GlowAnchor(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: ContrastImagePainter(image, scale, previous: previous)),
            ),
          ),
          if (widget.muted) Positioned.fill(child: ColoredBox(color: ContrastGlow.veil(brightness == Brightness.dark))),
          widget.child,
        ],
      ),
    );
  }
}

/// The area Contrast's backdrop and frost pictures are laid out on: the screen's; a computer's window rounded up to
/// the next 96 points, so dragging its edge doesn't draw both pictures afresh at every step (that stuttered)
Size contrastImageArea(Size screen) =>
    PlatformUtils.isDesktop ? Size((screen.width / 96).ceil() * 96.0, (screen.height / 96).ceil() * 96.0) : screen;

/// A block on Contrast's upper zone: a pane of frosted glass, what's behind it blurred.
class _ContrastBlock extends StatelessWidget {
  const _ContrastBlock({required this.child, this.expand = false});

  final Widget child;

  /// the child takes the block's height (the traffic)
  final bool expand;

  @override
  Widget build(BuildContext context) => ContrastFrost(child: child);
}

/// Contrast's frosted glass: the backdrop behind it blurred, a light tint and a bright edge. The blur is the
/// backdrop's picture blurred once ([ContrastFrostImage]), its part under the block shown, not a live blur on every
/// frame.
class ContrastFrost extends ConsumerWidget {
  const ContrastFrost({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(8),
    this.solo = false,
  });

  /// a card with nothing of its own inside (another page's): a little denser, as the home block with its tiles
  final bool solo;

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // how see-through, as chosen in Settings → Themes
    final clarity = ref.watch(sharedPreferencesProvider).hasValue
        ? ref.watch(Preferences.contrastClarity)
        : ContrastClarity.fallback;
    // the light look: a plain pane, nothing frosted behind it
    if (ref.watch(lightLookProvider)) {
      return RepaintBoundary(
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ContrastColours.of(context).pane(dark),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: .12) : Colors.black.withValues(alpha: .1)),
          ),
          child: child,
        ),
      );
    }
    return _FrostedBackdrop(
      radius: radius,
      // the block's content in a layer of its own: what moves in it (a clock, a figure) is drawn again alone, not
      // with the frosted backdrop and the blocks beside it
      child: RepaintBoundary(
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // lighter than the chosen clarity: the tiles inside add their own pane, and the two together came out
            // nearly solid next to the other pages' single see-through cards
            color: dark
                ? ContrastColours.of(context).pane(true).withValues(alpha: clarity.night * (solo ? .75 : .6))
                : Colors.white.withValues(alpha: clarity.day * (solo ? .75 : .6)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .7)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The blurred backdrop's part under [child], clipped to its rounded shape.
class _FrostedBackdrop extends ConsumerWidget {
  const _FrostedBackdrop({required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final ready = ref.watch(sharedPreferencesProvider).hasValue;
    final palette = ref.watch(contrastColoursProvider);
    final clarity = ready ? ref.watch(Preferences.contrastClarity) : ContrastClarity.fallback;
    final (warm, cool) = palette.backdrop(brightness);
    final scale = math.min(MediaQuery.devicePixelRatioOf(context), 1.0);
    final kind = ready ? ref.watch(Preferences.contrastBackdrop) : ContrastBackdrop.fallback;
    final layout = ref.watch(contrastBackdropLayoutProvider);
    ui.Image picture(int seed) => ContrastFrostImage.of(
      kind: kind,
      warm: warm,
      cool: cool,
      dark: brightness == Brightness.dark,
      area: contrastImageArea(MediaQuery.sizeOf(context)),
      // thin lines blurred lightly (they still show), filled shapes harder (their bright edges ran through the text)
      blur: palette.glass(brightness) != null || kind.lines ? clarity.blur : 12,
      scale: scale,
      seed: seed,
      page: palette.page(brightness == Brightness.dark),
      glass: palette.glass(brightness),
    );
    final image = picture(layout.seed);
    // the layout before, under the new one while that fades in (the VPN on or off)
    final previous = layout.previous == layout.seed ? null : picture(layout.previous);
    // on a muted page the backdrop under the frost is toned down too
    final muted = context.findAncestorStateOfType<_ContrastGlowState>()?.widget.muted ?? false;
    final frost = _FrostPart(
      image: image,
      previous: previous,
      scale: scale,
      radius: radius,
      scroll: Scrollable.maybeOf(context)?.position,
      child: child,
    );
    if (!muted) return frost;
    return _FrostPart(
      image: image,
      previous: previous,
      scale: scale,
      radius: radius,
      scroll: Scrollable.maybeOf(context)?.position,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ContrastGlow.veil(brightness == Brightness.dark),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// Marks a backdrop's box: frost inside it takes its part of the picture by its place in this box, so a page
/// sliding with its backdrop keeps its frost right without being repainted (it jumped when the tabs changed).
class _GlowAnchor extends SingleChildRenderObjectWidget {
  const _GlowAnchor({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGlowAnchor();
}

class _RenderGlowAnchor extends RenderProxyBox {}

class _FrostPart extends SingleChildRenderObjectWidget {
  const _FrostPart({
    required this.image,
    required this.scale,
    required this.radius,
    this.previous,
    this.scroll,
    super.child,
  });

  final ui.Image image;

  /// the layout before, under the new one while that fades in
  final ui.Image? previous;

  /// the picture's pixels per point
  final double scale;
  final double radius;

  /// the list it's in: it moves over the backdrop as that scrolls
  final Listenable? scroll;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFrostPart(image, radius, scroll)
    ..scale = scale
    ..previous = previous;

  @override
  void updateRenderObject(BuildContext context, _RenderFrostPart renderObject) => renderObject
    ..image = image
    ..previous = previous
    ..scale = scale
    ..radius = radius
    ..scroll = scroll;
}

class _RenderFrostPart extends RenderProxyBox {
  _RenderFrostPart(this._image, this._radius, this._scroll);

  double _scale = 1;
  set scale(double v) {
    if (v == _scale) return;
    _scale = v;
    markNeedsPaint();
  }

  Listenable? _scroll;
  set scroll(Listenable? v) {
    if (identical(v, _scroll)) return;
    if (attached) _scroll?.removeListener(markNeedsPaint);
    _scroll = v;
    if (attached) _scroll?.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll?.addListener(markNeedsPaint);
    if (_previous != null) ContrastBackdropLayout.fade.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scroll?.removeListener(markNeedsPaint);
    ContrastBackdropLayout.fade.removeListener(markNeedsPaint);
    super.detach();
  }

  /// the layout before, faded out as the new one fades in: repainted with the fade only while there is one
  ui.Image? _previous;
  set previous(ui.Image? v) {
    if (identical(v, _previous)) return;
    if (attached) {
      ContrastBackdropLayout.fade.removeListener(markNeedsPaint);
      if (v != null) ContrastBackdropLayout.fade.addListener(markNeedsPaint);
    }
    _previous = v;
    markNeedsPaint();
  }

  ui.Image _image;
  set image(ui.Image v) {
    if (identical(v, _image)) return;
    _image = v;
    markNeedsPaint();
  }

  double _radius;
  set radius(double v) {
    if (v == _radius) return;
    _radius = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // where the block is on its backdrop (laid out from the backdrop's corner, as the picture is): found from the
    // nearest one round it, which moves with the page; the screen when there's none
    RenderObject? up = parent;
    while (up != null && up is! _RenderGlowAnchor) {
      up = up.parent;
    }
    final at = localToGlobal(Offset.zero, ancestor: up);
    final k = _scale;
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(_radius)));
    // whole pixels of the picture: a part taken between them was resampled anew each frame and the lines shimmered
    final part = Rect.fromLTWH(
      (at.dx * k).roundToDouble(),
      (at.dy * k).roundToDouble(),
      size.width * k,
      size.height * k,
    );
    final fade = ContrastBackdropLayout.fade.value;
    final old = _previous;
    if (old != null && fade < 1) {
      canvas.drawImageRect(old, part, offset & size, Paint()..filterQuality = FilterQuality.low);
    }
    canvas.drawImageRect(
      _image,
      part,
      offset & size,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(0, 0, 0, old != null && fade < 1 ? fade : 1),
    );
    canvas.restore();
    super.paint(context, offset);
  }
}

/// The tab on the panel's top edge: "Серверы VPN"; a tap shows the servers this session went through.
class _SeamTab extends StatelessWidget {
  const _SeamTab({required this.label});

  final String label;

  /// how far the tab stands up over the panel's edge
  static const overhang = 15.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? Colors.white.withValues(alpha: .75) : const Color(0xFF4A4743);
    return Material(
      color: contrastPanelColor(dark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        onTap: () => showGlassPopup(context, const _SessionServers()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 7, 22, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dns_rounded, size: 14, color: theme.araIcon),
              const Gap(5),
              Text(
                label,
                style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contrast's panel: pure white by day, pure black by night.
Color contrastPanelColor(bool dark) => dark ? Colors.black : Colors.white;

/// The look Contrast's panel is drawn in: by night light text on black, the accent lifted to read on it; by day
/// the page's own look on white.
ThemeData contrastPanelTheme(ThemeData theme) {
  if (theme.brightness == Brightness.light) {
    return theme.copyWith(colorScheme: theme.colorScheme.copyWith(surface: Colors.white));
  }
  const ink = Color(0xFFF3F1EC);
  final hsl = HSLColor.fromColor(theme.colorScheme.primary);
  final primary = hsl.lightness < .55 ? hsl.withLightness(.62).toColor() : theme.colorScheme.primary;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(bodyColor: ink, displayColor: ink),
    iconTheme: const IconThemeData(color: ink),
    colorScheme: theme.colorScheme.copyWith(
      primary: primary,
      onPrimary: const Color(0xFF111111),
      surface: Colors.black,
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF8F8C86),
      surfaceContainerLow: const Color(0xFF111113),
      surfaceContainer: const Color(0xFF18181B),
      surfaceContainerHigh: const Color(0xFF1F1F22),
      surfaceContainerHighest: const Color(0xFF27272B),
      outlineVariant: const Color(0xFF34343A),
      outline: const Color(0xFF55555B),
    ),
  );
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
                          : Text(flag ?? '🌐', style: const TextStyle(fontSize: 18, fontFamilyFallback: ['Emoji'])),
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
              ? Image.memory(
                  app.icon!,
                  width: side,
                  height: side,
                  cacheWidth: (side * 3).round(),
                  gaplessPlayback: true,
                )
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

/// Contrast's popups: a see-through frosted card in the middle of the screen, a fifth smaller than the screen's
/// free room, growing from just above the panel.
Future<void> showGlassPopup(BuildContext context, Widget child) async {
  // the page under it held as a picture while it opens and closes (see [FreezeFrame])
  final frozen = await FreezeFrame.freeze();
  if (!context.mounted) {
    if (frozen) FreezeFrame.thawSoon();
    return;
  }
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black26,
      transitionDuration: lightDuration(const Duration(milliseconds: 300)),
      pageBuilder: (_, _, _) => _GlassPopup(child: child),
      transitionBuilder: (context, animation, _, child) =>
          HomePopupTransition(animation: animation, alignment: const Alignment(0, .9), child: child),
    );
  } finally {
    if (frozen) FreezeFrame.thawSoon();
  }
}

class _GlassPopup extends ConsumerWidget {
  const _GlassPopup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // as wide as the route's card (a traffic tile's): the screen less 16 at each side
          maxWidth: math.min(screen.width - 32, 440),
          maxHeight: (screen.height - 120) * .8,
        ),
        // solid: the see-through glass still stuttered as it opened
        child: Material(
          color: dark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F5F1),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: dark ? Colors.white.withValues(alpha: .1) : Colors.black.withValues(alpha: .06)),
          ),
          child: child,
        ),
      ),
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
                            FlagBadge(
                              profile: name.profile,
                              child: Text(
                                name.flag ?? '🌐',
                                style: const TextStyle(fontSize: 20, fontFamilyFallback: ['Emoji']),
                              ),
                            ),
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

/// The delay to the sites the user uses most, in tiles like the session line's: the site's letter in a thin circle,
/// its name and the delay large, over water that rises the faster it answers, green up to 150 ms, amber up to 300,
/// red slower or with no answer. Two rows of three filling the room the traffic had; a tap asks them again.
class _SiteTiles extends HookConsumerWidget {
  const _SiteTiles({required this.visible, this.compact = false});

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
      final timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(ref.read(siteLatencyProvider.notifier).test()));
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
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: ContrastClarity.of(context).tile),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
        ),
        child: Stack(
          children: [
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
              )
            else
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
                    fontSize: 12 * k,
                  ),
                );
                final server = siteServers[site.key];
                // no flag when the site goes through the main server, or one of the same country (the same flag
                // would read as the same server)
                final own = server == null || server == mainServer ? '' : _flagOf(server);
                final flag = own == _flagOf(mainServer ?? '') ? '' : own;
                // the flag as in the server row: a thin circle the size of the logo's disc, the flag in it at half
                // the circle's width, with room round it (it can't stick out of the circle)
                final cornerFlag = flag.isEmpty
                    ? null
                    : Container(
                        width: disc,
                        height: disc,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outline.withValues(alpha: .7), width: 1.3),
                        ),
                        child: Text(
                          flag,
                          style: TextStyle(fontSize: disc * .5, height: 1, fontFamilyFallback: const ['Emoji']),
                        ),
                      );
                // with several subscriptions: which one the site's server is from
                final corner = cornerFlag == null
                    ? null
                    : FlagBadge(
                        profile: server == null ? -1 : serverNameOf(server).profile,
                        size: 11 * k,
                        child: cornerFlag,
                      );
                final unitStyle = TextStyle(
                  fontSize: 12 * k,
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
                        children: [ring, const Spacer(), if (corner != null) corner],
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
                                          fontSize: 12 * k,
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
                                  fontSize: 32 * k,
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
            for (var start = 0; start < shown.length; start += 3) ...[
              if (start > 0) const Gap(8),
              line(shown.skip(start).take(3)),
            ],
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

/// A window's glass by the clarity chosen in Settings → Themes: what's behind it blurred, [builder] given the tint.
class ContrastClear extends ConsumerWidget {
  const ContrastClear({super.key, required this.builder, this.radius = 26});

  final Widget Function(Color tint) builder;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // solid: the see-through glass still stuttered as the card opened
    return builder(dark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F5F1));
  }
}

/// A round frosted plate under an icon button (Contrast's "+" and cog).
class ContrastPlate extends ConsumerWidget {
  const ContrastPlate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clarity = ref.watch(Preferences.contrastClarity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: _FrostedBackdrop(
        radius: 100,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark
                ? ContrastColours.of(context).pane(true).withValues(alpha: clarity.night)
                : Colors.white.withValues(alpha: clarity.day),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .7)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// [v] in whole percents (0 to 1): an animation to it starts again only when it moves by one.
double _percent(double v) => v.isFinite ? (v * 100).round() / 100 : 0;

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
          Positioned.fill(child: _Water(level: level, colour: colour, dark: dark)),
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
      pair(
        line(Icons.shield_rounded, accent, vpn, lit: true),
        line(Icons.alt_route_rounded, grey, direct),
      ),
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
      pair(
        line(Icons.south_rounded, accent, down, lit: true),
        line(Icons.north_rounded, grey, up),
      ),
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

/// How good a speed is as the water of a tile: nothing at 100 КБ/с or less, full at 10 МБ/с or more, between on a
/// log scale.
double _speedLevel(int bytesPerSecond) {
  const low = 100 * 1024;
  const high = 10 * 1024 * 1024;
  if (bytesPerSecond <= low) return 0;
  return (math.log(bytesPerSecond / low) / math.log(high / low)).clamp(0.0, 1.0);
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
        onTap: updating ? null : () => ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: updating
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurfaceVariant))
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
    // a small round button on the left, the block's name beside it; while the sites are asked a ring of the
    // accent fills round it, a site at a time, closes when they have all answered and fades
    return Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Row(
            children: [
              // the delay check, a pill like the multi-server one beside it: the sign and the name; while the sites are
              // asked the sign is a small ring of the accent that fills a site at a time
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
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
                        : Icon(Icons.refresh_rounded, size: 15, color: scheme.onSurfaceVariant),
                    const Gap(6),
                    Text(
                      t.avpn.sitesTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: sites.testing ? scheme.onSurface : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // the multi-server switch, for the network in use (Wi-Fi or LTE): a tap turns it on or off
              GestureDetector(
                key: const Key('multi-servers'),
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(multiPref.notifier).update(!multiOn),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: multiOn ? accent.withValues(alpha: .16) : Colors.transparent,
                    border: Border.all(color: multiOn ? accent : scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alt_route_rounded, size: 15, color: multiOn ? accent : scheme.onSurfaceVariant),
                      const Gap(6),
                      Text(
                        '${t.avpn.multiServers} · ${onMobile ? 'LTE' : 'Wi-Fi'}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: multiOn ? scheme.onSurface : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }
}
