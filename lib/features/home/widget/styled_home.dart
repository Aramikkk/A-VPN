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
    final servers = [
      for (final item in group?.items ?? <OutboundInfo>[])
        if (item.isVisible && item.tag != 'balance') item,
    ];
    final autoGroup = group?.items
        .where((i) => i.tag == (group.selected == 'balance' ? 'balance' : 'lowest'))
        .firstOrNull;
    final autoNow = autoGroup == null ? null : autoPick(autoGroup, group!.items);
    final current = group?.items.where((i) => i.tag == group.selected).firstOrNull;
    final picked = current != null && current.isGroup ? autoPick(current, group!.items) : null;
    final serverMode = ref.watch(ConfigOptions.homeNetwork);
    // the folded phone (about 960 high) has room to spare: wider gaps and a bigger connect panel; the unfolded one
    // (about 830) keeps everything tight
    final roomy = MediaQuery.sizeOf(context).height >= 900;
    final rowsInSight = roomy ? 4 : 3;
    final currentName = switch (current?.tag) {
      _ when serverMode => '🏠 ${t.avpn.server}',
      'lowest' || 'balance' => picked == null ? t.avpn.auto : '${t.avpn.auto} · ${_withFlag(serverName(picked))}',
      null => null,
      _ => _withFlag(serverName(current!)),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBlock(editorial: editorial, status: status, lastServer: currentName),
          Gap(roomy ? 20 : 14),
          _ServersHeader(
            editorial: editorial,
            profile: profile,
            testing: testing,
            onCheck: connected && editorial ? onCheck : null,
            showCheck: editorial,
          ),
          Gap(roomy ? 10 : 6),
          if (profile != null && servers.isNotEmpty && traffic) ...[
            // four rows in sight (Auto and three countries), three on a lower screen (the unfolded phone), so the
            // strip map under them fits; the rest a scroll away
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
            Gap(roomy ? 20 : 10),
            // where the traffic went, under the servers (as on the Topology tab)
            Expanded(child: _HomeTraffic(editorial: editorial)),
          ] else
            Expanded(
              child: profile == null
                  ? _EmptyCard(text: t.avpn.noProfile)
                  // the whole list where the traffic has a column of its own
                  : servers.isNotEmpty
                  ? _StyledServerList(
                      editorial: editorial,
                      servers: servers,
                      selectedTag: group?.selected,
                      autoNow: autoNow,
                      testing: testing,
                    )
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
          const Gap(6),
          _CheckRow(onCheck: onCheck, testing: testing, showCheck: false),
          if (editorial)
            _EditorialDock(status: status)
          else
            _GraphiteDock(
              status: status,
              server: connected ? currentName : null,
              testing: testing,
              onCheck: onCheck,
              // only a very tall screen has room to spare for a bigger connect panel; the strip map needs it first
              large: roomy,
            ),
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
    final small = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final accent = theme.araLook.neonFill ?? scheme.primary;
    return Padding(
      // no space of its own on top: the gap under the title bar matches the one above the servers
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            // two lines, as the totals on the right: the session's time, then the speed down and up
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  item(Icons.schedule_rounded, time, colour: scheme.primary),
                  const Gap(2),
                  Row(children: [item(Icons.south_rounded, down), const Gap(10), item(Icons.north_rounded, up)]),
                ],
              ),
            ),
          ),
          const Gap(10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 12, color: AraLook.readableOn(accent, scheme.surface)),
                  const Gap(3),
                  Text('VPN ${formatBytes(vpn, units)}', style: small),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alt_route_rounded, size: 12, color: scheme.onSurfaceVariant),
                  const Gap(3),
                  Text(
                    '${t.avpn.statsDirect} ${formatBytes(direct, units)}',
                    style: small?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
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
            final title = auto
                ? t.avpn.auto
                : _marked(dash < 0 ? name.title : name.title.substring(dash + 3).trim(), name.title);
            final subtitle = auto
                ? (autoNow == null ? t.avpn.autoBestHint : '${t.avpn.stNow}: ${_withFlag(serverName(autoNow!))}')
                : [if (dash > 0) name.title.substring(0, dash).trim(), server.type.toUpperCase()].join(' · ');
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
                  ? Color.alphaBlend(glass.accent.withValues(alpha: glass.dark ? .22 : .5), glass.panel)
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
                    ? BorderSide(color: glass.dark ? glass.accent : Colors.white, width: 1.8)
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
                // the flag on a soft tile
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: dark ? .22 : .14)
                        : scheme.surfaceContainerHighest.withValues(alpha: dark ? .7 : 1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: group
                      ? AraIconPaint(child: Icon(Icons.auto_awesome_rounded, size: 19, color: scheme.primary))
                      : Text(flag ?? '🌐', style: const TextStyle(fontSize: 21, fontFamilyFallback: ['Emoji'])),
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
                if (selected) ...[
                  const Gap(10),
                  AraIconPaint(child: Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary)),
                ],
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

