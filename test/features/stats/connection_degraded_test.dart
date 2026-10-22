import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/connection_quality.dart';

void main() {
  final calm = List<int?>.filled(30, 70);
  test('a calm connection is not bad', () {
    expect(ConnectionQuality.isDegraded(calm), isFalse);
    expect(ConnectionQuality.isDegraded([...calm, 90, null, 80, 75, 70, 72]), isFalse);
  });
  test('losses in a row are bad', () {
    expect(ConnectionQuality.isDegraded([...calm, null, null, 70, null, 70, 70]), isTrue);
  });
  test('several times slower for a while is bad', () {
    expect(ConnectionQuality.isDegraded([...calm, 380, 400, 350, 420, 390, 410]), isTrue);
  });
  test('slow from the start is not a change', () {
    expect(ConnectionQuality.isDegraded(List<int?>.filled(30, 380)), isFalse);
  });
  test('too few probes say nothing', () {
    expect(ConnectionQuality.isDegraded([null, null, null]), isFalse);
  });
}
