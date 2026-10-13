import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';

void main() {
  test('keeps European servers, LTE Only ones included', () {
    for (final tag in [
      '🇪🇪 LTE Only - Эстония',
      '🇩🇪 LTE Only -  Германия',
      '🇸🇪 LTE Only - Швеция',
      '🇵🇱 LTE Only - Польша',
      '🇧🇪 Доступ - Бельгия',
      '🇬🇧 Доступ - Великобритания',
      '🇷🇴 Доступ - Румыния',
      '🇩🇰 Доступ - Дания',
      '🇱🇹 Доступ - Литва',
      '🇳🇱 Доступ - Нидерланды',
      '🇫🇮 Доступ - Финляндия (Тестовый)',
      '🇬🇷 Доступ - Греция',
      '🇲🇰 Доступ - Македония',
      '🇭🇺 Доступ - Венгрия',
      '🇸🇰 Доступ - Словакия',
      '🇮🇹 Доступ -  Италия',
      '🇧🇬 Доступ - Болгария',
      '🇦🇹  Доступ - Австрия',
      '🇱🇻 Доступ -  Латвия',
      '🇷🇸 Доступ - Сербия',
      '🇭🇷 Доступ - Хорватия',
      '🇸🇪 Доступ - Швеция 3',
      '🇨🇿 Доступ - Чехия',
      '🇳🇴 Доступ - Норвегия',
      '🇫🇷 Доступ - Франция',
      '🇩🇪 Доступ - Германия 2 (Тестовый)',
      'Доступ - Германия',
    ]) {
      expect(ServerRegionFilter.keep(tag), isTrue, reason: tag);
    }
  });

  test('hides servers outside Europe, LTE Only ones included', () {
    for (final tag in [
      '🇷🇺 LTE Only - Россия',
      '🇧🇾 LTE Only - Беларусь',
      '🇷🇺 Доступ - Россия',
      '🇧🇾 Доступ - Беларусь',
      '🇹🇷 Доступ - Турция',
      '🇮🇱 Доступ - Израиль',
      '🇬🇪 Доступ - Грузия',
      '🇺🇿 Доступ - Узбекистан',
      '🇺🇸 Доступ - США Atlanta',
      '🇰🇿 Доступ - Казахстан',
      '🇸🇬 Доступ - Сингапур',
      '🇰🇷 Доступ - Южная Корейка',
      '🇭🇰 Доступ - Гонконг',
      '🇦🇲 Доступ - Армения',
      'Доступ - Россия',
    ]) {
      expect(ServerRegionFilter.keep(tag), isFalse, reason: tag);
    }
  });

  test('World and CIS: every country but Russia and Belarus, the whitelist servers too', () {
    bool keep(String tag) => ServerRegionFilter.keepCis(tag);
    expect(keep('🇰🇿 Доступ - Казахстан § 48'), isTrue);
    expect(keep('🇺🇸 Доступ - США Atlanta § 44'), isTrue);
    expect(keep('🇩🇪 Доступ - Германия § 36'), isTrue);
    expect(keep('🇷🇺 Доступ - Россия § 7'), isFalse);
    expect(keep('🇧🇾 Доступ - Беларусь § 8'), isFalse);
    expect(keep('🇪🇪 LTE Only - Эстония § 2'), isTrue);
    expect(keep('🇷🇺 LTE Only - Россия § 0'), isFalse);
    expect(keep('🇧🇾 LTE Only - Беларусь § 1'), isFalse);
    expect(keep('🇷🇺 Белый список - Россия § 53'), isFalse);
  });

  test('keeps servers whose country is unknown', () {
    expect(ServerRegionFilter.keep('🇦🇶 Автовыбор игровой'), isFalse);
    expect(ServerRegionFilter.keep('Автовыбор игровой'), isTrue);
  });

  test('hides placeholder and non-European servers in a config, keeps detours pointing right', () async {
    final dir = await Directory.systemTemp.createTemp('srf');
    final file = File('${dir.path}/c.json');
    await file.writeAsString(
      jsonEncode({
        'outbounds': [
          {'type': 'vless', 'tag': 'App not supported', 'server': '0.0.0.0', 'server_port': 1},
          {'type': 'vless', 'tag': '🇩🇪 Доступ - Германия', 'server': '1.2.3.4', 'server_port': 443},
          {'type': 'vless', 'tag': '🇹🇷 Доступ - Турция', 'server': '1.2.3.5', 'server_port': 443},
          {
            'type': 'vless',
            'tag': '🇫🇮 via TR',
            'server': '1.2.3.6',
            'server_port': 443,
            'detour': '🇹🇷 Доступ - Турция',
          },
          {'type': 'direct', 'tag': 'direct'},
          {'type': 'shadowsocks', 'tag': '🇩🇪 БС -  Германия', 'server': 'siski.com', 'server_port': 1234},
        ],
      }),
    );
    final out = await ServerRegionFilter.apply(file.path);
    final tags = [for (final o in (jsonDecode(await File(out).readAsString())['outbounds'] as List)) o as Map];
    expect(tags[0]['tag'], contains('§hide§'));
    expect(tags[1]['tag'], '🇩🇪 Доступ - Германия');
    expect(tags[2]['tag'], contains('§hide§'));
    expect(tags[3]['detour'], tags[2]['tag']);
    expect(tags[4]['tag'], 'direct');
    expect(tags[5]['tag'], contains('§hide§'));
    await dir.delete(recursive: true);
  });

  Future<List<String>> visible(NetworkKind network) async {
    final dir = await Directory.systemTemp.createTemp('srf');
    final file = File('${dir.path}/c.json');
    await file.writeAsString(
      jsonEncode({
        'outbounds': [
          {'type': 'vless', 'tag': '🇸🇪 Доступ - Швеция', 'server': '1.1.1.1', 'server_port': 443},
          {'type': 'vless', 'tag': '🇩🇪 LTE Only -  Германия', 'server': '1.1.1.2', 'server_port': 443},
          {'type': 'shadowsocks', 'tag': '🇪🇪 БС - Эстония', 'server': '1.1.1.3', 'server_port': 443},
          {'type': 'vless', 'tag': '🇷🇺 LTE Only - Россия', 'server': '1.1.1.4', 'server_port': 443},
        ],
      }),
    );
    final out = await ServerRegionFilter.apply(file.path, network: network);
    final tags = [
      for (final o in (jsonDecode(await File(out).readAsString())['outbounds'] as List))
        if (!(o['tag'] as String).contains('§hide§')) o['tag'] as String,
    ];
    await dir.delete(recursive: true);
    return tags;
  }

  test('on mobile data only the European mobile-only servers stay', () async {
    expect(await visible(NetworkKind.mobile), ['🇩🇪 LTE Only -  Германия', '🇪🇪 БС - Эстония']);
  });

  test('on Wi-Fi the mobile-only servers go', () async {
    expect(await visible(NetworkKind.wifi), ['🇸🇪 Доступ - Швеция']);
  });

  test('with an unknown network every European server stays', () async {
    expect(await visible(NetworkKind.unknown), [
      '🇸🇪 Доступ - Швеция',
      '🇩🇪 LTE Only -  Германия',
      '🇪🇪 БС - Эстония',
    ]);
  });
}
