part of 'avpn_home_body.dart';

/// The home screen in Graphite or Editorial: the state at the top, the servers in the middle, and the connect
/// control at the bottom, under the thumb.
class _StyledHome extends HookConsumerWidget {
  const _StyledHome({required this.editorial, required this.testing, required this.onCheck});

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
          const Gap(14),
          _ServersHeader(
            editorial: editorial,
            profile: profile,
            testing: testing,
            onCheck: connected && editorial ? onCheck : null,
            showCheck: editorial,
          ),
          const Gap(6),
          Expanded(
            child: profile == null
                ? _EmptyCard(text: t.avpn.noProfile)
                : servers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        t.avpn.connectToSeeServers,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : _StyledServerList(
                    editorial: editorial,
                    servers: servers,
                    selectedTag: group?.selected,
                    autoNow: autoNow,
                    testing: testing,
                  ),
          ),
          const Gap(6),
          _CheckRow(onCheck: onCheck, testing: testing, showCheck: false),
          if (editorial)
            _EditorialDock(status: status)
          else
            _GraphiteDock(status: status, server: connected ? currentName : null, testing: testing, onCheck: onCheck),
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
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          waiting ?? t.avpn.stTapBelow,
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
        ),
      );
    }
    final big = theme.textTheme.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget item(IconData icon, String text, {Color? colour}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AraIconPaint(child: Icon(icon, size: 18, color: colour ?? scheme.onSurfaceVariant)),
        const Gap(4),
        Text(text, style: big?.copyWith(color: colour)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            item(Icons.schedule_rounded, time, colour: scheme.primary),
            const Gap(18),
            item(Icons.south_rounded, down),
            const Gap(14),
            item(Icons.north_rounded, up),
          ],
        ),
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
        if (remote != null)
          SizedBox(
            width: 30,
            height: 26,
            child: updating
                ? Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: scheme.onSurfaceVariant),
                    ),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    tooltip: t.avpn.stUpdateSub,
                    icon: Icon(Icons.sync_rounded, color: scheme.onSurfaceVariant),
                    onPressed: () => ref.read(updateProfileNotifierProvider(remote.id).notifier).updateProfile(remote),
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
    final scheme = Theme.of(context).colorScheme;
    final list = LayoutBuilder(
      builder: (context, box) {
        final base = editorial ? 66.0 : 64.0;
        final room = box.maxHeight - (editorial ? 0 : 8);
        final rows = (room / base).floor().clamp(1, 1000);
        // whole rows only: they stretch a little so the last one in view isn't cut in half
        final extent = servers.length <= rows ? base : room / rows;
        return ListView.builder(
          itemExtent: extent,
          padding: EdgeInsets.symmetric(vertical: editorial ? 0 : 4, horizontal: editorial ? 0 : 6),
          itemCount: servers.length,
          itemBuilder: (context, i) {
            final server = servers[i];
            final selected = server.tag == selectedTag || (server.tag == 'lowest' && selectedTag == 'balance');
            final name = serverName(server);
            final auto = server.tag == 'lowest';
            // "Финляндия" with "Sigma · VLESS" under it, rather than "Sigma - Финляндия"
            final dash = name.title.indexOf(' - ');
            final title = auto ? t.avpn.auto : (dash < 0 ? name.title : name.title.substring(dash + 3).trim());
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (Theme.of(context).araLook.style == AraStyle.cyberpunk) {
      return Container(clipBehavior: Clip.antiAlias, decoration: _neonPanel(scheme, 14), child: list);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: dark ? .75 : 1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: dark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: list,
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: first || selected ? null : Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [scheme.primary.withValues(alpha: .24), scheme.primary.withValues(alpha: .03)],
                    ),
                    border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _Flag(flag: flag, group: group, color: scheme.primary),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                        ),
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
  const _GraphiteDock({required this.status, required this.server, required this.testing, required this.onCheck});

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
    final cyber = theme.araLook.style == AraStyle.cyberpunk;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: cyber
          ? _neonPanel(scheme, 16)
          : BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: dark ? .85 : 1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: dark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
      child: Row(
        children: [
          _Orb(on: on, busy: busy, onTap: busy ? null : () => _toggleConnection(ref)),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  server ?? t.avpn.stNotProtected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          // connected: check the servers' ping (the ring button disconnects); off: connect
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: on ? scheme.surfaceContainerHighest : scheme.primary,
              foregroundColor: on ? scheme.onSurface : scheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
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
      ),
    );
  }
}

/// The round button: a dark (or white) sphere with a ring in the accent that glows while connected and turns
/// while connecting.
class _Orb extends HookWidget {
  const _Orb({required this.on, required this.busy, this.onTap});

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
    final hsl = HSLColor.fromColor(scheme.primary);
    final second = theme.araLook.style == AraStyle.cyberpunk
        ? theme.araLook.graphUp ?? scheme.primary
        : hsl.saturation < .12
        ? scheme.primary
        : hsl.withHue((hsl.hue + 28) % 360).toColor();
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        height: 74,
        child: AnimatedBuilder(
          animation: spin,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(
              colors: on || busy
                  ? [scheme.primary, second, scheme.primary]
                  : [scheme.outlineVariant, scheme.outlineVariant],
              sweep: on ? 1 : (busy ? .3 : 1),
              rotation: spin.value,
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(0, -.25),
                    colors: dark
                        ? const [Color(0xFF2C2C32), Color(0xFF121215)]
                        : const [Colors.white, Color(0xFFE9E9EE)],
                  ),
                  boxShadow: on
                      ? [BoxShadow(color: scheme.primary.withValues(alpha: dark ? .45 : .3), blurRadius: 28)]
                      : null,
                ),
                child: Center(
                  child: AraIconPaint(
                    enabled: on,
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 30,
                      color: on ? (dark ? Colors.white : scheme.primary) : scheme.onSurfaceVariant,
                    ),
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

/// Cyberpunk's panel: cut corners, a neon outline and a faint neon glow.
ShapeDecoration _neonPanel(ColorScheme scheme, double cut) => ShapeDecoration(
  color: scheme.surfaceContainerLow.withValues(alpha: .9),
  shape: BeveledRectangleBorder(
    borderRadius: BorderRadius.circular(cut),
    side: BorderSide(color: scheme.primary.withValues(alpha: .55)),
  ),
  shadows: [BoxShadow(color: scheme.primary.withValues(alpha: .18), blurRadius: 18)],
);
