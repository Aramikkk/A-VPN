import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The phone's Speed tab: the same traffic panel as the desktop sidebar, large, with the speed graph.
class SpeedPage extends ConsumerWidget {
  const SpeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.speedTab)),
      body: const SingleChildScrollView(child: SideBarStatsOverview(large: true)),
    );
  }
}
