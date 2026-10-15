part of 'avpn_home_body.dart';

/// The home screen in Contrast, Glass or Graphite: the state at the top, the servers in the middle, and the connect
/// control at the bottom, under the thumb.
class _StyledHome extends HookConsumerWidget {
  const _StyledHome({required this.testing, required this.onCheck, this.traffic = true});

  final bool traffic;

  final bool testing;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    // the status as the screen shows it: a blink of "disconnected" while the core's link restarts doesn't show
    final status = ref.watch(shownConnectionProvider);
    final connected = status.isConnected;
    final group = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    final autoGroup = group?.items
        .where((i) => i.tag == (group.selected == 'balance' ? 'balance' : 'lowest'))
        .firstOrNull;
    final autoNow = autoGroup == null ? null : autoPick(autoGroup, group!.items);
    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    final picked = current != null && current.isGroup ? autoPick(current, group!.items) : null;
    // with Auto chosen, the country it is on now shows in Auto's own row ("сейчас: Польша"), not again below it
    final servers = [
      for (final item in group?.items ?? <OutboundInfo>[])
        if (item.isVisible && item.tag != 'balance' && item.tag != picked?.tag) item,
    ];
    final serverMode = ref.watch(ConfigOptions.homeNetwork);
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
    if (theme.araLook.style == AraStyle.contrast) {
      return _ContrastHome(
        header: header,
        status: _StatusBlock(status: status, lastServer: currentName),
        servers: hasList
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // only the choice in use (Auto, as a rule); a tap on it brings up every country
                  SizedBox(
                    height: 64,
                    child: _StyledServerList(
                      servers: [
                        servers.firstWhere(
                          (s) => s.tag == group?.selected || (s.tag == 'lowest' && group?.selected == 'balance'),
                          orElse: () => servers.first,
                        ),
                      ],
                      selectedTag: group?.selected,
                      autoNow: autoNow,
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
        traffic: traffic && hasList ? const _HomeTraffic() : null,
        toggles: _CheckRow(onCheck: onCheck, testing: testing, showCheck: false),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 2, 18, spread ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBlock(status: status, lastServer: currentName),
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
                    testing: testing,
                  ),
                ),
              ],
            ),
            gap,
            // where the traffic went, under the servers (as on the Topology tab): always the same place and size,
            // all the room between the servers and the toggles; the unfolded phone has it in a column of its own
            if (traffic) const Expanded(child: _HomeTraffic()) else share(),
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
  }
}

/// "Защищено" with the time and the speed, or "Отключено".
class _StatusBlock extends HookConsumerWidget {
  const _StatusBlock({required this.status, required this.lastServer});

