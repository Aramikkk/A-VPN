import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Statistics tab: the traffic panel, large, with the speed graph, ping and loss, and active connections.
class SpeedPage extends ConsumerWidget {
  const SpeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final contrast = Theme.of(context).araLook.style == AraStyle.contrast;
    return Scaffold(
      appBar: AppBar(title: Text(t.avpn.speedTab)),
      // it all at once, no scroll: two columns on a wide screen (the unfolded phone), otherwise one column whose
      // graph takes the height the rest leaves; a short window (landscape) still scrolls
      body: LayoutBuilder(
        builder: (context, constraints) => contrast && (!PlatformUtils.isDesktop || constraints.maxWidth < 640)
            // Contrast on the phone, folded or unfolded: fitted over the panel, the graph taking what the rest leaves
            ? const SideBarStatsOverview(large: true, contrast: true)
            : constraints.maxWidth >= 640 && constraints.maxHeight >= 480
            ? const SideBarStatsOverview(large: true, split: true)
            : constraints.maxHeight >= 600
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SideBarStatsOverview(large: true, fill: true),
                  ),
                ),
              )
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
