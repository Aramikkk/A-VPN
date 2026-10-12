import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/blocked_only_routing.dart';
import 'package:hiddify/features/route_rules/notifier/rule_groups.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';

List<Rule> get _defaults => [
  for (final builtin in BuiltinRule.values) builtin.rule..enabled = builtin.enabledByDefault,
];

void main() {
  final rules = BlockedOnlyRouting.rules(list: _defaults, extraProxyHosts: ['www.gstatic.com']);
  final suffixes = [
    for (final rule in rules.where((r) => r['outbound'] == 'select'))
      ...?(rule['domain_suffix'] as List?)?.cast<String>(),
  ];

  /// Where a host goes: the first rule whose suffixes hold it, or everything else (direct).
  String route(String host) {
    for (final rule in rules) {
      final list = (rule['domain_suffix'] as List?)?.cast<String>();
      if (list == null || rule.containsKey('protocol')) continue;
      if (list.any((s) => host == s || host.endsWith('.$s'))) return rule['outbound'] as String? ?? 'reject';
    }
    return 'direct §hide§';
  }

  test('the list in its order, then everything else direct', () {
    expect(rules.first, {
      'domain_suffix': ['www.gstatic.com'],
      'action': 'route',
      'outbound': 'select',
    });
    expect(rules[1]['ip_cidr'], contains('192.168.0.0/16'));
    expect(rules[2], {
      'protocol': ['quic'],
      'action': 'reject',
    });
    expect(rules.last, {
      'network': ['tcp', 'udp'],
      'action': 'route',
      'outbound': 'direct §hide§',
    });
    // ads are a rule-set, which this mode can't load
    expect(rules.where((r) => r.containsKey('rule_set')), isEmpty);
  });

  test('AI, Google, social networks and blocked sites through the VPN; Russian ones direct', () {
    for (final host in [
      'chatgpt.com',
      'claude.ai',
      'api.anthropic.com',
      'gemini.google.com',
      'notebooklm.google',
      'grok.com',
      'chat.deepseek.com',
      'copilot.microsoft.com',
      'www.youtube.com',
      'rr1.googlevideo.com',
      'play.googleapis.com',
      'www.google.ru',
      'instagram.com',
      'web.telegram.org',
      'discord.com',
      'www.snapchat.com',
      'www.roblox.com',
      'www.twitch.tv',
      'netflix.com',
      'rutracker.org',
      'tvrain.ru', // blocked, though .ru
    ]) {
      expect(route(host), 'select', reason: host);
    }
    for (final host in [
      'alice.yandex.ru',
      'yandex.ru',
      'uniproxy.alice.yandex.net',
      'ya.ru',
      'vk.com',
      'example.com',
    ]) {
      expect(route(host), 'direct §hide§', reason: host);
    }
  });

  test('each blocked domain is in exactly one group', () {
    final groups = [aiDomains, googleDomains, socialDomains, otherBlockedDomains];
    final all = groups.expand((g) => g).toList();
    expect(all.toSet().length, all.length);
    expect(aiDomains, contains('chatgpt.com'));
    expect(googleDomains, contains('googlevideo.com'));
    expect(socialDomains, containsAll(['instagram.com', 'telegram.org', 'discord.com', 'twitter.com']));
    expect(otherBlockedDomains, containsAll(['netflix.com', 'tvrain.ru']));
    expect(suffixes.where((d) => d.contains('yandex')), isEmpty);
  });

  test('a group of sites and apps is two rules; every Google app goes by pattern', () {
    final apps = rules.where((r) => r.containsKey('package_name')).toList();
    expect(apps.length, 3); // AI, Google, Russian
    expect(apps[0]['package_name'], containsAll(['com.openai.chatgpt', 'com.anthropic.claude']));
    expect(apps[1]['package_name'], contains('com.android.vending'));
    final pattern = RegExp((apps[1]['package_name_regex'] as List).single as String);
    expect(pattern.hasMatch('com.google.android.apps.nbu.files'), isTrue);
    expect(pattern.hasMatch('com.android.chrome'), isFalse);
    expect(apps[2]['outbound'], 'direct §hide§');
    expect(rules.where((r) => r.containsKey('package_name') && r.containsKey('domain_suffix')), isEmpty);
  });

  test("the user's own rules keep their place; a switched-off one is left out", () {
    final withUser = BlockedOnlyRouting.rules(
      list: [
        Rule(name: 'mine', enabled: true, outbound: Outbound.direct, domainSuffixes: ['example.org']),
        Rule(name: 'off', enabled: false, outbound: Outbound.proxy, domains: ['off.example']),
        Rule(name: 'ports', enabled: true, outbound: Outbound.block, portRanges: ['25', '1000:2000']),
        Rule(name: 'set', enabled: true, outbound: Outbound.proxy, ruleSets: ['https://example.org/x.srs']),
        ..._defaults,
      ],
    );
    expect(withUser[0], {
      'domain_suffix': ['example.org'],
      'action': 'route',
      'outbound': 'direct §hide§',
    });
    expect(withUser[1], {
      'port': [25],
      'port_range': ['1000:2000'],
      'action': 'reject',
    });
    expect(withUser.length, rules.length + 1); // two added, the ping host's rule not there
  });

  test('the core gets a group as two rules in the group place', () {
    final split = splitGroups(_defaults);
    final ai = split.where((r) => r.name == BuiltinRule.aiProxy.key).toList();
    expect(ai.length, 2);
    expect(ai[0].packageNames, isEmpty);
    expect(ai[1].domainSuffixes, isEmpty);
    expect(ai[0].listOrder, ai[1].listOrder);
  });
}
