import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/clash_to_links.dart';

void main() {
  test('turns the provider-shaped Clash proxies into share links', () {
    const yaml = '''
mixed-port: 7890
proxies:
  - name: "🇩🇪 LTE Only -  Германия"
    type: vless
    server: wte2.example.link
    port: 2089
    uuid: 11111111-2222-3333-4444-555555555555
    network: grpc
    tls: true
    udp: true
    servername: www.example.com
    client-fingerprint: chrome
    packet-encoding: xudp
    grpc-opts:
      grpc-service-name: svc
    reality-opts:
      public-key: PBK
      short-id: "ab12"
  - name: "🇫🇮 Доступ - Финляндия"
    type: vless
    server: 1.2.3.4
    port: 443
    uuid: u
    network: tcp
    tls: true
    flow: xtls-rprx-vision
    servername: sni.example
    client-fingerprint: chrome
    reality-opts: {public-key: K, short-id: "01"}
  - name: "🇱🇻 Доступ - Латвия"
    type: hysteria2
    server: hy.example
    port: 8443
    password: "p@ss"
    sni: hy.example
    alpn: [h3]
proxy-groups:
  - {name: PROXY, type: select, proxies: [DIRECT]}
''';
    final lines = ClashToLinks.convert(yaml)!.split('\n');
    expect(lines, hasLength(3));
    final grpc = Uri.parse(lines[0]);
    expect(grpc.scheme, 'vless');
    expect(grpc.host, 'wte2.example.link');
    expect(grpc.port, 2089);
    expect(grpc.queryParameters, containsPair('type', 'grpc'));
    expect(grpc.queryParameters, containsPair('serviceName', 'svc'));
    expect(grpc.queryParameters, containsPair('security', 'reality'));
    expect(grpc.queryParameters, containsPair('pbk', 'PBK'));
    expect(grpc.queryParameters, containsPair('sid', 'ab12'));
    expect(grpc.queryParameters, containsPair('sni', 'www.example.com'));
    expect(Uri.decodeComponent(grpc.fragment), '🇩🇪 LTE Only -  Германия');
    expect(Uri.parse(lines[1]).queryParameters, containsPair('flow', 'xtls-rprx-vision'));
    final hy = Uri.parse(lines[2]);
    expect(hy.scheme, 'hy2');
    expect(Uri.decodeComponent(hy.userInfo), 'p@ss');
    expect(hy.queryParameters, containsPair('alpn', 'h3'));
  });

  test('leaves non-Clash content alone', () {
    expect(ClashToLinks.convert('vless://u@h:1#x'), isNull);
    expect(ClashToLinks.convert('{"outbounds": []}'), isNull);
  });
}
