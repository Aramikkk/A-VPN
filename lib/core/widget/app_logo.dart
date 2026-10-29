import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's mark in the Dots style: a staircase of dots (8 x 8 in blocks of 2 x 2): black blocks in the corner, the
/// step in red, small faint dots beyond, on a rounded square. Black on paper by day and light on black by night, as the
/// launcher icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});

  final double size;

  static const _n = 8;
  static const _pad = 170.0;

  static final _svgs = <bool, String>{};

  static String svg({required bool dark}) => _svgs.putIfAbsent(dark, () {
    final ground = dark ? '#111111' : '#EAE9E5';
    final ink = dark ? '#F2F2EE' : '#111111';
    final faint = dark ? '#2C2C2C' : '#CDCCC7';
    const step = (680 - 2 * _pad) / (_n - 1);
    final dots = StringBuffer();
    for (var j = 0; j < _n; j++) {
      for (var i = 0; i < _n; i++) {
        final total = i ~/ 2 + j ~/ 2;
        final colour = total < 3 ? ink : (total == 3 ? '#EE4245' : faint);
        final r = step * (total <= 3 ? .47 : .13);
        dots.write(
          '<circle cx="${(_pad + i * step).toStringAsFixed(1)}" cy="${(_pad + j * step).toStringAsFixed(1)}" '
          'r="${r.toStringAsFixed(1)}" fill="$colour"/>',
        );
      }
    }
    return '<svg viewBox="0 0 680 680" xmlns="http://www.w3.org/2000/svg">'
        '<rect width="680" height="680" rx="176" fill="$ground"/>$dots</svg>';
  });

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svg(dark: Theme.of(context).brightness == Brightness.dark),
    width: size,
    height: size,
  );
}