  final ConnectionStatus status;
  final String? lastServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = status.isConnected;
    final stats = ref.watch(statsNotifierProvider).valueOrNull;
    final now = useState(DateTime.now());
    final since = useState<DateTime?>(null);
    useEffect(() {
      if (!connected) {
        since.value = null;
        return null;
      }
      since.value ??= DateTime.now();
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => now.value = DateTime.now());
      return timer.cancel;
    }, [connected]);
    final units = t.avpn.bytesUnits.split(',');
    String speed(int bytes) => '${formatBytes(bytes, units)}${t.avpn.perSecond}';
    final time = _duration(now.value.difference(stats?.sessionStartedAt ?? since.value ?? now.value));
    final down = speed(stats?.downlink.toInt() ?? 0);
    final up = speed(stats?.uplink.toInt() ?? 0);
    final waiting = switch (status) {
      Connecting() => t.avpn.connecting,
      Disconnecting() => t.avpn.disconnecting,
      _ => null,
    };

    if (theme.araLook.style == AraStyle.contrast) {
      // what moved today, from 03:00 to 03:00
      ref.watch(trafficHistoryProvider);
      final today = ref.read(trafficHistoryProvider.notifier).amountFrom(statsDayStart(DateTime.now()));
      (String, String) amount(int bytes) {
        final parts = formatBytes(bytes, units).split(' ');
        return (parts.first, parts.length > 1 ? parts.last : '');
      }

      final vpn = amount(today.vpn);
      final direct = amount((today.total - today.vpn).clamp(0, 1 << 62));
      final sessionLength = now.value.difference(stats?.sessionStartedAt ?? since.value ?? now.value);
      final routed = today.total == 0 ? 1 : today.total;
      final vpnShare = today.vpn / routed;
      return _ContrastStats(
        items: [
          // the time by the day, the two routes by each other
          (
            Icons.schedule_rounded,
            t.avpn.contrastTime,
            connected ? time : (waiting ?? '—'),
            '',
            false,
            connected ? sessionLength.inMinutes / (24 * 60) : 0,
            const Color(0xFF8FA8BD),
          ),
          (
            Icons.shield_outlined,
            t.avpn.statsViaVpn,
            vpn.$1,
            vpn.$2,
            true,
            today.total == 0 ? 0 : vpnShare,
            scheme.primary,
          ),
          (
            Icons.alt_route_rounded,
            t.avpn.homeBypass,
            direct.$1,
            direct.$2,
            false,
            today.total == 0 ? 0 : 1 - vpnShare,
            const Color(0xFF9AA0A6),
          ),
        ],
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
    final accent = theme.araLook.neonFill ?? scheme.primary;
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
    final updating = remote != null && ref.watch(updateProfileNotifierProvider(remote.id)).isLoading;
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
        // the subscription refresh, with a word so it's clear what it does
        if (remote != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: updating
                  ? null
                  : () => ref.read(updateProfileNotifierProvider(remote.id).notifier).updateProfile(remote),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (updating)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: scheme.onSurfaceVariant),
                      )
                    else
                      Icon(Icons.sync_rounded, size: 15, color: scheme.onSurfaceVariant),
                    const Gap(4),
                    Text(
                      t.avpn.stUpdateServers.toUpperCase(),
                      style: label?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
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
    required this.testing,
    this.onRowTap,
    this.afterSelect,
  });

  /// a tap on a row does this instead of choosing it (Contrast's one row opens the list)
  final VoidCallback? onRowTap;

  /// after a row is chosen (the list in a sheet closes)
  final VoidCallback? afterSelect;

  final List<OutboundInfo> servers;
  final String? selectedTag;
  final OutboundInfo? autoNow;
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
            final name = serverName(server);
            final auto = server.tag == 'lowest';
            // "Финляндия" with "Sigma · VLESS" under it, rather than "Sigma - Финляндия"
            final dash = name.title.indexOf(' - ');
            // a note in brackets at the end ("Финляндия (Тестовый)") goes to the line under: "Тестовый · Sigma · VLESS"
            final full = _marked(dash < 0 ? name.title : name.title.substring(dash + 3).trim(), name.title);
            final note = RegExp(r'\s*\(([^()]*)\)$').firstMatch(full);
            final title = auto ? t.avpn.auto : (note == null ? full : full.substring(0, note.start).trim());
            final subtitle = auto
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
              flag: server.isGroup ? null : name.flag,
              group: server.isGroup,
              title: title,
              subtitle: subtitle,
              delay: server.urlTestDelay,
              selected: selected,
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
    required this.group,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.selected,
    required this.testing,
    required this.first,
    required this.onTap,
    this.flooded = false,
  });

  final String? flag;
  final bool group;
  final String title;
  final String subtitle;
  final int delay;
  final bool selected;
  final bool testing;
  final bool first;
  final VoidCallback onTap;

  /// already drawn inside the neon theme override
  final bool flooded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = theme.araLook.neonFill;
    if (theme.araLook.style == AraStyle.contrast) {
      return _ContrastRow(
        flag: flag,
        group: group,
        title: title,
        subtitle: subtitle,
        delay: delay,
        selected: selected,
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
              style: theme.araLook.style,
              neonFill: fill,
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
          testing: testing,
          first: first,
          onTap: onTap,
          flooded: true,
        ),
      );
    }
    final glass = theme.araLook.glass;
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
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: group
                        ? AraIconPaint(child: Icon(Icons.auto_awesome_rounded, size: 24, color: scheme.primary))
                        : Text(flag ?? '🌐', style: const TextStyle(fontSize: 28, fontFamilyFallback: ['Emoji'])),
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
final _pendingFrom = ValueNotifier<ConnectionStatus?>(null);
Timer? _pendingTimeout;

Future<void> _toggleConnection(WidgetRef ref) async {
  if (_pendingFrom.value != null) return;
  if (ref.read(activeProfileProvider).valueOrNull == null) {
    await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
    ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
    return;
  }
  _pendingFrom.value = ref.read(connectionNotifierProvider).valueOrNull ?? const Disconnected();
  // never stuck: a core that doesn't answer lets the button go after a while
  _pendingTimeout?.cancel();
  _pendingTimeout = Timer(const Duration(seconds: 30), () => _pendingFrom.value = null);
  try {
    await ref.read(connectionNotifierProvider.notifier).toggleConnection();
  } catch (_) {
    _pendingFrom.value = null;
    rethrow;
  }
}

