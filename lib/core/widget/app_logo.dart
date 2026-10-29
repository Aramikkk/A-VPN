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
  static const _k = .42;

  // the shield the letter is knocked out of: its outline (points on the 680 square)
  static const _shield =
      '88,115 139,105 189,98 239,92 290,89 340,88 390,89 441,92 491,98 541,105 592,115 592,340 591,366 588,391 583,415 576,439 567,461 556,482 544,503 529,522 512,541 493,559 473,575 450,591 426,606 399,620 370,633 340,645 340,645 310,633 281,620 254,606 230,591 207,575 187,559 168,541 151,522 136,503 124,482 113,461 104,439 97,415 92,391 89,366 88,340';

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
          '<circle cx="${(340 + x * _k).toStringAsFixed(1)}" cy="${(340 + (y - 619) * _k + 6.8).toStringAsFixed(1)}" '
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
