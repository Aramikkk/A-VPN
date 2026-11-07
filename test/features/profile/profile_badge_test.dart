import 'package:hiddify/core/http_client/provider_quirks.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/widget/profile_badge.dart';

void main() {
  // the badge tests are about the Sigma provider, whose special handling is an option
  setUpAll(() => ProviderQuirks.sigma = true);
  tearDownAll(() => ProviderQuirks.sigma = false);

  test('the subscription a server is from, by the shift of its number', () {
    expect(profileOfTag('🇸🇪 Доступ - Швеция 2 § 29'), 0);
    expect(profileOfTag('🇩🇪 Германия § 1001'), 1);
    expect(profileOfTag('🇫🇮 Финляндия § 2007'), 2);
    expect(profileOfTag('🇫🇮 Финляндия § 2007 §hide§'), 2);
    expect(profileOfTag('🇸🇪 Швеция'), 0);
    expect(profileOfTag('select'), 0);
  });

  test('the providers keep their colours whichever subscription is first: Sigma blue, Chill yellow, Phantom purple', () {
    const blue = Color(0xFF4F8CFF);
    const yellow = Color(0xFFF5C518);
    const purple = Color(0xFFB36BFF);
    for (final index in [0, 1, 2, 3]) {
      expect(badgeOf(index, 'Sigma').colour, blue);
      expect(badgeOf(index, 'Доступ').colour, blue, reason: 'renamed to Sigma');
      expect(badgeOf(index, 'ChillGuy VPN 🚀').colour, yellow);
      expect(badgeOf(index, 'PHANTOM VPN').colour, purple);
    }
    // any other: not one of the three
    expect({blue, yellow, purple}.contains(badgeOf(0, 'Другой').colour), false);
  });

  test('a mark: the first letter of the name, its own colour for each subscription', () {
    final sigma = badgeOf(0, 'Доступ');
    expect(sigma.letter, 'S');
    final chill = badgeOf(1, 'ChillGuy VPN 🚀');
    expect(chill.letter, 'C');
    // another alphabet: its own first letter
    expect(badgeOf(2, 'Второй провайдер').letter, 'В');
    expect(sigma.colour, isNot(chill.colour));
    expect(badgeOf(2, 'x').colour, isNot(chill.colour));
  });

  test('a name carries its subscription as an invisible mark, taken off again', () {
    profileBadgesNow = [badgeOf(0, 'Доступ'), badgeOf(1, 'ChillGuy')];
    final sigmaName = '🇸🇪 Швеция${profileMark(0)}';
    final chillName = '🇩🇪 LTE-Антиглушилка №8${profileMark(1)}';
    expect(splitMark(chillName), (profile: 1, text: '🇩🇪 LTE-Антиглушилка №8'));
    expect(splitMark(sigmaName), (profile: 0, text: '🇸🇪 Швеция'));
    expect(splitMark('🇸🇪 Швеция').profile, isNull);
    // the mark is invisible: nothing a reader sees is added
    expect(profileMark(1).runes.every((r) => r == 0x200B), isTrue);
    profileBadgesNow = const [];
  });

  test('no marks with one subscription', () {
    profileBadgesNow = const [];
    expect(profileMark(0), '');
    expect(profileMark(3), '');
    profileBadgesNow = [badgeOf(0, 'Доступ'), badgeOf(1, 'ChillGuy')];
    expect(profileMark(5), '');
    profileBadgesNow = const [];
  });
}
