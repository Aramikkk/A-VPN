import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/logger/logger_setup.dart';
import 'package:hiddify/core/logger/ring/log_ring.dart';
import 'package:logging/logging.dart';
import 'package:hiddify/core/logger/redaction.dart';

void main() {
  test('redaction remains stable across ring, display, and export', () {
    final once = redactLogText('https://example.com/private?token=secret');
    expect(redactLogText(once), once);
  });
  test('a server\'s settings logged as JSON lose their credentials but keep the address', () {
    const json =
        '{"outbounds": [{"type":"vless","tag":"DE","server":"203.0.113.7","server_port":443,'
        '"uuid":"1976d936-4d46-4dc7-89e2-f762c3eab1ba","flow":"xtls-rprx-vision",'
        '"tls":{"reality":{"enabled":true,"public_key":"Lzx_Kqy2bjd8XcV_HBNYgApSX4PEpcaTMrtgExo7xSk","short_id":"6afe69fbea2f40fb"}},'
        '"password":"hunter2"}]}';
    final cleaned = redactLogText(json);
    for (final secret in [
      '1976d936-4d46-4dc7-89e2-f762c3eab1ba',
      'Lzx_Kqy2bjd8XcV_HBNYgApSX4PEpcaTMrtgExo7xSk',
      '6afe69fbea2f40fb',
      'hunter2',
    ]) {
      expect(cleaned, isNot(contains(secret)));
    }
    expect(cleaned, contains('203.0.113.7'));
    expect(cleaned, contains('"server_port":443'));
    expect(redactLogText(cleaned), cleaned);
  });

  test('a bare UUID in a line is hidden', () {
    expect(redactLogText('profile 9421fbb9-e722-4d5d-b7f1-fe22dd730df4 updated'), equals('profile [uuid] updated'));
  });

  test('ring and exported lines never retain URL credentials, paths or queries', () {
    const url = 'https://user:password@example.com/sub/private-token?key=query-token#fragment-token';
    final record = LogRecord(Level.WARNING, 'adding remote profile: $url', 'infra.test', StateError(url));
    final ring = LogRing(10)..add(record);
    final saved = ring.records.single;
    for (final token in ['password', 'private-token', 'query-token', 'fragment-token']) {
      expect(saved.message, isNot(contains(token)));
      expect(saved.error.toString(), isNot(contains(token)));
      expect(formatRecord(record), isNot(contains(token)));
    }
    expect(saved.message, contains('example.com'));
  });
}
