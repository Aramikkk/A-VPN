import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/blocked_only_routing.dart';

void main() {
  final rules = BlockedOnlyRouting.rules(extraProxyHosts: ['www.gstatic.com']);

  test('local network first, then blocked through the VPN, then everything else direct', () {
    expect(rules.first['ip_is_private'], isTrue);
    expect(rules.first['outbound'], 'direct §hide§');
    expect(rules[1]['action'], 'reject');
    expect(rules[2]['outbound'], 'select');
    expect(rules[3]['outbound'], 'select');
    expect(rules.last['outbound'], 'direct §hide§');
    expect(rules.last['network'], ['tcp', 'udp']);
  });

  test('blocked services, blocked .ru sites and the ping test host go through the VPN', () {
    final domains = rules[2]['domain_suffix'] as List;
    for (final d in [
      'youtube.com',
      'googlevideo.com',
      'instagram.com',
      'telegram.org',
      'chatgpt.com',
      'www.gstatic.com',
    ]) {
      expect(domains, contains(d), reason: d);
    }
    expect(rules[3]['ip_cidr'] as List, contains('91.108.4.0/22')); // Telegram
  });

  test('Yandex stays direct', () {
    final domains = (rules[2]['domain_suffix'] as List).cast<String>();
    expect(domains.where((d) => d == 'yandex.net' || d == 'yandex.ru' || d == 'disk.yandex.ru'), isEmpty);
  });
}
