import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/route_rules/notifier/rkn_ru_domains.dart';
import 'package:hiddify/features/route_rules/notifier/ru_services.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';

void main() {
  test('Russian sites direct cover Russian services outside the Russian zones', () {
    final rule = BuiltinRule.ruDomainsDirect.rule;
    expect(rule.outbound, Outbound.direct);
    expect(
      rule.domainSuffixes,
      containsAll(['ru', 'su', 'xn--p1ai', 'yandex.net', 'yastatic.net', 'avito.st', 'userapi.com']),
    );
  });

  test('Russian apps go direct by package, browsers are left out', () {
    final rule = BuiltinRule.ruAppsDirect.rule;
    expect(rule.outbound, Outbound.direct);
    expect(rule.packageNames, containsAll(['ru.yandex.music', 'com.avito.android', 'ru.rostel', 'ru.sberbankmobile']));
    expect(rule.packageNames.where((p) => p.contains('browser')), isEmpty);
    expect(ruAppPackages.toSet().length, ruAppPackages.length, reason: 'no duplicates');
  });

  test('blocked sites come before the direct rules', () {
    final order = BuiltinRule.values;
    for (final group in [
      BuiltinRule.aiProxy,
      BuiltinRule.googleProxy,
      BuiltinRule.socialProxy,
      BuiltinRule.blockedProxy,
    ]) {
      expect(order.indexOf(group), lessThan(order.indexOf(BuiltinRule.ruDomainsDirect)), reason: group.name);
    }
    // none of the Russian services is on the blocked list
    expect(ruServiceDomains.where(rknRuDomains.contains), isEmpty);
  });
}
