import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/subscription_decoy.dart';

String _link(String host, String name, {int port = 443}) =>
    'vless://id@$host:$port?security=reality#${Uri.encodeComponent(name)}';

void main() {
  test('only decoys: the client is not known to the provider', () {
    final content = [
      _link('0.0.0.0', '❌ Приложение clash.meta не поддерживается', port: 1),
      _link('0.0.0.0', 'Скачайте Happ', port: 1),
    ].join('\n');
    expect(SubscriptionDecoy.isDecoy(content), isTrue);
    expect(SubscriptionDecoy.isDecoy(base64.encode(utf8.encode(content))), isTrue);
  });

  test('a decoy beside real servers is an ordinary subscription (the provider adds a banner of its own)', () {
    final content = [
      _link('0.0.0.0', 'App not supported', port: 1),
      _link('se1.example.com', '🇸🇪 Швеция'),
      _link('de1.example.com', '🇩🇪 Германия'),
    ].join('\n');
    expect(SubscriptionDecoy.isDecoy(content), isFalse);
  });

  test('a decoy by its name alone, at a real-looking address', () {
    expect(SubscriptionDecoy.isDecoy(_link('h.example.com', 'Download Happ')), isTrue);
    expect(SubscriptionDecoy.isDecoy(_link('h.example.com', 'Please use Happ')), isTrue);
  });

  test('nothing to read in it: not a decoy', () {
    expect(SubscriptionDecoy.isDecoy(''), isFalse);
    expect(SubscriptionDecoy.isDecoy('proxies:\n  - name: a'), isFalse);
    expect(SubscriptionDecoy.isDecoy('!!!not base64!!!'), isFalse);
  });

  test('looksLikeProfile: links, JSON, Clash, WireGuard and base64 are; a number or an empty answer is not', () {
    expect(SubscriptionDecoy.looksLikeProfile(_link('h.example.com', 'a')), isTrue);
    expect(SubscriptionDecoy.looksLikeProfile('{"outbounds": []}'), isTrue);
    expect(SubscriptionDecoy.looksLikeProfile('[{"dns": {}}]'), isTrue);
    expect(SubscriptionDecoy.looksLikeProfile('mixed-port: 7890\nproxies:\n  - name: a'), isTrue);
    expect(SubscriptionDecoy.looksLikeProfile('[Interface]\nPrivateKey = x'), isTrue);
    expect(SubscriptionDecoy.looksLikeProfile(base64.encode(utf8.encode(_link('h.example.com', 'a')))), isTrue);
    expect(SubscriptionDecoy.looksLikeProfile(''), isFalse);
    expect(SubscriptionDecoy.looksLikeProfile('0'), isFalse);
    expect(SubscriptionDecoy.looksLikeProfile('404 not found'), isFalse);
    expect(SubscriptionDecoy.looksLikeProfile('Access denied'), isFalse);
  });

  test('describe: the shape only, no keys or addresses', () {
    final text = SubscriptionDecoy.describe(
      '${_link('secret.example.com', 'name')}\n${_link('other.example.com', 'b')}',
    );
    expect(text, contains('share links (vless://)'));
    expect(text, contains('2 links'));
    expect(text, isNot(contains('secret')));
    expect(SubscriptionDecoy.describe('0'), contains('short text "0"'));
    expect(SubscriptionDecoy.describe('mixed-port: 7890\nproxies:'), contains('Clash YAML'));
  });
}
