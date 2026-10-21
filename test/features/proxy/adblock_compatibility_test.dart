import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';

void main() {
  test('the ad block never touches bank and AI domains', () {
    final exceptions = adBlockExceptions();
    for (final host in ['sberbank.ru', 'alfabank.ru', 'openai.com']) {
      expect(exceptions.any((d) => host == d || host.endsWith('.$d')), isTrue, reason: host);
    }
  });
  test('ads are not a routing rule any more (they are Settings → Ads)', () {
    expect(BuiltinRule.values.map((r) => r.name), isNot(contains('blockAds')));
    expect(BuiltinRule.values.map((r) => r.name), contains('blockQuic'));
  });
}