/// Ping and loss through the VPN, measured every second (the probes the Statistics tab shows; the tunnel's warm-up
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
    required this.testing,
    required this.onCheck,
    this.large = false,
  });

  final bool large;

  final ConnectionStatus status;
  final String? server;
  final bool testing;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final on = status.isConnected;
    final pendingFrom = useValueListenable(_pendingFrom);
    // the tap's done once the core has settled on another status (on, off, or a failure)
    useEffect(() {
      if (pendingFrom != null && !status.isSwitching && status != pendingFrom) {
        Future.microtask(() {
          _pendingTimeout?.cancel();
          _pendingFrom.value = null;
        });
      }
      return null;
    }, [status, pendingFrom]);
    final busy = status.isSwitching || pendingFrom != null;
    final glass = theme.araLook.glass;
    // Contrast: tight, on its black panel
    final padding = theme.araLook.style == AraStyle.contrast
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
    // the whitelist ("LTE Only") servers or the regular ones: the server in use (Auto: the one it picked) tells; the
    // computer only ever marks the whitelist
    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    final inUse = current != null && current.isGroup ? autoPick(current, group!.items) : current;
    final whitelist =
        inUse != null &&
        (ServerRegionFilter.isMobileOnly(inUse.tag) || ServerRegionFilter.isMobileOnly(inUse.tagDisplay));
    final mode = !on || busy || inUse == null ? null : (whitelist ? true : (PlatformUtils.isDesktop ? null : false));
    final accent = theme.araLook.neonFill ?? scheme.primary;
    // the side icons and the ping in the accent (by day a light accent goes to the text colour); grey while off
    final ink = on
        ? (dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : scheme.onSurface)
        : scheme.onSurfaceVariant;
    // Contrast: the side figures and captions a little bigger
    final sideFigure = theme.araLook.style == AraStyle.contrast ? 25.0 : null;
    final caption =
        (theme.araLook.style == AraStyle.contrast ? theme.textTheme.labelLarge : theme.textTheme.labelMedium)?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        );
    final iconSize = (large ? 28.0 : 26.0) * (theme.araLook.style == AraStyle.contrast ? 1.05 : 1);
    // no plates: an icon (or a number) over a small caption, pressed as one
    // on a barely-there plate, as the toggles above
    Widget side({required Widget top, required String label, VoidCallback? onTap}) => Material(
      // Contrast: no plate, right on its black panel
      color: theme.araLook.style == AraStyle.contrast
          ? Colors.transparent
          : scheme.onSurface.withValues(alpha: dark ? .06 : .045),
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
                Text(label, style: caption),
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
            alignment: theme.araLook.style == AraStyle.contrast ? const Alignment(-.45, 0) : Alignment.center,
            child: side(
              top: on && testing
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: ink))
                  : theme.araLook.style == AraStyle.contrast
                  // Contrast: the ping here, as the servers answering are on the right: the sign and the figure
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.network_ping_rounded, size: iconSize, color: ink),
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
                          ),
                        ),
                      ],
                    )
                  : Icon(Icons.network_ping_rounded, size: iconSize, color: ink),
              // Contrast: the loss under it while measured
              label: theme.araLook.style == AraStyle.contrast && on && measured && !busy
                  ? t.avpn.dockLoss(loss: lossText)
                  : t.avpn.stPingButton,
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
          size: (large ? 88.0 : 76.0) * (theme.araLook.style == AraStyle.contrast ? .8 : 1),
          below: padding.bottom,
          ping: measured ? _Orb.pingFill(ping) : 0,
          loss: measured ? _Orb.lossFill(loss) : 0,
          pingLabel: measured && !busy ? '$ping ms' : null,
          lossLabel: measured && !busy ? lossText : null,
          mode: mode,
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
                      Icon(Icons.dns_rounded, size: iconSize - 2, color: ink),
                      const Gap(6),
                      Text(
                        on ? '$answering' : '—',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1,
                          fontSize: sideFigure,
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
    if (theme.araLook.style == AraStyle.contrast) return Padding(padding: padding, child: content);
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
class _Orb extends HookWidget {
  const _Orb({
    required this.on,
    required this.busy,
    this.onTap,
    this.size = 74,
    this.ping = 0,
    this.loss = 0,
    this.pingLabel,
    this.lossLabel,
    this.mode,
    this.below = 0,
  });

  /// the button's diameter; the arcs and numbers take about twice that across
  final double size;

  /// how much of each arc is filled, 0 to 1
  final double ping;
  final double loss;

  final String? pingLabel;
  final String? lossLabel;

  /// which servers the connection runs on, on the button's lower edge: null hides it, true the whitelist
  /// ("Белые списки", filled in the accent), false the regular ones ("Обычные", quiet)
  final bool? mode;

  /// the panel's room under this widget: the mode pill sits halfway between the button and the panel's edge
  final double below;

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
    final accent = theme.araLook.neonFill ?? scheme.primary;
    final lossColor = deep(accent);
    final contrastDay = !dark && theme.araLook.style == AraStyle.contrast;
    // the numbers readable: by day a light accent goes to the text colour; the deep shade lifted a little by night
    final pingInk = dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : scheme.onSurface;
    final lossInk = dark ? Color.lerp(lossColor, Colors.white, .35)! : lossColor;
    final width = size * 2.1;
    // Contrast: a rounded-square button in two square frames, the ping outside, the loss inside
    final square = theme.araLook.style == AraStyle.contrast;
    // the square: its numbers inside the button, the frames reaching below it
    final centre = square ? size * .94 : size * .98;
    // Contrast keeps the mode inside the button: no room under it for a pill
    final height = square ? centre + size * .84 : centre + size * .5 + size * .26;
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
              tween: Tween(begin: drawn.value, end: on && !busy ? Offset(_step(ping), _step(loss)) : Offset.zero),
              duration: const Duration(milliseconds: 700),
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
                            ? Color.alphaBlend(
                                accent.withValues(alpha: dark ? .22 : .14),
                                dark ? const Color(0xFFF7F5F1) : Colors.white,
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
                  child: theme.araLook.style == AraStyle.contrast && mode != null
                      // Contrast: the mode under the sign, inside the button
                      // Contrast: the network it runs on, large, instead of the power sign (that only while off)
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // the network it runs on (the ping and the loss are by the ping button)
                            Icon(
                              mode! ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded,
                              size: size * .36,
                              color: accent,
                            ),
                            Text(
                              mode! ? 'LTE' : 'Wi‑Fi',
                              style: TextStyle(
                                fontSize: size * .14,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          Icons.power_settings_new_rounded,
                          size: size * .42,
                          // the icon in the accent too; by day a light one (yellow, green) can't be read on white, so
                          // it goes black there, as the chosen server's text does
                          color: on
                              ? (theme.araLook.neonFill == null
                                    ? (dark && theme.araLook.style != AraStyle.contrast ? Colors.white : scheme.primary)
                                    : (dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : Colors.black))
                              : scheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
          ),
          // the mode, under the button, as far from it as from the panel's lower edge
          Positioned(
            left: 0,
            right: 0,
            top: centre + size * .5 + (height - centre - size * .5 + below) / 2 - size * .13,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: mode == null || theme.araLook.style == AraStyle.contrast
                    ? const SizedBox.shrink()
                    : _ModeBadge(key: ValueKey(mode), whitelist: mode!, size: size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The servers the connection runs on, as a small pill: the whitelist filled in the accent with an antenna, the
/// regular ones quiet (the button's own colour, a thin edge, the Wi-Fi sign).
class _ModeBadge extends ConsumerWidget {
  const _ModeBadge({super.key, required this.whitelist, required this.size});

  final bool whitelist;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araLook.neonFill ?? scheme.primary;
    final onAccent = AraLook.contrast(accent, Colors.black) >= AraLook.contrast(accent, Colors.white)
        ? Colors.black
        : Colors.white;
    final ink = whitelist ? onAccent : scheme.onSurfaceVariant;
    final height = size * .26;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * .45),
      decoration: BoxDecoration(
        color: whitelist ? accent : (dark ? const Color(0xFF16161A) : Colors.white),
        borderRadius: BorderRadius.circular(height / 2),
        border: whitelist ? null : Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .3 : .08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(whitelist ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded, size: height * .58, color: ink),
          SizedBox(width: height * .2),
          Text(
            whitelist ? t.avpn.dockModeWhitelist : t.avpn.dockModeRegular,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: height * .44,
              height: 1,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
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
  const _HomeTraffic();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final units = t.avpn.bytesUnits.split(',');
    // followed only while the home screen is in sight
    final visible = TickerMode.of(context);
    final state = visible ? ref.watch(connectionsProvider) : ref.read(connectionsProvider);
    // this session's connections only, as the right panel of the unfolded phone
    // held across the statistics stream's blinks, so the card doesn't flip when the app comes back
    final sessionStart = ref.watch(sessionStartProvider);
    // the VPN off: no session, the picture (the last session's list isn't shown)
    final connected = ref.watch(shownConnectionProvider).isConnected;
    final current = [
      // the session's start not known yet: nothing rather than the whole day's list
      if (connected && sessionStart != null)
        for (final c in state.items)
          if (!c.start.isBefore(sessionStart)) c,
    ];
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
    if (theme.araLook.style == AraStyle.contrast) {
      final installed = ref.watch(installedAppsProvider).valueOrNull ?? const {};
      List<_AppShare> route(ConnectionRoute r) {
        final groups = groupConnections(items.where((c) => c.route == r), (c) => c.app)
          ..sort((a, b) => b.total.compareTo(a.total));
        return [
          for (final g in groups)
            (
              name: connectionAppName(t, installed, g.key),
              bytes: g.total,
              servers: r == ConnectionRoute.vpn ? serverFlags(g.servers.where((s) => !isHiddenServer(s))) : '',
              icon: installed[g.key]?.icon,
            ),
        ];
      }

      return _ContrastTraffic(vpn: route(ConnectionRoute.vpn), direct: route(ConnectionRoute.direct));
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
                colour: theme.araLook.neonFill ?? theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
    // Glass: the strips on a pane of glass, as the rows above them
    final glass = theme.araLook.glass;
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
                  leading: Text(name.flag ?? '🌐', style: const TextStyle(fontSize: 22, fontFamilyFallback: ['Emoji'])),
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
  });

  /// "Серверы · Sigma · 23 дн. · Обновить", over the blocks
  final Widget header;
  final Widget status;
  final Widget servers;
  final Widget? traffic;
  final Widget toggles;

  @override
  Widget build(BuildContext context) {
    return _LongSwipe(
      // down: the settings come down from the top; up: the day's connections come up from the panel
      onDown: () => context.goNamed('settings'),
      onUp: () => context.goNamed('connections'),
      child: LayoutBuilder(
        // a short screen: no room for the traffic block (it's on the Statistics tab)
        builder: (context, box) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: header),
              _ContrastBlock(child: status),
              const Gap(8),
              _ContrastBlock(child: servers),
              const Gap(8),
              if (traffic != null && box.maxHeight >= 440)
                Expanded(child: _ContrastBlock(expand: true, child: traffic!))
              else
                const Spacer(),
              // a short screen (the phone turned): the toggles are under the connect control at the side
              if (!ContrastShellDock.sideways(context)) ...[const Gap(8), _ContrastBlock(child: toggles)],
            ],
          ),
        ),
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
    final dock = _GraphiteDock(
      status: status,
      server: null,
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
  const ContrastGlow({super.key, required this.child, this.page = '', this.own = false});

  final Widget child;

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
    // the settings not read yet (the first frames): the defaults
    final ready = ref.watch(sharedPreferencesProvider).hasValue;
    final palette = ready ? ref.watch(Preferences.contrastPalette) : ContrastPalette.fallback;
    final (warm, cool) = palette.backdrop(brightness);
    return _GlowAnchor(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: ContrastBackdropPainter(
                  kind: ready ? ref.watch(Preferences.contrastBackdrop) : ContrastBackdrop.fallback,
                  warm: warm,
                  cool: cool,
                  dark: brightness == Brightness.dark,
                  seed: contrastBackdropSeed,
                  // laid out on the screen, so every page's lines up with the rest
                  area: MediaQuery.sizeOf(context),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

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
  const ContrastFrost({super.key, required this.child, this.radius = 24, this.padding = const EdgeInsets.all(8)});

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
    return _FrostedBackdrop(
      radius: radius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          // lighter than the chosen clarity: the tiles inside add their own pane, and the two together came out
          // nearly solid next to the other pages' single see-through cards
          color: dark
              ? const Color(0xFF1E1E22).withValues(alpha: clarity.night * .6)
              : Colors.white.withValues(alpha: clarity.day * .6),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .7)),
        ),
        child: child,
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
    final palette = ready ? ref.watch(Preferences.contrastPalette) : ContrastPalette.fallback;
    final clarity = ready ? ref.watch(Preferences.contrastClarity) : ContrastClarity.fallback;
    final (warm, cool) = palette.backdrop(brightness);
    final image = ContrastFrostImage.of(
      kind: ready ? ref.watch(Preferences.contrastBackdrop) : ContrastBackdrop.fallback,
      warm: warm,
      cool: cool,
      dark: brightness == Brightness.dark,
      area: MediaQuery.sizeOf(context),
      blur: clarity.blur,
    );
    return _FrostPart(image: image, radius: radius, scroll: Scrollable.maybeOf(context)?.position, child: child);
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
  const _FrostPart({required this.image, required this.radius, this.scroll, super.child});

  final ui.Image image;
  final double radius;

  /// the list it's in: it moves over the backdrop as that scrolls
  final Listenable? scroll;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFrostPart(image, radius, scroll);

  @override
  void updateRenderObject(BuildContext context, _RenderFrostPart renderObject) => renderObject
    ..image = image
    ..radius = radius
    ..scroll = scroll;
}

class _RenderFrostPart extends RenderProxyBox {
  _RenderFrostPart(this._image, this._radius, this._scroll);

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
  }

  @override
  void detach() {
    _scroll?.removeListener(markNeedsPaint);
    super.detach();
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
    const k = ContrastFrostImage.scale;
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(_radius)));
    canvas.drawImageRect(
      _image,
      Rect.fromLTWH(at.dx * k, at.dy * k, size.width * k, size.height * k),
      offset & size,
      Paint()..filterQuality = FilterQuality.medium,
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
    final accent = theme.araLook.neonFill ?? theme.colorScheme.primary;
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
              Icon(Icons.dns_rounded, size: 14, color: accent),
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
    required this.group,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.selected,
    required this.testing,
    required this.onTap,
  });

  final String? flag;
  final bool group;
  final String title;
  final String subtitle;
  final int delay;
  final bool selected;
  final bool testing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.araLook.neonFill ?? scheme.primary;
    final ink = scheme.onSurface;
    final decoration = selected
        // the chosen one: see-through glass, cool at the left warming to the accent, a light edge and a glow
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8FA8BD).withValues(alpha: dark ? .28 : .32),
                accent.withValues(alpha: dark ? .25 : .22),
                accent.withValues(alpha: dark ? .4 : .36),
              ],
              stops: const [0, .6, 1],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .14 : .85)),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: .15), blurRadius: 20, offset: const Offset(0, 6))],
          )
        : BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: dark ? .3 : .3),
            borderRadius: BorderRadius.circular(22),
            // see-through: the zone's light shows through
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
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
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? accent : scheme.outlineVariant, width: 1.3),
                    ),
                    child: group
                        ? Icon(Icons.auto_awesome_rounded, size: 18, color: selected ? accent : ink)
                        : Text(flag ?? '🌐', style: const TextStyle(fontSize: 18, fontFamilyFallback: ['Emoji'])),
                  ),
                  const Gap(11),
                  Expanded(
                    child: country != null
                        // "Авто" at the left, the country it's on in the middle of the row (a test server's note
                        // under it)
                        ? Row(
                            children: [
                              Text(title, style: titleStyle?.copyWith(fontWeight: FontWeight.w700)),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      country,
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
                              style: TextStyle(fontSize: 10, letterSpacing: 0, color: ink.withValues(alpha: .65)),
                            ),
                        ],
                      ),
                      // the same size as the name, in the text's colour
                      style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
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
    Widget water(double level, Color colour) => TweenAnimationBuilder<double>(
      // in whole percents: the traffic moving every second doesn't restart it each time (the screen redrew nonstop)
      tween: Tween(end: _percent(level.clamp(0.0, 1.0))),
      duration: const Duration(milliseconds: 900),
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
    // the unfolded phone (or a tablet): half as high, the sign beside the label and the figure
    final compact = MediaQuery.sizeOf(context).width >= 700 || MediaQuery.sizeOf(context).height < 600;
    Widget tile(IconData icon, String label, String figure, String unit, bool lit, double level, Color colour) {
      Widget value(double size) => Text.rich(
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
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: .3),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outlineVariant, width: 1.3),
                      ),
                      child: Icon(icon, size: 14, color: scheme.onSurfaceVariant),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outlineVariant, width: 1.3),
                        ),
                        child: Icon(icon, size: 14, color: scheme.onSurfaceVariant),
                      ),
                      const Gap(5),
                      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const Gap(2),
                      FittedBox(fit: BoxFit.scaleDown, child: value(22)),
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
          Expanded(child: tile(icon, label, figure, unit, lit, level, colour)),
        ],
      ],
    );
  }
}

