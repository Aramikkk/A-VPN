import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/subscription_decoy.dart';
import 'package:hiddify/features/profile/data/xray_json_to_links.dart';

Map<String, dynamic> _vless(String remarks, {String host = 'se1.example.com', Map<String, dynamic>? stream}) => {
  'remarks': remarks,
  'outbounds': [
    {
      'protocol': 'vless',
      'tag': 'proxy',
      'settings': {
        'vnext': [
          {
            'address': host,
            'port': 443,
            'users': [
              {'id': '11111111-2222-3333-4444-555555555555', 'encryption': 'none', 'flow': 'xtls-rprx-vision'},
            ],
          },
        ],
      },
      'streamSettings':
          stream ??
          {
            'network': 'tcp',
            'security': 'reality',
            'realitySettings': {
              'serverName': 'www.example.org',
              'fingerprint': 'chrome',
              'publicKey': 'PUBKEY',
              'shortId': 'ab12',
              'spiderX': '/',
            },
          },
    },
    {'protocol': 'freedom', 'tag': 'direct'},
  ],
};

void main() {
  test('a list of Xray configs becomes one share link each, with the name', () {
    final links = XrayJsonToLinks.convert(
      jsonEncode([_vless('🇸🇪 Швеция'), _vless('🇩🇪 Германия', host: 'de1.example.com')]),
    )!;
    final lines = links.split('\n');
    expect(lines, hasLength(2));
    final uri = Uri.parse(lines.first);
    expect(uri.scheme, 'vless');
    expect(uri.userInfo, '11111111-2222-3333-4444-555555555555');
    expect(uri.host, 'se1.example.com');
    expect(uri.port, 443);
    expect(Uri.decodeComponent(uri.fragment), '🇸🇪 Швеция');
    expect(uri.queryParameters, {
      'encryption': 'none',
      'flow': 'xtls-rprx-vision',
      'type': 'tcp',
      'security': 'reality',
      'sni': 'www.example.org',
      'fp': 'chrome',
      'pbk': 'PUBKEY',
      'sid': 'ab12',
      'spx': '/',
    });
  });

  test('websocket and grpc transports, tls', () {
    final ws = XrayJsonToLinks.convert(
      jsonEncode(
        _vless(
          'ws',
          stream: {
            'network': 'ws',
            'security': 'tls',
            'tlsSettings': {
              'serverName': 'cdn.example.com',
              'alpn': ['h2', 'http/1.1'],
            },
            'wsSettings': {
              'path': '/ws',
              'headers': {'Host': 'cdn.example.com'},
            },
          },
        ),
      ),
    )!;
    final q = Uri.parse(ws).queryParameters;
    expect(
      (q['type'], q['security'], q['path'], q['host'], q['sni'], q['alpn']),
      ('ws', 'tls', '/ws', 'cdn.example.com', 'cdn.example.com', 'h2,http/1.1'),
    );
    final grpc = XrayJsonToLinks.convert(
      jsonEncode(
        _vless(
          'g',
          stream: {
            'network': 'grpc',
            'security': 'none',
            'grpcSettings': {'serviceName': 'svc'},
          },
        ),
      ),
    )!;
    expect(Uri.parse(grpc).queryParameters['serviceName'], 'svc');
  });

  test('the newer flat form of the outbound settings', () {
    final config = {
      'remarks': 'flat',
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {'address': 'f.example.com', 'port': 8443, 'id': 'aaaa', 'encryption': 'none'},
          'streamSettings': {'network': 'tcp', 'security': 'none'},
        },
      ],
    };
    final uri = Uri.parse(XrayJsonToLinks.convert(jsonEncode([config]))!);
    expect((uri.host, uri.port, uri.userInfo), ('f.example.com', 8443, 'aaaa'));
  });

  test('trojan and shadowsocks', () {
    final trojan = {
      'remarks': 't',
      'outbounds': [
        {
          'protocol': 'trojan',
          'settings': {
            'servers': [
              {'address': 't.example.com', 'port': 443, 'password': 'pw'},
            ],
          },
          'streamSettings': {
            'network': 'tcp',
            'security': 'tls',
            'tlsSettings': {'serverName': 't.example.com'},
          },
        },
      ],
    };
    expect(XrayJsonToLinks.convert(jsonEncode([trojan])), startsWith('trojan://pw@t.example.com:443?'));
    final ss = {
      'remarks': 's',
      'outbounds': [
        {
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {'address': 's.example.com', 'port': 8388, 'method': 'aes-256-gcm', 'password': 'pw'},
            ],
          },
        },
      ],
    };
    final link = XrayJsonToLinks.convert(jsonEncode([ss]))!;
    expect(link, startsWith('ss://'));
    expect(link, contains('@s.example.com:8388#s'));
  });

  test('hysteria 2', () {
    final config = {
      'remarks': 'h',
      'outbounds': [
        {
          'protocol': 'hysteria',
          'settings': {'address': 'h.example.com', 'port': 8443, 'version': 2},
          'streamSettings': {
            'network': 'hysteria',
            'security': 'tls',
            'tlsSettings': {
              'serverName': 'h.example.com',
              'alpn': ['h3'],
            },
            'hysteriaSettings': {'version': 2, 'auth': 'secret'},
          },
        },
      ],
    };
    final uri = Uri.parse(XrayJsonToLinks.convert(jsonEncode([config]))!);
    expect((uri.scheme, uri.userInfo, uri.host, uri.port), ('hysteria2', 'secret', 'h.example.com', 8443));
    expect(uri.queryParameters, {'sni': 'h.example.com', 'alpn': 'h3'});
    expect(XrayJsonToLinks.lastReport.skipped, isEmpty);
    // version 1: left out, and told
    config['outbounds'] = [
      {
        'protocol': 'hysteria',
        'settings': {'address': 'h.example.com', 'port': 8443, 'version': 1},
      },
    ];
    expect(XrayJsonToLinks.convert(jsonEncode([config])), isNull);
    expect(XrayJsonToLinks.lastReport.skipped, {'hysteria': 1});
  });

  test('not an Xray subscription: nothing', () {
    expect(XrayJsonToLinks.convert('vless://a@b:443#x'), isNull);
    expect(XrayJsonToLinks.convert('{"outbounds":[{"type":"vless","tag":"a"}]}'), isNull);
    expect(XrayJsonToLinks.convert('[1,2,3]'), isNull);
    expect(XrayJsonToLinks.convert('not json'), isNull);
  });

  test('the decoy of a panel that wants a device id is told from the links', () {
    final decoy = XrayJsonToLinks.convert(
      jsonEncode([
        {
          'remarks': 'Приложение не передаёт идентификатор устройства (HWID)',
          'outbounds': [
            {
              'protocol': 'vless',
              'tag': 'missing-hwid-1',
              'settings': {
                'vnext': [
                  {
                    'address': '0.0.0.0',
                    'port': 1,
                    'users': [
                      {'id': 'x'},
                    ],
                  },
                ],
              },
            },
          ],
        },
      ]),
    )!;
    expect(SubscriptionDecoy.isDecoy(decoy), isTrue);
  });
}
