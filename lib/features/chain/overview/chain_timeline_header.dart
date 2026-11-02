import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/chain/model/chain_enum.dart';
import 'package:hiddify/features/chain/overview/chain_look.dart';
import 'package:hiddify/features/chain/overview/chain_mode_button.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChainTimelineHeader extends HookConsumerWidget {
  const ChainTimelineHeader(this.level, {super.key});

  final ChainTimelineLevel level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final chain = ref.watch(ConfigOptions.chainStatus);
    // the step that is on has a lit dot; the others a grey one
    final on = switch (level) {
      ChainTimelineLevel.extraSecurity => chain.isExtraSecurity(),
      ChainTimelineLevel.unblocker => chain.isUnblocker(),
      _ => true,
    };
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 16),
      height: 44,
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsetsDirectional.only(start: 3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? ChainLook.accent : ChainLook.line(context)),
          ),
          const Gap(14),
          Icon(level.icon(), size: 18, color: ChainLook.soft(context)),
          const Gap(10),
          Expanded(
            child: Text(
              level.present(t).title.toUpperCase(),
              style: ChainLook.mono(14, ChainLook.ink(context), weight: FontWeight.w700, spacing: 1.6),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Gap(12),
          AnimatedOpacity(
            duration: ChainConst.finalIpDuration,
            opacity:
                (level.isMainProfile() && !ref.watch(ConfigOptions.chainStatus).isExtraSecurity() ||
                    level.isExtraSecurity() && ref.watch(ConfigOptions.chainStatus).isExtraSecurity())
                ? 1
                : 0,
            child: Text(
              t.pages.settings.chain.finalIp,
              style: ChainLook.mono(12, ChainConst.finalIpColor(theme), weight: FontWeight.w700, spacing: 1),
              maxLines: 1,
            ),
          ),
          const Gap(12),
          if (level.isExtraSecurity()) const ChainModeButton.extraSecurity(),
          if (level.isUnblocker()) const ChainModeButton.unblocker(),
        ],
      ),
    );
  }
}
