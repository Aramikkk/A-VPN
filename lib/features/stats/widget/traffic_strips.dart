import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show homeLookNow;
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Where the traffic went, as a strip map: a strip per route (through the VPN, direct, blocked), the biggest first,
/// each split into its apps by [weight]. On the Topology tab and on the home screen.
class TrafficStrips extends ConsumerWidget {
  const TrafficStrips({
    super.key,
    required this.items,
    required this.weight,
    required this.value,
    this.compact = false,
    this.barHeight,
    this.headers = true,
    this.directLabel,
  });

  /// the direct strip's name; the home screen calls it «Обход»
  final String? directLabel;

  /// "Через VPN · 72%   283 МБ" over each strip; the traffic panel has the totals in tiles of its own
  final bool headers;

  /// the phone's home screen sets it, so the strips fill the room under the servers
  final double? barHeight;

  final List<SeenConnection> items;
  final double Function(SeenConnection c) weight;
  final String Function(double w) value;

  /// the home screen's: a thinner strip, fewer pieces
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final namesLoading = PlatformUtils.isAndroid && !ref.watch(installedAppsProvider).hasValue;
    double sum(Iterable<SeenConnection> cs) => cs.fold<double>(0, (s, c) => s + weight(c));
    final total = sum(items);
    final strips = <_Strip>[
      for (final route in ConnectionRoute.values)
        if (items.where((c) => c.route == route).toList() case final inRoute
            when inRoute.isNotEmpty || (compact && route != ConnectionRoute.block))
          _Strip(route, sum(inRoute), [
            for (final g in groupConnections(
              inRoute,
              (c) => c.app,
            )..sort((a, b) => sum(b.items).compareTo(sum(a.items))))
              (app: g.key, weight: sum(g.items)),
          ]),
    ];
    // the home screen keeps VPN over the bypass whatever their sizes, so nothing swaps places as traffic comes in
    if (!compact) strips.sort((a, b) => b.weight.compareTo(a.weight));
    // nothing yet: a picture of strips until the traffic comes
    if (strips.isEmpty || (compact && total == 0)) {
      return SizedBox(
        height: compact ? 120 : 170,
        child: Center(child: TrafficPlaceholder(height: compact ? 60 : 85)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, strip) in strips.indexed) ...[
          if (i > 0) Gap(compact ? 10 : 16),
          _StripMap(
            strip: strip,
            total: total,
            value: value,
            compact: compact,
            barHeight: barHeight,
            headers: headers,
            directLabel: directLabel,
            // until the apps' names are read (a moment after the start) a piece has no name rather than a package
            appName: (app) => app == null ? t.avpn.connOther : (namesLoading ? '' : connectionAppName(t, apps, app)),
          ),
        ],
      ],
    );
  }
}

class _Strip {
  _Strip(this.route, this.weight, this.apps);

  final ConnectionRoute route;
  final double weight;

  /// biggest first
  final List<({String app, double weight})> apps;
}

/// One route as a strip: its name, share and amount over it; the strip split into its apps, the biggest in the
/// strongest shade of the route's colour; under it each piece named with its amount, so the thin ones read too.
class _StripMap extends ConsumerWidget {
  const _StripMap({
    required this.strip,
    required this.total,
    required this.value,
    required this.appName,
    this.compact = false,
    this.barHeight,
    this.headers = true,
    this.directLabel,
  });

  final String? directLabel;
  final bool compact;
  final double? barHeight;
  final bool headers;

  final _Strip strip;
  final double total;
  final String Function(double) value;
  final String Function(String? app) appName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Glass: the VPN strip in the scheme's colour, a little deeper; the direct one grey, as everywhere (in a lighter
    // shade of the colour it was taken for the VPN one)
    final glass = theme.glassLook;
    final calm = glass?.calm ?? false;
    Color deeper(Color c) {
      final hsl = HSLColor.fromColor(c);
      return hsl.withLightness((hsl.lightness - .08).clamp(0.0, 1.0)).toColor();
    }

