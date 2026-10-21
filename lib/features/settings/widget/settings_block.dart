import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/ara_style.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';

/// Settings in one outlined block, so a page reads as a whole rather than loose lines.
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final column = Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    // the same frosted glass as the home screen's blocks
    return ContrastFrost(radius: 20, padding: EdgeInsets.zero, solo: true, child: column);
  }
}
