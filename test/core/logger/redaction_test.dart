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
