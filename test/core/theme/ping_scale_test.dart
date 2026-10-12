import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/theme/ara_accent.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + .05) / ((la > lb ? lb : la) + .05);
}

void main() {
  for (final accent in AraAccent.values) {
    for (final dark in [false, true]) {
      test('${accent.name} ${dark ? 'dark' : 'light'}: every ping colour is readable and the steps differ', () {
        final scale = AraLook.pingScale(dark ? accent.darkPrimary : accent.lightPrimary, dark: dark);
        final card = dark ? const Color(0xFF17171A) : const Color(0xFFFBFBFB);
        for (final c in scale) {
          expect(contrast(c, card), greaterThanOrEqualTo(2.95), reason: '$c on $card');
        }
        expect(scale.toSet().length, 4, reason: 'fast and slow must look different');
      });
    }
  }
}
