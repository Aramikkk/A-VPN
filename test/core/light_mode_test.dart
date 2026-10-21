import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/preferences/light_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the light look takes the time out of the animations', () {
    lightLookNow = false;
    expect(lightDuration(const Duration(milliseconds: 700)), const Duration(milliseconds: 700));
    lightLookNow = true;
    expect(lightDuration(const Duration(milliseconds: 700)), Duration.zero);
    lightLookNow = false;
  });
}
