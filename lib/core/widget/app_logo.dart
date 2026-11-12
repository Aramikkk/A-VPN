import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's mark, as the launcher icon is: an A (a triangle with a triangular hole and a notch at the foot) with a red point in
/// the hole, on a rounded square. By night a silver A on near-black, by day a near-black A on the silver of the night one.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24});

  final double size;

  static String svg({required bool dark}) {
    // night: a silver A on near-black; day: a dark A on the silver of the night A
    final plate = dark
        ? '<rect width="512" height="512" rx="112" fill="#111111"/>'
        : '<defs><linearGradient id="p" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E6E6E6"/>'
              '<stop offset="1" stop-color="#B2B2B8"/></linearGradient></defs>'
              '<rect width="512" height="512" rx="112" fill="url(#p)"/>';
    final from = dark ? '#E6E6E6' : '#22222A';
    final to = dark ? '#B2B2B8' : '#0C0C0E';
    return '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
        '<defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="60" y1="70" x2="452" y2="440">'
        '<stop offset="0" stop-color="$from"/><stop offset="1" stop-color="$to"/></linearGradient></defs>'
        '$plate'
        '<g transform="translate(256 244) scale(.78) translate(-256 -256)">'
        '<path fill-rule="evenodd" fill="url(#g)" d="M256,70 L452,440 L298,440 L256,380 L214,440 L60,440 Z M256,210 L182,360 L330,360 Z"/>'
        '<circle cx="256" cy="300" r="22" fill="#EE4245"/></g></svg>';
  }

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svg(dark: Theme.of(context).brightness == Brightness.dark),
    width: size,
    height: size,
  );
}
