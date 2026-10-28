import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's mark in the Dots style: the A as an 11×11 matrix of dots (a triangle with a cut-out at its foot), its
/// top cap red, the unlit dots faint, on a rounded square. Black on paper by day and light on black by night, as the
/// launcher icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});

  final double size;

  static const _n = 11;
  static const _pad = 96.0;

  static bool _inside(double x, double y, (double, double) a, (double, double) b, (double, double) c) {
    double side((double, double) p, (double, double) q, (double, double) r) =>
        (p.$1 - r.$1) * (q.$2 - r.$2) - (q.$1 - r.$1) * (p.$2 - r.$2);
    final p = (x, y);
    final d = [side(p, a, b), side(p, b, c), side(p, c, a)];
    return !(d.any((v) => v < 0) && d.any((v) => v > 0));
  }

  static final _svgs = <bool, String>{};

  static String svg({required bool dark}) => _svgs.putIfAbsent(dark, () {
    final ground = dark ? '#111111' : '#EAE9E5';
    final ink = dark ? '#F2F2EE' : '#111111';
    final faint = dark ? '#2C2C2C' : '#CDCCC7';
    const cap = '#EE4245';
    const step = (680 - 2 * _pad) / (_n - 1);
    final dots = StringBuffer();
    for (var j = 0; j < _n; j++) {
      for (var i = 0; i < _n; i++) {
        final u = i / (_n - 1);
        final v = j / (_n - 1);
        final on =
            _inside(u, v, (.5, 0), (-.02, 1), (1.02, 1)) && !_inside(u, v, (.5, .58), (.27, 1.05), (.73, 1.05));
        final colour = on ? (v < .3 ? cap : ink) : faint;
        final r = step * (on ? .36 : .36 * .55);
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
