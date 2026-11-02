part of 'traffic_sankey.dart';

/// The details of a tapped route: how much, its share, how many connections, and what it is made of (the apps, the
/// sites, the servers, the rules), each with its amount.
class SankeyDetails extends ConsumerWidget {
  const SankeyDetails({super.key, required this.selection, required this.value, this.speedValue, this.rows = 5});

  final SankeySelection selection;
  final String Function(double w) value;
  final String Function(double bytesPerSecond)? speedValue;
  final int rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = switch (selection.route) {
      ConnectionRoute.vpn => theme.araAccent,
      ConnectionRoute.direct => const Color(0xFF9AA0A6),
      ConnectionRoute.block => scheme.error,
      null => scheme.onSurfaceVariant,
    };
    final routeName = switch (selection.route) {
      ConnectionRoute.vpn => t.avpn.statsViaVpn,
      ConnectionRoute.direct => t.avpn.statsDirect,
      ConnectionRoute.block => t.avpn.connBlocked,
      null => null,
    };
    final share = selection.total <= 0 ? 0 : (selection.weight / selection.total * 100).round();
    Map<String, double> by(String Function(SankeyFlow) keyOf) {
      final m = <String, double>{};
      for (final f in selection.flows) {
        final k = keyOf(f);
        if (k.isEmpty) continue;
        m[k] = (m[k] ?? 0) + f.weight;
      }
      return m;
    }

    final sections = [
      (t.avpn.sankeyApps, by((f) => f.app)),
      (t.avpn.sankeySites, by((f) => f.host)),
      (t.avpn.sankeyRules, by((f) => f.rule)),
      (
        t.avpn.sankeyServers,
        {for (final e in by((f) => f.route == ConnectionRoute.vpn ? f.out : '').entries) e.key: e.value},
      ),
    ].where((s) => s.$2.length > 1 || (s.$2.length == 1 && s.$1 == t.avpn.sankeySites)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 36,
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(5)),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (homeLookNow == HomeLayout.dots)
                        flagsText(
                          selection.title,
                          maxLines: 2,
                          width: 21,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        )
                      else
                        Text(
                          selection.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFamilyFallback: const ['Emoji'],
                          ),
                        ),
                      if (routeName != null)
                        Text(
                          routeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AraLook.readableOn(colour, scheme.surfaceContainerLow),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(10),
            Row(
              children: [
                Text(
                  value(selection.weight),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Gap(10),
                Text(
                  t.avpn.sankeyShare(share: share, count: selection.connections),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (speedValue != null)
              Text(
                '${t.avpn.sankeySpeed}: ${speedValue!(selection.speed)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            for (final (title, data) in sections) ...[
              const Gap(14),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Gap(6),
              _Rows(data: data, total: selection.weight, colour: colour, value: value, rows: rows),
            ],
          ],
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.data, required this.total, required this.colour, required this.value, required this.rows});

  final Map<String, double> data;
  final double total;
  final Color colour;
  final String Function(double w) value;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ranked = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final e in ranked.take(rows))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: homeLookNow == HomeLayout.dots
                          ? flagsText(e.key, style: theme.textTheme.bodyMedium, width: 18)
                          : Text(
                              e.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(fontFamilyFallback: const ['Emoji']),
                            ),
                    ),
                    const Gap(8),
                    Text(value(e.value), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const Gap(3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: total <= 0 ? 0 : (e.value / total).clamp(0.0, 1.0),
                    minHeight: 3,
                    color: colour,
                    backgroundColor: scheme.onSurface.withValues(alpha: .08),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A host as the site it belongs to, for the diagram's middle column: "rr4---sn.googlevideo.com" becomes
/// "googlevideo.com", "api.telegram.org" "telegram.org", "a.b.example.co.uk" "example.co.uk"; an address stays as it is.
String siteOf(String host) {
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return '';
  if (RegExp(r'^[\d.]+$').hasMatch(h) || h.contains(':')) return h;
  final parts = h.split('.');
  if (parts.length <= 2) return h;
  // a second-level zone of a country (co.uk, com.tr): one more label
  const zones = {'co', 'com', 'org', 'net', 'gov', 'edu', 'ac'};
  final keep = parts.last.length == 2 && zones.contains(parts[parts.length - 2]) ? 3 : 2;
  return parts.sublist(parts.length - keep).join('.');
}
