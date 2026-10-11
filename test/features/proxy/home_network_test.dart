import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/home_network.dart';

// A WireGuard profile as the core's parser stores an imported .conf (keys are made up).
const _wireguardProfile = {
  'endpoints': [
    {
      'type': 'wireguard',
      'tag': 'wiregaurd § 0',
      'address': '192.168.99.198/32',
      'private_key': 'YNZ1j9cQaXg0yRtj3yJ8gBf7JbXg5mJcVZ5D2P5m+3E=',
      'peers': [
        {
          'address': '203.0.113.1',
          'port': 8443,
          'public_key': 'yR/S2c+QvLGTFCec7QyO02tzJq6XduLOrcDZsJ66JCw=',
          'allowed_ips': ['192.168.99.198/32', '192.168.1.0/24', '192.168.88.1/32'],
          'persistent_keepalive_interval': 300,
        },
      ],
      'noise': {
        'fake_packet': {'enabled': true, 'count': '2-10'},
      },
    },
  ],
};

const _providerProfile = {
  'outbounds': [
    {'type': 'vless', 'tag': '🇫🇮 Доступ - Финляндия § 1', 'server': '1.2.3.4', 'server_port': 443},
  ],
};

void main() {
  late Directory dir;
  late String active;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('home');
    active = '${dir.path}/active-id.json';
    await File(active).writeAsString(jsonEncode(_providerProfile));
  });

  tearDown(() => dir.delete(recursive: true));

  test('adds a WireGuard-only profile as a hidden endpoint with a rule for its networks', () async {
    await File('${dir.path}/mechta-id.json').writeAsString(jsonEncode(_wireguardProfile));

    final out = await HomeNetwork.attach(active, activeConfigPath: active);

    expect(out, isNot(active));
    final config = jsonDecode(await File(out).readAsString()) as Map<String, dynamic>;
    final endpoint = (config['endpoints'] as List).single as Map<String, dynamic>;
    expect(endpoint['tag'], '🏠 wiregaurd §hide§');
    expect(endpoint.containsKey('noise'), isFalse);
    expect(endpoint['private_key'], isNotEmpty);
    final rules = ((config['route'] as Map)['rules'] as List).cast<Map<String, dynamic>>();
    expect(rules, hasLength(2));
    expect(rules[0]['outbound'], '🏠 wiregaurd §hide§');
    expect(rules[0]['action'], 'route');
    expect(rules[0]['ip_cidr'], ['192.168.99.198/32', '192.168.1.0/24', '192.168.88.1/32']);
    // everything else goes direct, not through the provider
    expect(rules[1]['outbound'], 'direct §hide§');
    expect(rules[1]['network'], ['tcp', 'udp']);
    // the provider's servers are untouched
    expect((config['outbounds'] as List).single['tag'], '🇫🇮 Доступ - Финляндия § 1');
  });

  test('the home WireGuard always connects directly', () async {
    await File('${dir.path}/mechta-id.json').writeAsString(jsonEncode(_wireguardProfile));

    final out = await HomeNetwork.attach(active, activeConfigPath: active);

    final config = jsonDecode(await File(out).readAsString()) as Map<String, dynamic>;
    expect(((config['endpoints'] as List).single as Map).containsKey('detour'), isFalse);
  });

  test('leaves the config alone without a WireGuard profile', () async {
    await File('${dir.path}/other-id.json').writeAsString(jsonEncode(_providerProfile));
    expect(await HomeNetwork.attach(active, activeConfigPath: active), active);
  });

  test('skips a WireGuard profile that takes all traffic', () async {
    final full = jsonDecode(jsonEncode(_wireguardProfile)) as Map<String, dynamic>;
    ((full['endpoints'] as List).single['peers'] as List).single['allowed_ips'] = ['0.0.0.0/0'];
    await File('${dir.path}/full-id.json').writeAsString(jsonEncode(full));
    expect(await HomeNetwork.attach(active, activeConfigPath: active), active);
  });

  test('ignores the copies the app writes next to a profile', () async {
    await File('$active.filtered.json').writeAsString(jsonEncode(_wireguardProfile));
    expect(await HomeNetwork.attach(active, activeConfigPath: active), active);
  });

  test('reports whether a WireGuard profile is there for the Server button', () async {
    expect(await HomeNetwork.available(active), isFalse);
    await File('${dir.path}/mechta-id.json').writeAsString(jsonEncode(_wireguardProfile));
    expect(await HomeNetwork.available(active), isTrue);
  });
}
