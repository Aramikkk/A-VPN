import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/site_latency.dart';

const _six = [
  'com.instagram.android',
  'com.whatsapp',
  'org.telegram.messenger',
  'com.openai.chatgpt',
  'com.google.android.youtube',
  'com.google.android.apps.docs',
];

List<String> keys(List<String> apps, List<String> saved, {bool android = true}) => homeSitesFor(
  android: android,
  apps: apps,
  saved: saved,
  testUrl: 'http://www.gstatic.com/generate_204',
).map((s) => s.key).toList();

void main() {
  test('until a switch is touched the six services\' apps are the tiles, in the list order', () {
    expect(keys(_six, ['*']), ['instagram', 'whatsapp', 'telegram', 'chatgpt', 'youtube', 'gdrive']);
    expect(keys([..._six.reversed], ['*']).first, 'gdrive');
  });

  test('another app is not a tile until it is marked', () {
    final apps = [..._six, 'ru.sberbankmobile'];
    expect(keys(apps, ['*']).length, 6);
    final saved = [...apps];
    final marked = keys(apps, saved);
    expect(marked.last, 'app:ru.sberbankmobile');
    expect(homeSitesFor(android: true, apps: apps, saved: saved, testUrl: 'http://x/').last.name, 'sberbankmobile');
  });

  test('the saved list decides, and an unmarked app is out', () {
    expect(keys(_six, ['com.whatsapp']), ['whatsapp']);
    expect(keys(_six, ['']), isEmpty);
  });

  test('two apps of one service are one tile; the AI chats are services too', () {
    expect(keys(['com.instagram.android', 'com.instagram.lite'], ['com.instagram.android', 'com.instagram.lite']), ['instagram']);
    expect(keys(['com.anthropic.claude', 'com.google.android.apps.bard'], ['com.anthropic.claude', 'com.google.android.apps.bard']), [
      'claude',
      'gemini',
    ]);
  });

  test('no more than nine tiles', () {
    final apps = [for (var i = 0; i < 15; i++) 'app.number$i'];
    expect(keys(apps, apps).length, maxHomeSites);
  });

  test('a computer has the six services', () {
    expect(keys(['whatever'], ['whatever'], android: false), ['instagram', 'whatsapp', 'telegram', 'chatgpt', 'youtube', 'gdrive']);
  });

  test('a drag as the list reports it', () {
    final list = ['a', 'b', 'c', 'd'];
    expect(movedKey(list, 0, 3), ['b', 'c', 'a', 'd']);
    expect(movedKey(list, 3, 0), ['d', 'a', 'b', 'c']);
    expect(movedKey(list, 1, 2), list);
    expect(movedKey(list, 0, 4), ['b', 'c', 'd', 'a']);
    expect(movedKey(list, 9, 0), list);
  });

  test('the order of the user: named first as named, the rest after', () {
    expect(orderedKeys(['a', 'b', 'c', 'd'], []), ['a', 'b', 'c', 'd']);
    expect(orderedKeys(['a', 'b', 'c', 'd'], ['c', 'a']), ['c', 'a', 'b', 'd']);
    expect(orderedKeys(['a', 'b'], ['x', 'b']), ['b', 'a']);
    expect(orderedKeys(['a', 'b', 'c'], ['b', 'b']), ['b', 'a', 'c']);
  });
}
