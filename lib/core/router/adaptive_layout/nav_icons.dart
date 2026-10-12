import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The menu's line icons: thin rounded strokes in the icon colour the menu gives each state; the chosen tab's
/// lines are bolder.
abstract final class NavIcons {
  /// a shield with a check: the VPN
  static const home =
      '<path d="M12 3.2 19 6v5.6c0 4.3-2.9 7.5-7 9.2-4.1-1.7-7-4.9-7-9.2V6z"/><path d="m9 12 2.1 2.1L15.2 10"/>';

  /// a pulse line: the live speed
  static const stats = '<path d="M3 12.5h3.6l2.4-6 4 12 2.6-7.5 1.4 1.5H21"/>';

  /// two arrows going opposite ways: the connections
  static const connections =
      '<path d="M7 4 3.5 7.5 7 11"/><path d="M3.5 7.5H17"/><path d="m17 13 3.5 3.5L17 20"/><path d="M20.5 16.5H7"/>';

  /// three nodes linked: the topology
  static const topology =
      '<circle cx="5.5" cy="6" r="2.2"/><circle cx="5.5" cy="18" r="2.2"/><circle cx="18.5" cy="12" r="2.2"/><path d="M7.7 6.3c5.3.4 4.3 5.5 8.6 5.7M7.7 17.7c5.3-.4 4.3-5.5 8.6-5.7"/>';

  /// sliders: the settings
  static const settings =
      '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2.2"/><circle cx="9" cy="17" r="2.2"/>';

  /// stacked cards: the profiles
  static const profiles = '<rect x="4" y="8" width="16" height="12" rx="3"/><path d="M7 5h10M9.5 2.5h5"/>';

  /// a page with lines: the logs
  static const logs = '<path d="M7 3h7l4 4v14H7z" stroke-linejoin="round"/><path d="M14 3v4h4M10 12h5M10 16h5"/>';

  /// an i in a circle: about
  static const about = '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.6v.2"/>';
}

class NavIcon extends StatelessWidget {
  const NavIcon(this.paths, {super.key, this.selected = false});

  /// the icon's SVG shapes, drawn on a 24×24 grid
  final String paths;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final colour = icon.color ?? const Color(0xFF888888);
    final size = icon.size ?? 24;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" '
        'stroke-width="${selected ? 2.3 : 1.7}" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
    return SvgPicture.string(svg, width: size, height: size, colorFilter: ColorFilter.mode(colour, BlendMode.srcIn));
  }
}
