import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/app_based_routing/overview/app_based_routing_notifier.dart';

void main() {
  const installed = {
    'ru.sberbankmobile',
    'ru.rostel',
    'ru.yandex.taxi',
    'com.yandex.browser',
    'com.google.android.youtube',
    'org.telegram.messenger',
  };

  test('"ru.*" becomes the installed apps it covers', () {
    expect(expandAutoList({'ru.*'}, installed), {'ru.sberbankmobile', 'ru.rostel', 'ru.yandex.taxi'});
  });

  test('plain names stay, patterns matching nothing vanish', () {
    expect(expandAutoList({'com.vkontakte.android', 'com.mail.*', 'com.yandex.*'}, installed), {
      'com.vkontakte.android',
      'com.yandex.browser',
    });
  });

  test('blocked apps are never swept in', () {
    final list = expandAutoList({'ru.*', ...russianAppsOutsideRu}, installed);
    expect(list, isNot(contains('com.google.android.youtube')));
    expect(list, isNot(contains('org.telegram.messenger')));
  });
}
