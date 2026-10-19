import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';

void main() {
  test('a tunnel that never answers starts counting losses after bounded grace', () {
    final start = DateTime(2026, 10, 16);
    expect(startupGraceExpired(start, start.add(const Duration(seconds: 14))), isFalse);
    expect(startupGraceExpired(start, start.add(const Duration(seconds: 15))), isTrue);
    expect(startupGraceExpired(start, start.add(const Duration(minutes: 2))), isTrue);
  });
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
