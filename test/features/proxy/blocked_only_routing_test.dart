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
    // ads are rule-sets, named by the core's tags (it sets up their download)
    expect(rules[3], {
      'rule_set': [
        'geosite-category-ads-all',
        'geosite-malware',
        'geosite-phishing',
        'geosite-cryptominers',
        'geoip-malware',
        'geoip-phishing',
      ],
      'action': 'reject',
    });
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
      'www.baidu.com',
      'weixin.qq.com',
      'www.aliexpress.com',
      'gov.cn',
      'relay-1.net.anydesk.com',
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
    final groups = [
      aiDomains,
      videoDomains,
      googleDomains,
      socialDomains,
      chinaDomains,
      adultDomains,
      otherBlockedDomains,
    ];
    final all = groups.expand((g) => g).toList();
    expect(all.toSet().length, all.length);
    expect(aiDomains, contains('chatgpt.com'));
    expect(videoDomains, containsAll(['googlevideo.com', 'twitch.tv']));
    expect(googleDomains, contains('gstatic.com'));
    expect(socialDomains, containsAll(['instagram.com', 'telegram.org', 'discord.com', 'twitter.com']));
    expect(otherBlockedDomains, containsAll(['netflix.com', 'tvrain.ru']));
    expect(suffixes.where((d) => d.contains('yandex')), isEmpty);
  });

  test('a group of sites and apps is two rules; every Google app goes by pattern', () {
    final apps = rules.where((r) => r.containsKey('package_name')).toList();
    // what is blocked first (social, the rest blocked), then the Russian apps whole (Yandex, marketplaces, banks,
    // the rest), then AI, YouTube and Twitch, stores, Google, Chinese, foreign
    expect(apps.length, 12);
    expect(apps[0]['package_name'], containsAll(['org.telegram.messenger', 'com.whatsapp', 'com.instagram.android']));
    expect(apps[1]['package_name'], containsAll(['com.anydesk.anydeskandroid', 'notion.id', 'ru.fourpda.client']));
    for (final (i, app) in [(2, 'ru.yandex.music'), (3, 'ru.ozon.app.android'), (4, 'ru.sberbankmobile')]) {
      expect(apps[i]['outbound'], 'direct §hide§');
      expect(apps[i]['package_name'], contains(app));
    }
    expect(apps[5]['outbound'], 'direct §hide§');
    expect(apps[5]['package_name'], containsAll(['com.yandex.aliceapp', 'ru.sberbank_sbbol']));
    expect(apps[5]['package_name'], isNot(contains('ru.fourpda.client')));
    expect(apps[6]['package_name'], containsAll(['com.openai.chatgpt', 'com.anthropic.claude']));
    expect(apps[7]['package_name'], containsAll(['com.google.android.youtube', 'tv.twitch.android.app']));
    expect(apps[8]['package_name'], containsAll(['com.android.vending', 'org.fdroid.fdroid']));
    final pattern = RegExp((apps[9]['package_name_regex'] as List).single as String);
    expect(pattern.hasMatch('com.google.android.apps.nbu.files'), isTrue);
    expect(pattern.hasMatch('com.android.chrome'), isFalse);
    expect(apps[10]['package_name'], containsAll(['com.tencent.mm', 'com.alibaba.aliexpresshd']));
    expect(apps[11]['package_name'], containsAll(['com.microsoft.office.word', 'com.pinterest']));
    // AnyDesk on the computer, by its program
    expect(rules.where((r) => r['process_name'] != null).single['process_name'], contains('AnyDesk.exe'));
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
    expect(withUser[2], {
      'rule_set': ['x'],
      'action': 'route',
      'outbound': 'select',
    });
    expect(withUser.length, rules.length + 2); // three added, the ping host's rule not there
  });

  test('the core gets a group as two rules in the group place', () {
    final split = splitGroups(_defaults);
    final ai = split.where((r) => r.name == BuiltinRule.aiProxy.key).toList();
    expect(ai.length, 2);
    expect(ai[0].packageNames, isEmpty);
    expect(ai[1].domainSuffixes, isEmpty);
    expect(ai[0].listOrder, ai[1].listOrder);
  });

  test('adult sites go through the VPN and are known as such; Netflix is not one of them', () {
    expect(route('www.pornhub.com'), 'select');
    expect(route('onlyfans.com'), 'select');
    expect(adultDomains, contains('xvideos.com'));
    expect(adultDomains, isNot(contains('nflxvideo.net')));
    expect(otherBlockedDomains, contains('nflxvideo.net'));
    expect(isAdultHost('cdn.xhamster.com'), isTrue);
    expect(isAdultHost('some-porn-site.example'), isTrue);
    expect(isAdultHost('nflxvideo.net'), isFalse);
    expect(isAdultHost('ya.ru'), isFalse);
    final adult = rules.where((r) => (r['domain_keyword'] as List?)?.contains('porn') ?? false);
    expect(adult.single['outbound'], 'select');
  });
}