Future<void> _toggleConnection(WidgetRef ref) async {
  if (ref.read(activeProfileProvider).valueOrNull == null) {
    await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
    ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
    return;
  }
  await ref.read(connectionNotifierProvider.notifier).toggleConnection();
}

/// Graphite's connect panel: the glowing ring button, the state and server, and a pill button.
class _GraphiteDock extends ConsumerWidget {
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
    final busy = status.isSwitching;
    final title = switch (status) {
      Connected() => t.avpn.stOn,
      Connecting() => t.avpn.connecting,
      Disconnecting() => t.avpn.disconnecting,
      Disconnected() => t.avpn.stOffShort,
    };
    final glass = theme.araLook.glass;
    final padding = large ? const EdgeInsets.fromLTRB(12, 16, 12, 16) : const EdgeInsets.fromLTRB(10, 10, 12, 10);
    final content = Row(
      children: [
        _Orb(on: on, busy: busy, size: large ? 92 : 74, onTap: busy ? null : () => _toggleConnection(ref)),
        const Gap(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // ON / OFF are short: the larger size fits either way
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              // "Авто" on one line and the country under it, so a long name isn't cut
              Text(
                server?.replaceFirst(' · ', '\n') ?? t.avpn.stNotProtected,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (large ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // connected: check the servers' ping (the ring button disconnects); off: the ring button connects
        if (on) ...[
          const Gap(8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: on ? scheme.surfaceContainerHighest : scheme.primary,
              foregroundColor: on ? scheme.onSurface : scheme.onPrimary,
              padding: large
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 18)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: large ? 15 : 14),
            ),
            onPressed: busy || (on && testing) ? null : (on ? onCheck : () => _toggleConnection(ref)),
            icon: on && testing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurface),
                  )
                : AraIconPaint(
                    enabled: on,
                    child: Icon(on ? Icons.network_ping_rounded : Icons.power_settings_new_rounded, size: 18),
                  ),
            label: Text(on ? t.avpn.stPingButton : t.avpn.stConnect),
          ),
        ],
      ],
    );
    // Glass: floating over the backdrop, what's behind it blurred
    if (glass != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
        child: GlassPane(look: glass, radius: large ? 40 : 32, padding: padding, child: content),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 12),
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

/// The round button: a dark (or white) sphere with a ring in the accent that glows while connected and turns
/// while connecting.
class _Orb extends HookWidget {
  const _Orb({required this.on, required this.busy, this.onTap, this.size = 74});

  final double size;

  final bool on;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final spin = useAnimationController(duration: const Duration(milliseconds: 1400));
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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: spin,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              colors: on || busy
                  // one colour, the accent
                  ? [accent, accent]
                  : [scheme.outlineVariant, scheme.outlineVariant],
              sweep: on ? 1 : (busy ? .3 : 1),
              rotation: spin.value,
            ),
            child: Padding(
              padding: EdgeInsets.all(size * .095),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // one colour, no gradient
                  color: dark ? const Color(0xFF16161A) : Colors.white,
                  boxShadow: on ? [BoxShadow(color: accent.withValues(alpha: dark ? .45 : .3), blurRadius: 28)] : null,
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: size * .4,
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
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.colors, required this.sweep, required this.rotation});

  final List<Color> colors;

  /// how much of the circle the ring covers (1: all of it)
  final double sweep;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(2.5);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * 2 * 3.1415926);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawArc(
      ring,
      -1.57,
      sweep * 2 * 3.1415926,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(colors: colors).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.rotation != rotation || old.sweep != sweep || old.colors != colors;
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
    final sessionStart = ref.watch(statsNotifierProvider).valueOrNull?.sessionStartedAt;
    final current = [
      for (final c in state.items)
        if (sessionStart == null || !c.start.isBefore(sessionStart)) c,
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
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: glass.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: glass.edge, width: 1.2),
        ),
        child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 10), child: strips),
      ),
    );
  }
}
