import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/features/stats/notifier/speed_history.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/traffic_history.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'side_bar_graphs.dart';
part 'side_bar_quality.dart';

/// The traffic panel: live speed on the accent gradient, then matching tiles for this session, the share that
/// went through the VPN and the share that went direct. In the desktop sidebar, and [large] (with the last
/// minute's speed graph) on the phone's Speed tab.
class SideBarStatsOverview extends ConsumerWidget {
  const SideBarStatsOverview({
    super.key,
    this.large = false,
    this.dense = false,
    this.fill = false,
    this.split = false,
    this.contrast = false,
  });

  /// the phone's Statistics tab in Contrast, over the panel: a ring of the session's routes with its traffic in
  /// the middle beside the speed and the connections, the graph under them taking the room left, the period
  /// under it
  final bool contrast;

  final bool large;

  /// [large] made to fit one screen height (the unfolded phone's home, beside the servers): a lower graph,
  /// legend and figures on one line, compact cards
  final bool dense;

  /// [dense] stretched to the height it's given (the unfolded home, level with the servers' column): the graph
  /// takes the room left over; no padding of its own
  final bool fill;

  /// [large] in two columns filling the height it's given (the unfolded phone's Statistics tab): the speed block
  /// on the left with the graph taking the room left over, ping and the tiles on the right
  final bool split;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // followed only while in sight: the phone's Statistics tab, hidden behind another tab, rebuilt every second
    // and could cost a swipe a frame (it comes back up to date when shown again)
    final visible = TickerMode.of(context);
    T follow<T>(ProviderListenable<T> provider) => visible ? ref.watch(provider) : ref.read(provider);
    final stats = follow(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = theme.araLook.gradient;
    final units = t.avpn.bytesUnits.split(',');
    String size(int bytes) => formatBytes(bytes, units);
    String speed(int bytes) => '${formatBytes(bytes, units)}${t.avpn.perSecond}';

    // the whole session's totals: the core's own counters restart at every reload (network or server change)
    final session = follow(sessionTotalsProvider);
    final total = session.up + session.down;
    final vpnUp = session.vpnUp;
    final vpnDown = session.vpnDown;
    final vpn = vpnUp == null || vpnDown == null ? null : vpnUp + vpnDown;
    final direct = vpn == null ? null : (total - vpn).clamp(0, total);
    final share = vpn == null || total == 0 ? null : (vpn / total).clamp(0.0, 1.0);
    final onSpeed = gradient != null ? theme.araLook.onGradient : scheme.onPrimaryContainer;
    final minute = follow(speedHistoryProvider);
    // the Statistics tab picks the period; the sidebar always shows the last minute
    // the Statistics tab and the computer's sidebar pick the period; elsewhere it's the last minute
    final pickRange = large || PlatformUtils.isDesktop;
    final range = pickRange ? ref.watch(statsRangeProvider) : StatsRange.minute;
    follow(trafficHistoryProvider);
    final series = range == StatsRange.minute ? null : ref.read(trafficHistoryProvider.notifier).series(range);
    final history = series?.points ?? minute;
    final periodName = switch (range) {
      StatsRange.minute => t.avpn.rangeMinute,
      StatsRange.tenMinutes => t.avpn.rangeTenMinutes,
      StatsRange.hour => t.avpn.rangeHour,
      StatsRange.day => t.avpn.rangeDay,
      StatsRange.all => t.avpn.periodAllTime,
    };
    final period = pickRange ? (series ?? ref.read(trafficHistoryProvider.notifier).series(range)).total : null;
    final slots = series?.slots ?? SpeedHistory.length;
    String two(int n) => n.toString().padLeft(2, '0');
    final since = ref.read(trafficHistoryProvider.notifier).since;
    final sinceLabel = since == null ? '' : '${two(since.day)}.${two(since.month)}';
    final ticks = switch (range) {
      // the same shape on every period: the start with its unit, three marks, now
      StatsRange.minute => ['−60 с', '−45', '−30', '−15', t.avpn.graphNow],
      StatsRange.tenMinutes => ['−10 мин', '−7,5', '−5', '−2,5', t.avpn.graphNow],
      StatsRange.hour => ['−60 мин', '−45', '−30', '−15', t.avpn.graphNow],
      StatsRange.day => ['−24 ч', '−18', '−12', '−6', t.avpn.graphNow],
      StatsRange.all => [sinceLabel, '', '', '', t.avpn.graphToday],
    };
    final quality = follow(connectionQualityProvider);
    final downColor = theme.araLook.graphDown ?? onSpeed;
    final upColor = theme.araLook.graphUp ?? onSpeed.withValues(alpha: .7);
    // on a neon fill the text stays solid black: faded black reads as grey mud on the colour
    final solid = theme.araLook.neonFill != null;
    Color soft(double alpha) => solid ? onSpeed : onSpeed.withValues(alpha: alpha);

    final compact = !large || dense;
    final vpnTile = _Tile(
      icon: Icons.shield_rounded,
      title: large && !dense ? t.avpn.statsViaVpn : 'VPN',
      value: vpn == null ? '—' : size(vpn),
      share: share,
      accent: true,
      compact: compact,
    );
    final directTile = _Tile(
      icon: Icons.alt_route_rounded,
      title: t.avpn.statsDirect,
      value: direct == null ? '—' : size(direct),
      share: share == null ? null : 1 - share,
      compact: compact,
    );

    final graph = _SlidingGraph(
      samples: history,
      // the last minute slides on as each second comes in; longer periods just redraw
      live: range == StatsRange.minute,
      painter: (slide) => _SpeedGraph(
        history,
        slide: slide,
        color: onSpeed,
        downColor: downColor,
        upColor: upColor,
        label: (value, top) {
          // every mark of the scale in the top mark's unit: «1,5 МБ/с … 0,5 МБ/с», not «512 КБ/с» under «1 МБ/с»
          var unit = 0;
          var div = 1.0;
          while (top / div >= 1024 && unit < units.length - 1) {
            div *= 1024;
            unit++;
          }
          final v = value / div;
          // «0,25», «0,5», «1», «37,5», «150»: as many decimals as the mark has, at most two
          var text = v >= 100 ? '${v.round()}' : v.toStringAsFixed(2);
          if (text.contains('.')) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
          text = text.replaceAll('.', ',');
          return '$text ${units[unit]}${t.avpn.perSecond}';
        },
        detailed: large,
        textStyle: theme.textTheme.labelSmall!.copyWith(
          color: soft(.75),
          fontSize: 10,
          fontWeight: solid ? FontWeight.w700 : null,
        ),
        ticks: ticks,
        slots: slots,
      ),
    );
    final speedBlock = Container(
      padding: EdgeInsets.fromLTRB(16, dense ? 12 : 14, 16, large && !dense ? 16 : 12),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? scheme.primaryContainer : null,
        border: theme.araLook.border == null ? null : Border.all(color: theme.araLook.border!),
        borderRadius: BorderRadius.circular(large ? 24 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // two different things, each named: the speed right now on the left, and on the right how much traffic
          // moved in the period the graph shows
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // the narrow sidebar says just «Скорость»: «Скорость сейчас» ran into «Трафик за 1 мин» and was cut
              Expanded(
                child: _Caption(pickRange && large ? t.avpn.statsSpeedNow : t.avpn.statsSpeed, color: soft(.8)),
              ),
              if (period != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Caption(t.avpn.statsTrafficFor(period: periodName), color: soft(.8)),
                    const Gap(2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: size(period.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (period.total > 0)
                            TextSpan(text: '  ·  VPN ${(period.vpn * 100 / period.total).round()}%'),
                        ],
                      ),
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(color: soft(.9)),
                    ),
                  ],
                ),
            ],
          ),
          const Gap(8),
          _SpeedRow(
            icon: Icons.south_rounded,
            label: t.avpn.statsDownload,
            value: speed(stats.downlink.toInt()),
            color: onSpeed,
            big: true,
          ),
          const Gap(4),
          _SpeedRow(
            icon: Icons.north_rounded,
            label: t.avpn.statsUpload,
            value: speed(stats.uplink.toInt()),
            color: onSpeed,
          ),
          ...[
            if (pickRange) ...[
              Gap(dense || !large ? 8 : 12),
              _RangePicker(range: range, color: onSpeed, short: !large),
              Gap(dense || !large ? 6 : 10),
              // what the graph is: the speed over the period
              _Caption(t.avpn.statsSpeedFor(period: periodName), color: soft(.8)),
            ],
            Gap(large && !dense ? 12 : 10),
            if (fill || split)
              Expanded(
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 160), child: graph),
              )
            else
              SizedBox(height: dense ? 92 : (large ? 130 : 64), child: graph),
            const Gap(8),
            _GraphSummary(
              history: history,
              color: onSpeed,
              downColor: downColor,
              upColor: upColor,
              speed: speed,
              oneLine: dense,
            ),
          ],
        ],
      ),
    );

    final sessionPair = _pair(
      _Tile(
        icon: Icons.data_usage_rounded,
        title: t.avpn.statsSessionShort,
        value: size(total),
        detail: large
            ? '↓ ${size(session.down)}   ↑ ${size(session.up)}'
            : '↓ ${size(session.down)}\n↑ ${size(session.up)}',
        compact: compact,
      ),
      _Tile(
        icon: Icons.lan_rounded,
        title: t.avpn.statsConnectionsShort,
        value: '${stats.connectionsIn}',
        showBar: false,
        compact: compact,
      ),
    );

    if (contrast) {
      final accent = theme.araAccent;
      // the figures and labels in the accent: graphite by day when it's too light to read (Contrast's citrus)
      final accentText = theme.araIcon;
      final dark = theme.brightness == Brightness.dark;
      final ink = scheme.onSurface;
      final muted = scheme.onSurfaceVariant;
      Widget pane({required Widget child, EdgeInsets padding = const EdgeInsets.all(10)}) =>
          Container(padding: padding, child: child);
      // as dense as the other pages' cards (solo), not the lighter home block that has tiles of its own inside
      Widget block(Widget child) => ContrastFrost(solo: true, child: child);
      final contrastGraph = _SlidingGraph(
        samples: history,
        live: range == StatsRange.minute,
        painter: (slide) => _SpeedGraph(
          history,
          slide: slide,
          color: ink,
          downColor: accent,
          // Dots: the upload in the paper's grey, not blue
          upColor: homeLookNow == HomeLayout.dots
              ? (dark ? const Color(0xFF9A9A95) : const Color(0xFF6A6A66))
              : (dark ? const Color(0xFF9FB4C7) : const Color(0xFF6F8BA3)),
          label: (value, top) => size(value) + t.avpn.perSecond,
          detailed: true,
          textStyle: theme.textTheme.labelSmall!.copyWith(color: muted, fontSize: 10),
          ticks: ticks,
          slots: slots,
        ),
      );
      final speedPage = block(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: pane(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.avpn.statsSpeedFor(period: periodName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (period != null)
                          Text(
                            period.total > 0
                                ? '${size(period.total)} · VPN ${(period.vpn * 100 / period.total).round()}%'
                                : size(period.total),
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                    const Gap(8),
                    Expanded(child: contrastGraph),
                  ],
                ),
              ),
            ),
            const Gap(6),
            _RangePicker(range: range, color: accentText),
          ],
        ),
      );
      // two pages, one under the other: the session, the speed now and the day's losses; the speed graph a whole
      // page down
      final firstPage = LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxHeight < 420 && box.maxWidth >= 560;
          final ping = block(_PingBlock(range: range));
          final losses = block(const _LossDay());
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
            // the ping over the period on top, the session's losses under it (side by side on a short, wide page)
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ping),
                      const Gap(8),
                      Expanded(child: losses),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: ping),
                      const Gap(8),
                      Expanded(flex: 2, child: losses),
                      if (!PlatformUtils.isDesktop || MediaQuery.sizeOf(context).width < 760) ...[
                        const Gap(8),
                        // the name of the page under this one, the arrow before it
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.keyboard_arrow_down_rounded, color: muted),
                            const Gap(4),
                            Text(
                              t.avpn.statsSpeed,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          );
        },
      );
      // a computer's window has the room: the speed graph beside the ping, nothing hidden a page down (the mouse
      // can't swipe there)
      return LayoutBuilder(
        builder: (context, box) => PlatformUtils.isDesktop && box.maxWidth >= 760
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: firstPage),
                  Expanded(
                    child: Padding(padding: const EdgeInsets.fromLTRB(0, 0, 14, 10), child: speedPage),
                  ),
                ],
              )
            : PageView(
                scrollDirection: Axis.vertical,
                children: [
                  firstPage,
                  Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 22), child: speedPage),
                ],
              ),
      );
    }
    if (split) {
      // both columns end on the same line, filling the screen with no scroll: the graph and the ping bars take
      // what the rest leaves
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: speedBlock),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _QualityCard(samples: quality, range: range, fill: true),
                  ),
                  const Gap(10),
                  sessionPair,
                  const Gap(10),
                  _pair(vpnTile, directTile),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: fill
          ? EdgeInsets.zero
          : dense
          ? const EdgeInsets.fromLTRB(12, 4, 12, 8)
          : EdgeInsets.all(large ? 16 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (fill) Expanded(child: speedBlock) else speedBlock,
          Gap(large ? 10 : 8),
          _QualityCard(samples: quality, compact: compact, range: range),
          const Gap(8),
          sessionPair,
          const Gap(8),
          _pair(vpnTile, directTile),
        ],
      ),
    );
  }
}

