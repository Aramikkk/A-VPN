import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's mark in the Dots style: the A as big dots (its bar in red, small faint dots inside) on a rounded square.
/// Black on paper by day and light on black by night, as the launcher icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});

  final double size;

  // dot centres as offsets from the middle of the letter (pixels of a 1254 px picture of it), mirrored left and right
  static const _ink = [
    (0, 224),
    (-68, 331),
    (68, 331),
    (-121, 441),
    (121, 441),
    (-174, 553),
    (174, 553),
    (-256, 789),
    (256, 789),
    (-187, 900),
    (187, 900),
    (-311, 900),
    (311, 900),
    (-244, 1013),
    (244, 1013),
    (-364, 1013),
    (364, 1013),
  ];
  static const _bar = [(-70, 673), (70, 673), (-210, 673), (210, 673)];
  static const _k = .30;

  // the shield the letter is knocked out of: its outline (points on the 680 square)
  static const _shield =
      '82,68 598,68 598,340 597,367 594,392 589,417 582,441 573,464 562,486 549,507 534,527 517,546 497,564 476,581 453,598 428,613 401,627 371,640 340,653 340,653 309,640 279,627 252,613 227,598 204,581 183,564 163,546 146,527 131,507 118,486 107,464 98,441 91,417 86,392 83,367 82,340';

  static final _svgs = <bool, String>{};

  static String svg({required bool dark}) => _svgs.putIfAbsent(dark, () {
    final ground = dark ? '#111111' : '#EAE9E5';
    // the shield in the text's colour (white on black, black on paper), the letter in the ground's
    final plate = dark ? '#F2F2EE' : '#111111';
    final letter = dark ? '#111111' : '#EAE9E5';
    final dots = StringBuffer();
    void put(List<(int, int)> list, String colour, double radius) {
      for (final (x, y) in list) {
        dots.write(
          '<circle cx="${(340 + x * _k).toStringAsFixed(1)}" cy="${(340 + (y - 619) * _k + 13.6).toStringAsFixed(1)}" '
          'r="${(radius * _k).toStringAsFixed(1)}" fill="$colour"/>',
        );
      }
    }

    dots.write('<polygon points="$_shield" fill="$plate"/>');
    put(_ink, letter, 52);
    put(_bar, '#EE4245', 52);
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
