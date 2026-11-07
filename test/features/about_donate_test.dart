import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/about/widget/donate_tile.dart';

void main() {
  test('every card number on the About page is a valid card number (a typo would send thanks to a stranger)', () {
    for (final card in donationCards) {
      expect(isValidCardNumber(card.number), isTrue, reason: '${card.bank}: ${card.number}');
      expect(card.holder, isNotEmpty);
    }
  });

  test('formatCardNumber groups the digits by four', () {
    expect(formatCardNumber('2202205332798831'), equals('2202 2053 3279 8831'));
    expect(formatCardNumber('22002'), equals('2200 2'));
  });

  test('isValidCardNumber tells a mistyped number', () {
    expect(isValidCardNumber('2202205332798831'), isTrue);
    expect(isValidCardNumber('2202205332798832'), isFalse);
    expect(isValidCardNumber('12ab'), isFalse);
  });
}
