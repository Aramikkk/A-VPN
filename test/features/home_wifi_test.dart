import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home_wifi/home_wifi_page.dart';

void main() {
  test('homes are kept as the JSON the VPN service reads', () {
    final homes = <HomeRouter>[
      (name: 'Дом 1', gateway: '192.168.31.1', ports: [3058, 9090]),
      (name: 'Дом 2', gateway: '192.168.1.1', ports: [9090]),
    ];
    final json = encodeHomeRouters(homes);
    expect(json, contains('"gateway":"192.168.31.1"'));
    expect(json, contains('"ports":[3058,9090]'));
    expect(encodeHomeRouters(parseHomeRouters(json)), json);
    expect(parseHomeRouters(json).last.ports, [9090]);
  });

  test('a broken list reads as no homes', () {
    expect(parseHomeRouters('not json'), isEmpty);
    expect(parseHomeRouters('[]'), isEmpty);
  });
}
