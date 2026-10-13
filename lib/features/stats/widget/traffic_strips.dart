import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
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
  });

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
    final scheme = Theme.of(context).colorScheme;
    double sum(Iterable<SeenConnection> cs) => cs.fold<double>(0, (s, c) => s + weight(c));
    final total = sum(items);
    final strips = <_Strip>[
      for (final route in ConnectionRoute.values)
        if (items.where((c) => c.route == route).toList() case final inRoute when inRoute.isNotEmpty)
          _Strip(route, sum(inRoute), [
            for (final g in groupConnections(
              inRoute,
              (c) => c.app,
            )..sort((a, b) => sum(b.items).compareTo(sum(a.items))))
              (app: g.key, weight: sum(g.items)),
          ]),
    ]..sort((a, b) => b.weight.compareTo(a.weight));
    if (strips.isEmpty) {
      return SizedBox(
        height: compact ? 48 : 120,
        child: Center(
          child: Text(t.avpn.connEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, strip) in strips.indexed) ...[
          if (i > 0) Gap(compact ? 14 : 16),
          _StripMap(
            strip: strip,
            total: total,
            value: value,
            compact: compact,
            barHeight: barHeight,
            headers: headers,
            appName: (app) => app == null ? t.avpn.connOther : connectionAppName(t, apps, app),
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
  });

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
    final base = switch (strip.route) {
      // the theme's own colour, as on the chosen server and the power button
      ConnectionRoute.vpn => theme.araLook.neonFill ?? scheme.primary,
      ConnectionRoute.direct => const Color(0xFF9AA0A6),
      ConnectionRoute.block => scheme.error,
    };
    final title = switch (strip.route) {
      ConnectionRoute.vpn => t.avpn.statsViaVpn,
      ConnectionRoute.direct => t.avpn.statsDirect,
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
              color: AraLook.readableOn(base, scheme.surfaceContainerLow),
            ),
          ),
        ),
        Text(value(strip.weight), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headers) ...[header, const Gap(6)],
        // the strip itself: each app as wide as its traffic, its name inside when there is room
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            height: compact ? 26 : 34,
            child: LayoutBuilder(
              builder: (context, box) {
                final gaps = (pieces.length - 1) * 2.0;
                final room = box.maxWidth - gaps;
                // every piece at least a sliver, the rest shared by traffic
                const least = 4.0;
                final spare = room - least * pieces.length;
                return Row(
                  children: [
                    for (final (i, piece) in pieces.indexed) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Container(
                        width: least + (strip.weight == 0 ? 0 : spare * piece.weight / strip.weight),
                        color: shade(i),
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
        const Gap(8),
        // every piece named, with its colour, amount and share of the route
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
                    decoration: BoxDecoration(color: shade(i), borderRadius: BorderRadius.circular(3)),
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
    return Column(
      children: [
        for (final (name, w) in rows)
          Padding(
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top <= 0 ? 0 : w / top,
                    minHeight: 6,
                    color: colour,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
