import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';

void main() {
  test('the bolt is empty at the start of a charge and full at its end', () {
    expect(boltChargedRows(0, 9), 0);
    expect(boltChargedRows(1, 9), 9);
  });

  test('it charges from the bottom up, never back down', () {
    var last = -1;
    for (var i = 0; i <= 100; i++) {
      final rows = boltChargedRows(i / 100, 9);
      expect(rows, greaterThanOrEqualTo(last));
      expect(rows, inInclusiveRange(0, 9));
      last = rows;
    }
  });

  test('it stays full for the last part of the cycle (the flash)', () {
    expect(boltChargedRows(.9, 9), 9);
    expect(boltChargedRows(.5, 9), lessThan(9));
  });

  test('a value outside the cycle is kept inside it', () {
    expect(boltChargedRows(-1, 9), 0);
    expect(boltChargedRows(3, 9), 9);
  });
}