/// An app's part of a route: its name, how much, the servers it went through (flags) and its icon.
typedef _AppShare = ({String name, int bytes, String servers, Uint8List? icon});

/// Contrast's traffic: two tiles, through the VPN (the accent) and the bypass (grey), each marked by its sign with
/// its share and amount; each filled from the bottom like water to its share of the session's traffic, the water
/// split into bands by app (the biggest at the bottom, deepest). A tap opens the route's apps in a card that grows
/// out of the tile into the middle of the screen.
class _ContrastTraffic extends StatelessWidget {
  const _ContrastTraffic({required this.vpn, required this.direct});

  final List<_AppShare> vpn;
  final List<_AppShare> direct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.araLook.neonFill ?? theme.colorScheme.primary;
    int sum(List<_AppShare> apps) => apps.fold(0, (s, a) => s + a.bytes);
    final total = sum(vpn) + sum(direct);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _WaterTile(icon: Icons.shield_rounded, apps: vpn, total: total, colour: accent, vpn: true),
        ),
        const Gap(6),
        Expanded(
          child: _WaterTile(
            icon: Icons.alt_route_rounded,
            apps: direct,
            total: total,
            colour: const Color(0xFF9AA0A6),
            vpn: false,
          ),
        ),
      ],
    );
  }
}

