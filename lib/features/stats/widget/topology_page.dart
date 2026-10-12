import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hiddify/features/stats/widget/connections_flow.dart';
import 'package:hiddify/features/stats/widget/connections_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Topology tab: the session's connections as flows, app → rule → VPN / direct → server, each as wide as the
/// connections (or the traffic) through it, on the whole screen.
class TopologyPage extends HookConsumerWidget {
  const TopologyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final state = ref.watch(connectionsProvider);
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final byTraffic = useState(false);
    final openOnly = useState(false);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = theme.scaffoldBackgroundColor;

    final hideSmall = useState(true);
    final open = openOnly.value ? state.items.where((c) => c.active).toList() : state.items;
    // apps that moved less than a megabyte are left out, as in Connections
    final bigApps = {
      for (final g in groupConnections(open, (c) => c.app))
        if (g.total >= smallTraffic) g.key,
    };
    final items = hideSmall.value ? open.where((c) => bigApps.contains(c.app)).toList() : open;

    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.topologyTab)),
      body: !state.available && state.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  t.avpn.connNotConnected,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: Text(t.avpn.connFlowCount),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.data_usage_rounded, size: 18),
                            label: Text(t.avpn.connFlowTraffic),
                          ),
                        ],
                        selected: {byTraffic.value},
                        onSelectionChanged: (s) => byTraffic.value = s.first,
                      ),
                      FilterChip(
                        label: Text(t.avpn.connHideSmallChip),
                        selected: hideSmall.value,
                        onSelected: (v) => hideSmall.value = v,
                      ),
                      FilterChip(
                        label: Text(t.avpn.connOpenOnly),
                        selected: openOnly.value,
                        onSelected: (v) => openOnly.value = v,
                      ),
                    ],
                  ),
                  const Gap(10),
                  // the column headings, over their columns
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final step = (constraints.maxWidth * .66 - ConnectionFlowPainter.bar) / 3;
                      final style = theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .8,
                      );
                      return SizedBox(
                        height: 16,
                        child: Stack(
                          children: [
                            for (final (i, text) in [
                              t.avpn.topoApps,
                              t.avpn.topoRules,
                              t.avpn.topoRoute,
                              t.avpn.topoServers,
                            ].indexed)
                              Positioned(
                                left: i * step,
                                width: i == 3 ? constraints.maxWidth - i * step : step - 4,
                                child: Text(
                                  text.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Gap(8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final flow = ConnectionFlow.build(
                          items,
                          byTraffic: byTraffic.value,
                          appName: (app) => connectionAppName(t, apps, app),
                          ruleName: (rule) => ruleLabel(rule) ?? t.avpn.connRuleDefault,
                          routeName: (route) => switch (route) {
                            ConnectionRoute.vpn => 'VPN',
                            ConnectionRoute.direct => t.avpn.statsDirect,
                            ConnectionRoute.block => t.avpn.connBlocked,
                          },
                          other: t.avpn.connOther,
                          palette: flowPalette(scheme.primary, surface),
                          routeColor: (route) => switch (route) {
                            ConnectionRoute.vpn => AraLook.readableOn(scheme.primary, surface),
                            ConnectionRoute.direct => AraLook.readableOn(const Color(0xFF9AA0A6), surface),
                            ConnectionRoute.block => AraLook.readableOn(scheme.error, surface),
                          },
                          // a taller screen names more of them
                          maxPerColumn: (constraints.maxHeight / 56).floor().clamp(4, 12),
                        );
                        if (flow.isEmpty) {
                          return Center(
                            child: Text(t.avpn.connEmpty, style: TextStyle(color: scheme.onSurfaceVariant)),
                          );
                        }
                        return CustomPaint(
                          size: Size.infinite,
                          painter: ConnectionFlowPainter(
                            flow,
                            background: surface,
                            textStyle: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurface, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
