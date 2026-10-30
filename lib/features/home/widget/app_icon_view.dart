import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:hiddify/features/home/model/home_layout.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart' show homeLookNow;
import 'package:hiddify/features/home/widget/pixel_flag.dart';

/// An app's icon as the look draws it: in Dots cells and a smooth sign, in the others the picture itself.
Widget appIconView(Uint8List icon, {required double size}) => homeLookNow == HomeLayout.dots
    ? DotsAppIcon(icon: icon, size: size)
    : Image.memory(icon, width: size, height: size, cacheWidth: (size * 3).round(), gaplessPlayback: true);
