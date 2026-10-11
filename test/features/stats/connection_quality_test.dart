import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';

void main() {
  test('no samples: no ping, no loss', () {
    final s = summarize(const []);
    expect(s.ping, isNull);
    expect(s.loss, isNull);
  });

  test('latest answered ping and the share of lost probes', () {
    final s = summarize(const [40, null, 55, 61, null]);
    expect(s.ping, 61);
    expect(s.loss, 40);
  });

  test('all answered: no loss', () {
    expect(summarize(const [30, 32]).loss, 0);
  });
}
