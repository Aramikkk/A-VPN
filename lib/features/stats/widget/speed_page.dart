import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Statistics tab: the traffic panel, large, with the speed graph, ping and loss, and active connections.
class SpeedPage extends ConsumerWidget {
  const SpeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Scaffold(
      appBar: AppBar(
        // what the page counts: this session (as Topology says its day)
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.avpn.speedTab),
            Text(
              t.avpn.statsForSession,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      // fitted over the panel (the phone, folded or unfolded), the graph taking what the rest leaves
      body: const SideBarStatsOverview(large: true, contrast: true),
    );
  }
}
