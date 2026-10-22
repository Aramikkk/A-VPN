import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/widget/profile_badge.dart';

void main() {
  test('the subscription a server is from, by the shift of its number', () {
    expect(profileOfTag('🇸🇪 Доступ - Швеция 2 § 29'), 0);
    expect(profileOfTag('🇩🇪 Германия § 1001'), 1);
    expect(profileOfTag('🇫🇮 Финляндия § 2007'), 2);
    expect(profileOfTag('🇫🇮 Финляндия § 2007 §hide§'), 2);
    expect(profileOfTag('🇸🇪 Швеция'), 0);
    expect(profileOfTag('select'), 0);
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
