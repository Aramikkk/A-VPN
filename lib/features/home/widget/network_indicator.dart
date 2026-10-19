import 'package:flutter/material.dart';

/// The physical network centred inside the connect button.
class HomeNetworkIndicator extends StatelessWidget {
  const HomeNetworkIndicator({super.key, required this.mobile, required this.iconSize, required this.color});

  final bool mobile;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: mobile ? 'LTE' : 'Wi-Fi',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const Key('network-symbol'),
          width: iconSize,
          height: iconSize,
          child: mobile
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final height in [.35, .65, 1.0]) ...[
                        if (height != .35) SizedBox(width: iconSize * .13),
                        Container(
                          width: iconSize * .16,
                          height: iconSize * height,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(iconSize * .08)),
                        ),
                      ],
                    ],
                  ),
                )
              : Icon(Icons.wifi_rounded, size: iconSize, color: color),
        ),
        SizedBox(height: iconSize * .12),
        Text(
          mobile ? 'LTE' : 'Wi-Fi',
          style: TextStyle(color: color, fontSize: iconSize * .36, height: 1, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
