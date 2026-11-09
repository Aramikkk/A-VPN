import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

OutboundInfo _server(String tag, int delay, {bool group = false, bool visible = true}) =>
    OutboundInfo(tag: tag, urlTestDelay: delay, isGroup: group, isVisible: visible);

void main() {
  test('the button takes the answering server with the lowest ping, whatever subscription it is from', () {
    final best = fastestServer([_server('dk', 77), _server('de', 56), _server('be', 63)]);
    expect(best?.tag, 'de');
  });

  test('groups, hidden servers and servers that do not answer are not chosen', () {
    final best = fastestServer([
      _server('lowest', 10, group: true),
      _server('smart', 20, group: true),
      _server('ru', 15, visible: false),
      _server('timeout', 65535),
      _server('none', 0),
      _server('nl', 68),
    ]);
    expect(best?.tag, 'nl');
  });

  test('nothing answers: no choice', () {
    expect(fastestServer([_server('a', 0), _server('b', 65535)]), isNull);
    expect(fastestServer(const []), isNull);
  });

  test('on Wi-Fi the whitelist servers are left out, on mobile data they are the only ones', () {
    final items = [
      _server('Доступ - Германия LTE Only', 40),
      _server('Доступ - Швеция', 56),
      _server('Доступ - Дания', 77),
    ];
    expect(fastestServer(items, network: NetworkKind.wifi)?.tag, 'Доступ - Швеция');
    expect(fastestServer(items, network: NetworkKind.mobile)?.tag, 'Доступ - Германия LTE Only');
    // the networks not told apart: the lowest of all
    expect(fastestServer(items)?.tag, 'Доступ - Германия LTE Only');
    // mobile data and no whitelist server answering: none (the others would pass a ping and drop the traffic)
    expect(fastestServer([_server('Швеция', 56)], network: NetworkKind.mobile), isNull);
  });

  test('a server hidden by the filters is not chosen even when it answers', () {
    expect(fastestServer([_server('Швеция §hide§', 10), _server('Дания', 77)])?.tag, 'Дания');
  });
}
