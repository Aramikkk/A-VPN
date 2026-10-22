import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _server(String tag, String host) => {
  'type': 'vless',
  'tag': tag,
  'server': host,
  'server_port': 443,
  'uuid': host,
};

Future<List<Object?>> _tags(String path) async {
  final config = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  return [for (final o in config['outbounds'] as List) (o as Map)['tag']];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a country outside the region filter passes it when the user chose it by hand', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('region_manual');
    final file = File('${dir.path}/p.json')
      ..writeAsStringSync(
        jsonEncode({
          'outbounds': [
            _server('🇸🇪 Швеция § 1', 'se.example'),
            _server('🇺🇸 США § 2', 'us.example'),
            _server('🇯🇵 Япония § 3', 'jp.example'),
          ],
        }),
      );
    // Europe only: the USA and Japan are hidden
    final europe = await ServerRegionFilter.apply(file.path, europeOnly: true, remember: false);
    expect(await _tags(europe), ['🇸🇪 Швеция § 1', '🇺🇸 США § 2 §hide§', '🇯🇵 Япония § 3 §hide§']);
    // the USA chosen by hand: it stays
    final chosen = await ServerRegionFilter.apply(file.path, europeOnly: true, remember: false, allowOutside: {'US'});
    expect(await _tags(chosen), ['🇸🇪 Швеция § 1', '🇺🇸 США § 2', '🇯🇵 Япония § 3 §hide§']);
  });
}