/// Two tiles side by side, the same height.
Widget _pair(Widget a, Widget b) => IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: a),
      const Gap(8),
      Expanded(child: b),
    ],
  ),
);

/// One stat as a card: icon, caption, value, and either a detail line or a share bar with its percentage.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
    this.showBar = true,
    this.share,
    this.accent = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  /// the share bar under the value (when there's no detail line)
  final bool showBar;
  final double? share;
  final bool accent;

  /// the sidebar's narrow version: no icon, tighter, smaller value
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = accent ? theme.araLook.gradient : null;
    final color = accent ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: compact ? const EdgeInsets.fromLTRB(10, 8, 10, 9) : const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!compact) ...[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    color: gradient == null ? color.withValues(alpha: .15) : null,
                  ),
                  child: Icon(icon, size: 13, color: gradient != null ? theme.araLook.onGradient : color),
                ),
                const Gap(8),
              ],
              Expanded(
                // tiles are narrow on a phone too: tight captions everywhere
                child: _Caption(title, color: scheme.onSurfaceVariant, tight: true),
              ),
              if (share != null) ...[
                Gap(compact ? 2 : 6),
                Text(
                  '${(share! * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ],
          ),
          Gap(compact ? 4 : 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap(compact ? 4 : 6),
          if (detail == null && !showBar)
            const SizedBox.shrink()
          else if (detail != null)
            Text(detail!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share ?? 0,
                minHeight: 5,
                color: accent ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: .55),
                backgroundColor: scheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.color, this.tight = false});

  final String text;
  final Color color;

  /// narrow tiles: less letter spacing, so the caption fits
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(letterSpacing: tight ? .3 : 1.1, fontWeight: FontWeight.w600, color: color),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: big ? 28 : 22,
          height: big ? 28 : 22,
          decoration: BoxDecoration(color: color.withValues(alpha: .18), shape: BoxShape.circle),
          child: Icon(icon, size: big ? 16 : 13, color: color),
        ),
        const Gap(10),
        Expanded(
          child: Tooltip(
            message: label,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (big ? theme.textTheme.titleLarge : theme.textTheme.bodyMedium)?.copyWith(
                color: color,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