class _WaterTile extends ConsumerWidget {
  const _WaterTile({
    required this.icon,
    required this.apps,
    required this.total,
    required this.colour,
    required this.vpn,
  });

  final IconData icon;
  final List<_AppShare> apps;
  final int total;
  final Color colour;
  final bool vpn;

  static const _alphas = [.62, .46, .34, .25, .2];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final units = t.avpn.bytesUnits.split(',');
    final bytes = apps.fold<int>(0, (s, a) => s + a.bytes);
    final share = total == 0 ? 0.0 : bytes / total;
    // the bands: the apps with at least 12% of the route, the rest in one ("Ещё N"), so no stack of thin lines
    final big = [
      for (final a in apps)
        if (bytes > 0 && a.bytes / bytes >= .12) a,
    ].take(4).toList();
    final rest = apps.where((a) => !big.contains(a)).toList();
    final bands = <(String, int)>[
      for (final a in big) (a.name, a.bytes),
      if (rest.isNotEmpty)
        (
          rest.length == 1 ? rest.first.name : t.avpn.contrastMore(n: rest.length),
          rest.fold<int>(0, (s, a) => s + a.bytes),
        ),
    ];
    final ink = scheme.onSurface;
    final amount = formatBytes(bytes, units).split(' ');
    const header = 40.0;
    // by day the water lighter, so the light behind shows through
    final alphas = dark ? _alphas : const [.4, .3, .22, .16, .14];
    // always full of its own apps; the route's share is the thin bar under the header
    final level = bytes == 0 ? 0.0 : 1.0;
    return GestureDetector(
      onTap: () => _open(context, t),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: dark ? .1 : .8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // the sign, the amount and the share in one small row over the water
            Container(
              height: header,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colour.withValues(alpha: .25))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colour, width: 1.3),
                    ),
                    child: Icon(icon, size: 13, color: colour),
                  ),
                  const Gap(8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: amount.first),
                        if (amount.length > 1)
                          TextSpan(
                            text: ' ${amount.sublist(1).join(' ')}',
                            style: TextStyle(fontSize: 10, letterSpacing: 0, color: ink.withValues(alpha: .6)),
                          ),
                      ],
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.6,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(share * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _percent(share)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    color: colour,
                    backgroundColor: ink.withValues(alpha: .07),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _percent(level)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, level, _) => Stack(
                  children: [
                    // the stream: a soft glow of the route's colour rising from the water up to the amount
                    if (level > .005)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, 1 - level, 1 - level],
                              colors: [
                                colour.withValues(alpha: 0),
                                colour.withValues(alpha: dark ? .16 : .14),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (level > .005)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: level,
                          widthFactor: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (i, (name, b)) in bands.indexed.toList().reversed)
                                Expanded(
                                  flex: (b * 1000 ~/ (bytes == 0 ? 1 : bytes)).clamp(1, 1000),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: colour.withValues(alpha: alphas[i.clamp(0, 4)]),
                                      border: i < bands.length - 1
                                          ? Border(
                                              top: BorderSide(color: Colors.white.withValues(alpha: dark ? .16 : .7)),
                                            )
                                          : null,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 11),
                                    child: LayoutBuilder(
                                      builder: (context, box) => box.maxHeight < 16
                                          ? const SizedBox.shrink()
                                          : Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      color: ink,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  formatBytes(b, units),
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: ink.withValues(alpha: .7),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The route's apps in a card that grows out of this tile into the middle of the screen.
  void _open(BuildContext context, Translations t) {
    final box = context.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context);
    var from = Alignment.center;
    if (box != null && box.hasSize) {
      final centre = box.localToGlobal(box.size.center(Offset.zero));
      from = Alignment(centre.dx / screen.width * 2 - 1, centre.dy / screen.height * 2 - 1);
    }
    final theme = Theme.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => Theme(
        data: theme,
        child: _RouteCard(apps: apps, total: total, colour: colour, icon: icon, vpn: vpn),
      ),
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(scale: Tween(begin: .25, end: 1.0).animate(curve), alignment: from, child: child),
        );
      },
    );
  }
}

