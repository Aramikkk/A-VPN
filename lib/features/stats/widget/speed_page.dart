import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Statistics tab: the traffic panel, large, with the speed graph, ping and loss, and active connections.
class SpeedPage extends ConsumerWidget {
  const SpeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.speedTab)),
      // on a wide window the panel stays a readable width
      // a wide screen (the unfolded phone) shows it all at once in two columns; otherwise one column that scrolls
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 640 && constraints.maxHeight >= 480
            ? const SideBarStatsOverview(large: true, split: true)
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: const SideBarStatsOverview(large: true),
                  ),
                ),
              ),
      ),
    );
  }
}
