import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/chain/model/chain_enum.dart';
import 'package:hiddify/features/chain/overview/chain_look.dart';
import 'package:hiddify/features/chain/overview/chain_mode_icon.dart';
import 'package:hiddify/features/chain/overview/chain_mode_menu.dart';
import 'package:hiddify/features/common/custom_text_scroll.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChainModeButton extends HookConsumerWidget {
  const ChainModeButton({super.key, required this.type, required this.showConfiguration});

  const ChainModeButton.extraSecurity({super.key, this.showConfiguration = false}) : type = ChainType.extraSecurity;

  const ChainModeButton.unblocker({super.key, this.showConfiguration = false}) : type = ChainType.unblocker;

  final ChainType type;
  final bool showConfiguration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final isDisable = type.isDisable(ref.watch(ConfigOptions.chainStatus));
    final mode = switch (type) {
      ChainType.extraSecurity => ref.watch(ConfigOptions.extraSecurityMode),
      ChainType.unblocker => ref.watch(ConfigOptions.unblockerMode),
    };
    final fColor = isDisable ? ChainLook.soft(context) : ChainLook.ink(context);
    return ChainModeMenu(
      (context, toggleVisibility, child) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDisable ? ChainLook.line(context) : ChainLook.accent, width: 1.5),
        ),
        child: InkWell(
          onTap: toggleVisibility,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 34,
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: isDisable ? const SizedBox() : ChainModeIcon(mode: mode),
                ),
                Flexible(
                  child: CustomTextScroll(
                    isDisable ? t.common.disable : mode.present(t),
                    style: ChainLook.mono(12.5, fColor, weight: FontWeight.w700, spacing: .8),
                  ),
                ),
                const Gap(4),
                Icon(Icons.arrow_drop_down_rounded, size: 16, color: fColor),
              ],
            ),
          ),
        ),
      ),
      type: type,
      showConfiguration: showConfiguration,
    );
  }
}