    final base = switch (strip.route) {
      ConnectionRoute.vpn when glass != null => deeper(glass.accent),
      // the theme's own colour, as on the chosen server and the power button
      ConnectionRoute.vpn => theme.araAccent,
      ConnectionRoute.direct => const Color(0xFF9AA0A6),
      ConnectionRoute.block => scheme.error,
    };
    final title = switch (strip.route) {
      ConnectionRoute.vpn => t.avpn.statsViaVpn,
      ConnectionRoute.direct => directLabel ?? t.avpn.statsDirect,
      ConnectionRoute.block => t.avpn.connBlocked,
    };
    // the biggest apps, the rest added up in one piece
    final shown = compact ? 3 : 5;
    final pieces = <({String? app, double weight})>[
      for (final a in strip.apps.take(shown)) (app: a.app, weight: a.weight),
      if (strip.apps.length > shown)
        (app: null, weight: strip.apps.skip(shown).fold<double>(0, (s, a) => s + a.weight)),
    ];
    // the shades step down from the route's own colour
    Color shade(int i) => Color.lerp(base, scheme.surfaceContainerLow, (i * .16).clamp(0, .7))!;
    Color ink(Color fill) => AraLook.contrast(Colors.white, fill) >= 3 ? Colors.white : Colors.black;
    final share = total == 0 ? 0 : (strip.weight / total * 100).round();
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final header = Row(
      children: [
        Expanded(
          child: Text(
            '$title · $share%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: calm && strip.route == ConnectionRoute.vpn
                  ? scheme.primary
                  : AraLook.readableOn(base, scheme.surfaceContainerLow),
            ),
          ),
        ),
        Text(value(strip.weight), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headers) ...[header, Gap(compact ? 4 : 6)],
        // the strip itself: each app as wide as its traffic, its name inside when there is room
        ClipRRect(
          borderRadius: BorderRadius.circular(switch (homeLookNow) {
            HomeLayout.dots => 2,
            HomeLayout.bento => 14,
            _ => 9,
          }),
          child: Container(
            // the strip's track: an empty strip keeps its place on the home screen
            color: homeLookNow == HomeLayout.dots
                ? null
                : base.withValues(alpha: homeLookNow == HomeLayout.bento ? .08 : .12),
            height: compact ? 24 : (homeLookNow == HomeLayout.bento ? 40 : 34),
            child: LayoutBuilder(
              builder: (context, box) {
                final gap = homeLookNow == HomeLayout.bento ? 4.0 : 2.0;
                final gaps = (pieces.length - 1) * gap;
                final room = box.maxWidth - gaps;
                // every piece at least a sliver, the rest shared by traffic
                const least = 4.0;
                final spare = room - least * pieces.length;
                return Row(
                  children: [
                    for (final (i, piece) in pieces.indexed) ...[
                      if (i > 0) SizedBox(width: gap),
                      if (homeLookNow == HomeLayout.dots)
                        SizedBox(
                          width: least + (strip.weight == 0 ? 0 : spare * piece.weight / strip.weight),
                          child: CustomPaint(painter: _DotField(shade(i)), child: const SizedBox.expand()),
                        )
                      else
                        Container(
                          width: least + (strip.weight == 0 ? 0 : spare * piece.weight / strip.weight),
                          decoration: BoxDecoration(
                            color: shade(i),
                            borderRadius: homeLookNow == HomeLayout.bento ? BorderRadius.circular(10) : null,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: least + spare * piece.weight / (strip.weight == 0 ? 1 : strip.weight) > 56
                              ? Text(
                                  appName(piece.app),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: ink(shade(i)),
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        Gap(compact ? 6 : 8),
        // every piece named, with its colour, amount and share of the route; on the home screen two rows of two,
        // always (empty cells keep their room), so the panel never grows or shrinks as apps come and go
        if (compact)
          for (final row in [0, 2]) ...[
            if (row > 0) const Gap(2),
            Row(
              children: [
                for (final i in [row, row + 1]) ...[
                  if (i > row) const Gap(12),
                  Expanded(
                    child: SizedBox(
                      height: 16,
                      child: i >= pieces.length
                          ? null
                          : Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: shade(i),
                                    borderRadius: BorderRadius.circular(_markRadius),
                                  ),
                                ),
                                const Gap(5),
                                Flexible(
                                  child: Text(
                                    appName(pieces[i].app),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(' ${value(pieces[i].weight)}', style: small),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ]
        else
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (i, piece) in pieces.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: shade(i), borderRadius: BorderRadius.circular(_markRadius)),
                    ),
                    const Gap(5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        appName(piece.app),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(' ${value(piece.weight)}', style: small),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

/// How many strips [items] make: one per route that has traffic.
int trafficStripCount(Iterable<SeenConnection> items) => {for (final c in items) c.route}.length;

/// Rows of a name, a share bar and the amount with its share.
class TrafficRanking extends StatelessWidget {
  const TrafficRanking({super.key, required this.rows, required this.total, required this.value, required this.colour});

  final List<(String, double)> rows;
  final double total;
  final String Function(double) value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = rows.fold<double>(0, (m, r) => r.$2 > m ? r.$2 : m);
    Widget row(String name, double w) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Gap(8),
              Text(
                '${value(w)} · ${total <= 0 ? 0 : (w * 100 / total).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Gap(5),
          if (homeLookNow == HomeLayout.dots)
            // Dots: the bar as a row of dots, lit up to its share
            SizedBox(
              height: 6,
              child: CustomPaint(
                painter: _DotField(colour, lit: top <= 0 ? 0 : w / top, faint: scheme.onSurface.withValues(alpha: .15)),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(homeLookNow == HomeLayout.bento ? 5 : 4),
              child: LinearProgressIndicator(
                value: top <= 0 ? 0 : w / top,
                minHeight: homeLookNow == HomeLayout.bento ? 10 : 6,
                color: colour,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
    // two columns where there's the width (the computer, the unfolded phone), the biggest first, read across
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 480) return Column(children: [for (final (name, w) in rows) row(name, w)]);
        return Column(
          children: [
            for (var i = 0; i < rows.length; i += 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: row(rows[i].$1, rows[i].$2)),
                  const Gap(20),
                  Expanded(child: i + 1 < rows.length ? row(rows[i + 1].$1, rows[i + 1].$2) : const SizedBox()),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Shown before there is any traffic: three rounded strips of different lengths, two in the theme's colour (the
/// VPN) and one grey (the bypass), each over its faint track. [height] is the whole picture's.
class TrafficPlaceholder extends StatelessWidget {
  const TrafficPlaceholder({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.araAccent;
    const grey = Color(0xFF9AA0A6);
    // drawn on a 200 x 122 grid: strips 26 high, 10 apart
    final unit = height / 122;
    Widget strip(Color track, Color fill, double share) => ClipRRect(
      borderRadius: BorderRadius.circular(13 * unit),
      child: SizedBox(
        width: 200 * unit,
        height: 26 * unit,
        child: ColoredBox(
          color: track,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: share,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(13 * unit)),
            ),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        strip(accent.withValues(alpha: .15), accent, 2 / 3),
        SizedBox(height: 10 * unit),
        strip(accent.withValues(alpha: .15), accent.withValues(alpha: .6), 5 / 12),
        SizedBox(height: 10 * unit),
        strip(grey.withValues(alpha: .15), grey.withValues(alpha: .6), 5 / 6),
      ],
    );
  }
}

/// a mark's corners in the legend: Dots square, Bento round, the others slightly rounded
double get _markRadius => switch (homeLookNow) {
  HomeLayout.dots => 0,
  HomeLayout.bento => 5,
  _ => 3,
};

/// The Dots look's bar: a row of dots in [colour], lit up to [lit] (0 to 1), the rest faint.
class DotBar extends StatelessWidget {
  const DotBar({super.key, required this.colour, required this.lit, this.height = 6});

  final Color colour;
  final double lit;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: _DotField(colour, lit: lit, faint: Theme.of(context).colorScheme.onSurface.withValues(alpha: .15)),
    ),
  );
}

/// A field of dots in [colour] (Dots' strips and bars): the first [lit] share lit, the rest in [faint].
class _DotField extends CustomPainter {
  _DotField(this.colour, {this.lit = 1, this.faint});

  final Color colour;
  final double lit;
  final Color? faint;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 5.0;
    final r = math.min(1.8, size.height / 2 - .4);
    final lit = <Offset>[];
    final unlit = <Offset>[];
    final rows = size.height < step ? [size.height / 2] : [for (var y = step / 2; y < size.height; y += step) y];
    for (final y in rows) {
      for (var x = step / 2; x < size.width; x += step) {
        (x <= size.width * this.lit ? lit : unlit).add(Offset(x, y));
      }
    }
    // the dots in two calls (one circle at a time was slow while the page scrolled)
    Paint dots(Color c) => Paint()
      ..color = c
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 2;
    canvas.drawPoints(ui.PointMode.points, lit, dots(colour));
    if (faint != null && unlit.isNotEmpty) canvas.drawPoints(ui.PointMode.points, unlit, dots(faint!));
  }

  @override
  bool shouldRepaint(_DotField old) => old.colour != colour || old.lit != lit || old.faint != faint;
}
