import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/site_latency.dart';

void main() {
  test('the catalog: the first six are the screen\'s old ones, keys are unique', () {
    expect(latencySites.take(6).map((s) => s.key), ['instagram', 'whatsapp', 'telegram', 'chatgpt', 'youtube', 'gdrive']);
    expect(latencySites.map((s) => s.key).toSet().length, latencySites.length);
    expect(latencySites.length, greaterThanOrEqualTo(15));
  });

  test('an address typed by the user', () {
    expect(latencyAddress('example.com'), 'http://example.com/');
    expect(latencyAddress('https://Example.com/page'), 'http://Example.com/page');
    expect(latencyAddress(' ya.ru '), 'http://ya.ru/');
    expect(latencyAddress('localhost'), isNull);
    expect(latencyAddress('two words.com'), isNull);
    expect(latencyAddress(''), isNull);
  });

  test('a site of one\'s own, as saved', () {
    final site = customLatencySite('Мой сайт\u0001http://example.com/');
    expect(site?.name, 'Мой сайт');
    expect(site?.letter, 'М');
    expect(site?.key, 'c:Мой сайт');
    expect(site?.url, 'http://example.com/');
    expect(customLatencySite('no separator'), isNull);
    expect(customLatencySite('\u0001http://x.com/'), isNull);
  });

  test('the order of the user: named first as named, the rest after', () {
    final keys = (List<String> order) => orderedSites(latencySites, order).map((s) => s.key).toList();
    expect(keys([]), latencySites.map((s) => s.key).toList());
    expect(keys(['claude', 'instagram']).take(3), ['claude', 'instagram', 'whatsapp']);
    expect(keys(['unknown', 'netflix']).first, 'netflix');
    expect(keys(['claude']).length, latencySites.length);
  });

  test('a drag as the list reports it', () {
    final keys = ['a', 'b', 'c', 'd'];
    expect(movedKey(keys, 0, 3), ['b', 'c', 'a', 'd']);
    expect(movedKey(keys, 3, 0), ['d', 'a', 'b', 'c']);
    expect(movedKey(keys, 1, 2), keys);
    expect(movedKey(keys, 0, 4), ['b', 'c', 'd', 'a']);
    expect(movedKey(keys, 9, 0), keys);
  });
}