/// A route's apps, in a card in the middle of the screen: the route with its share and amount, a strip of the
/// apps' shares, and each app with its icon, amount, a bar against the biggest, its share and (through the VPN)
/// the servers it went through.
class _RouteCard extends ConsumerWidget {
  const _RouteCard({
    required this.apps,
    required this.total,
    required this.colour,
    required this.icon,
    required this.vpn,
  });

  final List<_AppShare> apps;
  final int total;
  final Color colour;
  final IconData icon;
  final bool vpn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = t.avpn.bytesUnits.split(',');
    final bytes = apps.fold<int>(0, (s, a) => s + a.bytes);
    final top = apps.isEmpty ? 1 : apps.first.bytes;
    final servers = {for (final a in apps) ...a.servers.split(' ').where((f) => f.isNotEmpty)}.length;
    final amount = formatBytes(bytes, units).split(' ');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
        child: ContrastClear(
          radius: 28,
          builder: (tint) => Material(
            color: tint,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: colour.withValues(alpha: .35), width: 1.5),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colour, width: 1.6),
                          ),
                          child: Icon(icon, size: 20, color: colour),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vpn ? t.avpn.statsViaVpn : t.avpn.homeBypass, style: theme.textTheme.titleLarge),
                              Text(
                                vpn
                                    ? t.avpn.contrastRouteVpn(
                                        share: total == 0 ? 0 : (bytes * 100 / total).round(),
                                        n: servers,
                                      )
                                    : t.avpn.contrastRouteDirect(
                                        share: total == 0 ? 0 : (bytes * 100 / total).round(),
                                      ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: amount.first),
                              if (amount.length > 1)
                                TextSpan(
                                  text: ' ${amount.sublist(1).join(' ')}',
                                  style: TextStyle(fontSize: 13, letterSpacing: 0, color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          spacing: 2,
                          children: [
                            for (final (i, a) in apps.indexed)
                              Expanded(
                                flex: (a.bytes * 1000 ~/ (bytes == 0 ? 1 : bytes)).clamp(1, 1000),
                                child: ColoredBox(color: colour.withValues(alpha: (1 - i * .15).clamp(.2, 1))),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(14),
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Text(
                        t.avpn.contrastApps.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: apps.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .5)),
                        itemBuilder: (context, i) {
                          final a = apps[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: a.icon == null
                                      ? Container(
                                          width: 36,
                                          height: 36,
                                          color: colour.withValues(alpha: .2),
                                          alignment: Alignment.center,
                                          child: Text(
                                            a.name.isEmpty ? '?' : a.name.characters.first.toUpperCase(),
                                            style: TextStyle(color: colour, fontWeight: FontWeight.w800),
                                          ),
                                        )
                                      : Image.memory(a.icon!, width: 36, height: 36, gaplessPlayback: true),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              a.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          Text(
                                            formatBytes(a.bytes, units),
                                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      const Gap(5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: a.bytes / top,
                                                minHeight: 5,
                                                color: colour,
                                                backgroundColor: scheme.outlineVariant.withValues(alpha: .4),
                                              ),
                                            ),
                                          ),
                                          const Gap(10),
                                          Text(
                                            [
                                              if (a.servers.isNotEmpty) a.servers,
                                              '${bytes == 0 ? 0 : (a.bytes * 100 / bytes).round()}%',
                                            ].join(' · '),
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contrast's popups: a see-through frosted card in the middle of the screen, a fifth smaller than the screen's
/// free room, growing from just above the panel.
void showGlassPopup(BuildContext context, Widget child) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => _GlassPopup(child: child),
    transitionBuilder: (context, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween(begin: .9, end: 1.0).animate(curve),
          alignment: const Alignment(0, .9),
          child: child,
        ),
      );
    },
  );
}

class _GlassPopup extends ConsumerWidget {
  const _GlassPopup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clarity = ref.watch(Preferences.contrastClarity);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.sizeOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // as wide as the route's card (a traffic tile's): the screen less 16 at each side
          maxWidth: math.min(screen.width - 32, 440),
          maxHeight: (screen.height - 120) * .8,
        ),
        // the backdrop's picture blurred once, as the blocks have it: a live blur on every frame of the popup's
        // opening made it stutter
        child: _FrostedBackdrop(
          radius: 26,
          child: Material(
            // as see-through as the blocks, as chosen in Settings → Themes
            color: dark
                ? const Color(0xFF1C1C1F).withValues(alpha: (clarity.night * 1.2).clamp(0, 1))
                : Colors.white.withValues(alpha: clarity.day * .9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: Colors.white.withValues(alpha: dark ? .14 : .85)),
            ),
            child: child,
          ),
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
    final accent = theme.araLook.neonFill ?? scheme.primary;
    final units = t.avpn.bytesUnits.split(',');
    final start = ref.watch(sessionStartProvider);
    final group = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    final inUse = current != null && current.isGroup ? autoPick(current, group!.items) : current;
    final servers = groupConnections([
      for (final c in ref.watch(connectionsProvider).items)
        if (start != null &&
            !c.start.isBefore(start) &&
            c.route == ConnectionRoute.vpn &&
            c.outbound.isNotEmpty &&
            !isHiddenServer(c.outbound))
          c,
    ], (c) => c.outbound)..sort((a, b) => b.total.compareTo(a.total));
    final total = servers.fold<int>(0, (s, g) => s + g.total);
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
                  child: Icon(Icons.dns_rounded, size: 16, color: accent),
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
                  final delay = info?.urlTestDelay ?? 0;
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
                            Text(
                              name.flag ?? '🌐',
                              style: const TextStyle(fontSize: 20, fontFamilyFallback: ['Emoji']),
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
                              formatBytes(g.total, units),
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

/// Set while a ping of every server runs (from the home screen or the panel), so the lists can show spinners.
final homePingTesting = ValueNotifier(false);

/// Pings every server, unless that's already running.
Future<void> pingAllServers(WidgetRef ref) async {
  if (homePingTesting.value) return;
  homePingTesting.value = true;
  try {
    await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest("select");
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
    final clarity = ref.watch(Preferences.contrastClarity);
    // the backdrop's picture blurred once, not a live blur on every frame of the card's opening
    return _FrostedBackdrop(
      radius: radius,
      child: builder(
        dark
            ? const Color(0xFF1C1C1F).withValues(alpha: (clarity.night * 1.6).clamp(0, 1))
            : Colors.white.withValues(alpha: (clarity.day * 1.3).clamp(0, 1)),
      ),
    );
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
                ? const Color(0xFF1E1E22).withValues(alpha: clarity.night)
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

/// [v] in steps of 2% (0 to 1).
double _step(double v) => v.isFinite ? (v * 50).round() / 50 : 0;
