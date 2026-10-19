import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';

void main() {
  List<Rule> defaults() => [
    for (var i = 0; i < BuiltinRule.values.length; i++)
      BuiltinRule.values[i].rule
        ..enabled = true
        ..listOrder = i,
  ];
  test('bank and AI domains precede adblock without exempting their apps', () {
    final rules = splitGroups(defaults());
    final block = rules.indexWhere((r) => BuiltinRule.of(r) == BuiltinRule.blockAds);
    for (final host in [
      'svi.online.sberbank.ru',
      'metrics.alfabank.ru',
      'appmetrica.sovcombank.ru',
      'bzr.openai.com',
      'bzrcdn.openai.com',
    ]) {
      final index = rules.indexWhere((r) => r.domainSuffixes.any((d) => host == d || host.endsWith('.$d')));
      expect(index, inInclusiveRange(0, block - 1), reason: host);
      expect(rules[index].outbound, host.endsWith('openai.com') ? Outbound.proxy : Outbound.direct);
      expect(rules[index].packageNames, isEmpty);
      expect(rules[index].processNames, isEmpty);
      // The Go core sorts by listOrder; stable ties must keep exceptions next
      // to adblock, after LAN/QUIC, rather than moving them to position zero.
      expect(rules[index].listOrder, rules[block].listOrder);
    }
    expect(rules.indexWhere((r) => BuiltinRule.of(r) == BuiltinRule.blockQuic), lessThan(block));
  });
  test('disabled groups do not create compatibility exceptions', () {
    final list = defaults();
    for (final rule in list) {
      if ([BuiltinRule.banksDirect, BuiltinRule.aiProxy].contains(BuiltinRule.of(rule))) rule.enabled = false;
    }
    expect(splitGroups(list).where((r) => r.name.endsWith(':adblock-compatibility')), isEmpty);
  });
}
