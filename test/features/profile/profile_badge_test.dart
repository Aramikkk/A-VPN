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

  test('a mark: the first letter of the name, a circled one as text', () {
    final sigma = badgeOf(0, 'Доступ');
    expect((sigma.letter, sigma.glyph), ('S', 'Ⓢ'));
    final chill = badgeOf(1, 'ChillGuy VPN 🚀');
    expect((chill.letter, chill.glyph), ('C', 'Ⓒ'));
    // another alphabet: a circled number
    final other = badgeOf(2, 'Второй провайдер');
    expect((other.letter, other.glyph), ('В', '③'));
    expect(sigma.colour, isNot(chill.colour));
  });

  test('no marks with one subscription', () {
    profileBadgesNow = const [];
    expect(profileGlyph(0), '');
    expect(profileGlyph(3), '');
    profileBadgesNow = [badgeOf(0, 'Доступ'), badgeOf(1, 'ChillGuy')];
    expect(profileGlyph(1), 'Ⓒ');
    expect(profileGlyph(5), '');
    profileBadgesNow = const [];
  });
}
