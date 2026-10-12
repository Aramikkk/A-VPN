import 'package:flutter/material.dart';

//Helper class for storing details for each navigation action in my_adaptive_layout.dart
class ShellRouteAction {
  final IconData icon;
  final String title;

  /// the line icon's shapes (NavIcons); drawn instead of [icon] when set
  final String? svg;

  ShellRouteAction(this.icon, this.title, {this.svg});
}
