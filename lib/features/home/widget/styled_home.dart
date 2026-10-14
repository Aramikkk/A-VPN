part of 'avpn_home_body.dart';

/// The home screen in Graphite or Editorial: the state at the top, the servers in the middle, and the connect
/// control at the bottom, under the thumb.
class _StyledHome extends HookConsumerWidget {
  const _StyledHome({required this.editorial, required this.testing, required this.onCheck, this.traffic = true});

  final bool traffic;

  final bool editorial;
  final bool testing;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final status = ref.watch(connectionNotifierProvider).valueOrNull ?? const Disconnected();
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
    final header = _ServersHeader(
      editorial: editorial,
      profile: profile,
      testing: testing,
      onCheck: connected && editorial ? onCheck : null,
      showCheck: editorial,
    );
    final dock = editorial
        ? _EditorialDock(status: status)
        : _GraphiteDock(
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
    const gap = Gap(16);
    // the unfolded phone (the traffic in its own column) has room to spare under the servers: it goes in equal
    // shares to the three gaps under them, servers to toggles, toggles to the connect panel, the panel to the menu
    final spread = !traffic && profile != null && servers.isNotEmpty;
    Widget share() => spread ? const Spacer() : const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 2, 18, spread ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBlock(editorial: editorial, status: status, lastServer: currentName),
          if (hasList) ...[
            gap,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Gap(roomy ? 10 : 6),
                SizedBox(
                  height: (servers.length < rowsInSight ? servers.length : rowsInSight) * (editorial ? 66.0 : 62.0),
                  child: _StyledServerList(
                    editorial: editorial,
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
            if (traffic) Expanded(child: _HomeTraffic(editorial: editorial)) else share(),
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
  const _StatusBlock({required this.editorial, required this.status, required this.lastServer});

  final bool editorial;
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

    if (editorial) {
      final line = connected ? '$time · ↓ $down · ↑ $up' : (waiting ?? t.avpn.stNoVpn);
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          line.toUpperCase(),
          maxLines: 2,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
            color: connected ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
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
          const Gap(2),
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
  const _ServersHeader({
    required this.editorial,
    required this.profile,
    required this.testing,
    this.onCheck,
    this.showCheck = true,
  });

  /// the ping check at the end (Graphite has it in the connect panel)
  final bool showCheck;

  final bool editorial;
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
    final label = editorial
        ? theme.textTheme.labelSmall?.copyWith(letterSpacing: 1)
        : theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w800, fontSize: 11);

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
                    (editorial ? t.avpn.stPingMs : t.avpn.stPing).toUpperCase(),
                    style: label?.copyWith(color: onCheck == null ? scheme.onSurfaceVariant : scheme.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (!editorial) return row;
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outline, width: 2)),
      ),
      child: row,
    );
  }
}

class _StyledServerList extends ConsumerWidget {
  const _StyledServerList({
    required this.editorial,
    required this.servers,
    required this.selectedTag,
    required this.autoNow,
    required this.testing,
  });

  final bool editorial;
  final List<OutboundInfo> servers;
  final String? selectedTag;
  final OutboundInfo? autoNow;
  final bool testing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final list = LayoutBuilder(
      builder: (context, box) {
        final base = editorial ? 66.0 : 62.0;
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
            void select() => ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy("select", server.tag);
            return editorial
                ? _EditorialRow(
                    flag: server.isGroup ? null : name.flag,
                    group: server.isGroup,
                    title: title,
                    subtitle: subtitle,
                    delay: server.urlTestDelay,
                    selected: selected,
                    testing: testing,
                    onTap: select,
                  )
                : _GraphiteRow(
                    flag: server.isGroup ? null : name.flag,
                    group: server.isGroup,
                    title: title,
                    subtitle: subtitle,
                    delay: server.urlTestDelay,
                    selected: selected,
                    testing: testing,
                    first: i == 0,
                    onTap: select,
                  );
          },
        );
      },
    );
    if (editorial) return list;
    // Graphite: the rows on the page itself, no card round them
    return list;
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.flag, required this.group, required this.color});

  final String? flag;
  final bool group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: Center(
        child: group
            ? AraIconPaint(child: Icon(Icons.auto_awesome_rounded, size: 17, color: color))
            : Text(flag ?? '🌐', style: const TextStyle(fontSize: 18, fontFamilyFallback: ['Emoji'])),
      ),
    );
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
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12),
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

