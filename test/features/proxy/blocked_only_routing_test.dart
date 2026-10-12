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
    expect(rules[4]['outbound'], 'select'); // Google's and the AI apps
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

  test('Google and every AI service go through the VPN, Alice (Yandex) stays direct', () {
    final domains = (rules[2]['domain_suffix'] as List).cast<String>();
    bool proxied(String host) => domains.any((d) => host == d || host.endsWith('.$d'));
    for (final host in [
      'gemini.google.com',
      'play.googleapis.com',
      'android.clients.google.com',
      'notebooklm.google',
      'chatgpt.com',
      'claude.ai',
      'api.anthropic.com',
      'www.perplexity.ai',
      'grok.com',
      'chat.deepseek.com',
      'copilot.microsoft.com',
    ]) {
      expect(proxied(host), isTrue, reason: host);
    }
    for (final host in ['alice.yandex.ru', 'yandex.ru', 'uniproxy.alice.yandex.net', 'ya.ru']) {
      expect(proxied(host), isFalse, reason: host);
    }
    final apps = (rules[4]['package_name'] as List).cast<String>();
    expect(apps, containsAll(['com.android.vending', 'com.google.android.gms', 'com.openai.chatgpt']));
    expect(apps.where((a) => a.startsWith('ru.yandex') || a.startsWith('com.yandex')), isEmpty);
  });
}
