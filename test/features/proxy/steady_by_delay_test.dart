import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

OutboundInfo _s(String tag, int ms, {bool group = false}) => OutboundInfo(tag: tag, urlTestDelay: ms, isGroup: group);

List<String> _tags(List<OutboundInfo> l) => l.map((i) => i.tag).toList();

void main() {
  test('a first order is fastest first, the groups ahead and the untested last', () {
    final last = <String>[];
    final order = steadyByDelay([_s('de', 209), _s('pl', 104), _s('x', 0), _s('auto', 0, group: true)], last);
    expect(_tags(order), ['auto', 'pl', 'de', 'x']);
    expect(last, ['auto', 'pl', 'de', 'x']);
  });

  test('servers a few milliseconds apart keep their places', () {
    final last = <String>[];
    steadyByDelay([_s('pl', 104), _s('se', 181), _s('de', 203), _s('ee', 206)], last);
    // Estonia now 3 ms faster than Germany: no swap
    final order = steadyByDelay([_s('pl', 113), _s('se', 177), _s('de', 203), _s('ee', 200)], last);
    expect(_tags(order), ['pl', 'se', 'de', 'ee']);
  });

  test('a clearly faster one moves up', () {
    final last = <String>[];
    steadyByDelay([_s('pl', 104), _s('se', 181), _s('de', 203), _s('ee', 206)], last);
    final order = steadyByDelay([_s('pl', 104), _s('se', 181), _s('de', 260), _s('ee', 150)], last);
    expect(_tags(order), ['pl', 'ee', 'se', 'de']);
  });
}