class _EditorialRow extends StatelessWidget {
  const _EditorialRow({
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
    final ink = selected ? scheme.surface : scheme.onSurface;
    final mono = theme.textTheme.labelSmall;
    final Widget ping;
    if (testing) {
      ping = SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.6, color: ink));
    } else {
      final text = delay <= 0 ? '—' : (delay > 65000 ? '×' : '$delay');
      ping = Text(
        text,
        style: mono?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: selected
              ? _onInk(scheme)
              : (delay > 150 ? scheme.primary : (delay <= 0 ? scheme.onSurfaceVariant : ink)),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : null,
          border: Border(bottom: BorderSide(color: selected ? scheme.onSurface : scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            _Flag(flag: flag, group: group, color: ink),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18, color: ink),
                  ),
                  const Gap(1),
                  Text(
                    subtitle.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono?.copyWith(fontSize: 10, letterSpacing: .8, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Gap(8),
            ping,
          ],
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
    final padding = large ? const EdgeInsets.fromLTRB(12, 16, 12, 16) : const EdgeInsets.fromLTRB(10, 10, 12, 10);
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
    final caption = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant);
    final iconSize = large ? 28.0 : 26.0;
    // no plates: an icon (or a number) over a small caption, pressed as one
    Widget side({required Widget top, required String label, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    );
    // the glowing gauge in the middle; the ping check on its left and the servers answering on its right
    final content = Row(
      children: [
        Expanded(
          child: Center(
            child: side(
              top: on && testing
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: ink))
                  : Icon(Icons.network_ping_rounded, size: iconSize, color: ink),
              label: t.avpn.stPingButton,
              onTap: on && !busy && !testing ? onCheck : null,
            ),
          ),
        ),
        _Orb(
          on: on,
          // connected but no ping yet: the arcs keep filling and emptying until the first one comes, so switching
          // flows straight into the gauge
          busy: busy || (on && !measured),
          size: large ? 88 : 76,
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
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1),
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
                          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .6),
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
    useEffect(() {
      if (busy) {
        spin.repeat();
      } else {
        spin.stop();
      }
      return null;
    }, [busy]);
    // the theme's own colour, the same as the chosen server (not the darker one text uses on white)
    final accent = theme.araLook.neonFill ?? scheme.primary;
    final lossColor = deep(accent);
    // the numbers readable: by day a light accent goes to the text colour; the deep shade lifted a little by night
    final pingInk = dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : scheme.onSurface;
    final lossInk = dark ? Color.lerp(lossColor, Colors.white, .35)! : lossColor;
    final width = size * 2.1;
    final centre = size * .98;
    final height = centre + size * .5 + size * .26;
    final outer = size * .86;
    final inner = size * .7;
    final label = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: size * .15);
    Widget number(String? text, Color ink, bool left) => Positioned(
      top: centre + size * .12,
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
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<Offset>(
              // both arcs glide to new values
              tween: Tween(end: on && !busy ? Offset(ping, loss) : Offset.zero),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, filled, _) => AnimatedBuilder(
                animation: spin,
                builder: (context, _) => CustomPaint(
                  painter: _RainbowPainter(
                    centre: Offset(width / 2, centre),
                    radii: (outer, inner),
                    track: dark ? scheme.outlineVariant.withValues(alpha: .45) : scheme.onSurface.withValues(alpha: .1),
                    colors: (accent, lossColor),
                    fills: (filled.dx, filled.dy),
                    busy: busy,
                    rotation: spin.value,
                    stroke: size * .1,
                  ),
                ),
              ),
            ),
          ),
          number(pingLabel, pingInk, true),
          number(lossLabel, lossInk, false),
          Positioned(
            left: (width - size) / 2,
            top: centre - size / 2,
            width: size,
            height: size,
            child: GestureDetector(
              onTap: onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // one colour, no gradient
                  color: dark ? const Color(0xFF16161A) : Colors.white,
                  boxShadow: on && !busy
                      ? [BoxShadow(color: accent.withValues(alpha: dark ? .45 : .3), blurRadius: 28)]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: size * .42,
                    // the icon in the accent too; by day a light one (yellow, green) can't be read on white, so
                    // it goes black there, as the chosen server's text does
                    color: on
                        ? (theme.araLook.neonFill == null
                              ? (dark ? Colors.white : scheme.primary)
                              : (dark || AraLook.contrast(accent, Colors.white) >= 2.2 ? accent : Colors.black))
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          // the mode, over the button's lower edge in the arcs' gap, clear of the numbers at the sides
          Positioned(
            left: 0,
            right: 0,
            top: centre + size * .5 - size * .13,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: mode == null
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
/// regular ones quiet (the button's own colour, a thin edge, a globe).
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
          Icon(whitelist ? Icons.signal_cellular_alt_rounded : Icons.language_rounded, size: height * .58, color: ink),
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
  _RainbowPainter({
    required this.centre,
    required this.radii,
    required this.track,
    required this.colors,
    required this.fills,
    required this.busy,
    required this.rotation,
    required this.stroke,
  });

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
    double wave(double t) => Curves.easeInOut.transform(t < .5 ? t * 2 : 2 - t * 2);
    final (ping, loss) = busy ? (wave(rotation), wave((rotation + .92) % 1)) : fills;
    // the arcs fade in as the ping's fill grows from nothing (a ping always fills at least .06)
    final shown = busy ? 1.0 : (ping / .06).clamp(0.0, 1.0);
    if (shown == 0) return;
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

  @override
  bool shouldRepaint(_RainbowPainter old) =>
      old.rotation != rotation ||
      old.fills != fills ||
      old.busy != busy ||
      old.colors != colors ||
      old.track != track ||
      old.centre != centre;
}

/// Editorial's connect control: a huge "ВКЛ." / "ВЫКЛ." over a rule, and a big switch.
class _EditorialDock extends ConsumerWidget {
  const _EditorialDock({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = status.isConnected;
    final busy = status.isSwitching;
    final word = busy ? t.avpn.bigWait : (on ? t.avpn.bigOn : t.avpn.bigOff);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: busy ? null : () => _toggleConnection(ref),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: word),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: on ? scheme.primary : scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 56,
                    height: .95,
                    letterSpacing: -2.5,
                    color: busy ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const Gap(12),
          GestureDetector(
            onTap: busy ? null : () => _toggleConnection(ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 92,
              height: 52,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: on ? scheme.onSurface : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: on ? scheme.primary : scheme.surface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accent where it sits on ink (the chosen row, the switch's knob): itself when it reads there, else paper.
Color _onInk(ColorScheme scheme) =>
    AraLook.contrast(scheme.primary, scheme.onSurface) >= 2.6 ? scheme.primary : scheme.surface;

/// The home screen's strip map: where today's traffic went, the apps under a megabyte left out.
class _HomeTraffic extends ConsumerWidget {
  const _HomeTraffic({required this.editorial});

  final bool editorial;

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
    final connected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
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
      items.where((c) => c.route == ConnectionRoute.vpn && c.outbound.isNotEmpty),
      (c) => c.outbound,
    )..sort((a, b) => b.total.compareTo(a.total));
    final theme = Theme.of(context);
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
      ],
    );
  }
}
