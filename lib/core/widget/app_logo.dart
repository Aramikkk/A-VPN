import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's mark, the peak: a mountain with a pass cut under it and a red summit, on a rounded square. Dark on
/// white by day and white on dark by night, as the launcher icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});

  final double size;

  static String svg({required bool dark}) {
    final ground = dark ? '#111111' : '#FAFAFA';
    final body = dark ? '#F5F5F5' : '#111111';
    const cap = '#EE4245';
    return '''
<svg viewBox="0 0 680 680" xmlns="http://www.w3.org/2000/svg">
  <rect width="680" height="680" rx="176" fill="$ground"/>
  <g transform="translate(340 345) scale(.62) translate(-340 -345)" stroke-linejoin="round">
    <path d="M120,520 L340,150 L560,520 Z" fill="$body" stroke="$body" stroke-width="40"/>
    <path d="M265,548 L340,395 L415,548 Z" fill="$ground" stroke="$ground" stroke-width="16"/>
    <path d="M340,150 L400.1,251 L279.9,251 Z" fill="$cap" stroke="$cap" stroke-width="40"/>
  </g>
</svg>''';
  }

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svg(dark: Theme.of(context).brightness == Brightness.dark),
    width: size,
    height: size,
  );
}
