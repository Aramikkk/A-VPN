import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/site_latency.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

OutboundGroup _group(String tag, String selected) => OutboundGroup(tag: tag, selected: selected);

void main() {
  test('each service group gives its server to its site', () {
    final map = siteServersOf([_group('site-instagram', 'de'), _group('site-telegram', 'fi'), _group('select', 'x')]);
    expect(map, {'instagram': 'de', 'telegram': 'fi'});
  });

  test('the AI group gives its server to every AI service', () {
    final map = siteServersOf([_group('ai', 'fi'), _group('site-instagram', 'de')]);
    expect(map['claude'], 'fi');
    expect(map['chatgpt'], 'fi');
    expect(map['gemini'], 'fi');
    expect(map['perplexity'], 'fi');
    expect(map['deepseek'], 'fi');
    expect(map['instagram'], 'de');
  });

  test('a group with nothing selected gives nothing', () {
    expect(siteServersOf([_group('ai', ''), _group('site-youtube', '')]), isEmpty);
  });
}
