import 'package:flutter/painting.dart';

/// The one colour of the Dots style besides its black and its white (the OLED look: black, white and one contrast
/// colour): the lit dot of the connect control, the slow answers, the live mark. Twelve to choose from.
enum DotsAccent {
  red('Красный', 'Red', Color(0xFFE8231C)),
  orange('Оранжевый', 'Orange', Color(0xFFFF7A1A)),
  amber('Янтарный', 'Amber', Color(0xFFFFB000)),
  yellow('Жёлтый', 'Yellow', Color(0xFFF2E600)),
  lime('Лайм', 'Lime', Color(0xFFA6E22E)),
  green('Зелёный', 'Green', Color(0xFF1FD36B)),
  teal('Бирюзовый', 'Teal', Color(0xFF14C8D4)),
  blue('Синий', 'Blue', Color(0xFF2F7BFF)),
  indigo('Индиго', 'Indigo', Color(0xFF6B5BFF)),
  violet('Фиолетовый', 'Violet', Color(0xFFB04DFF)),
  pink('Розовый', 'Pink', Color(0xFFFF4FA3)),
  mono('Без цвета', 'None', Color(0xFFF2F2EE));

  const DotsAccent(this.ru, this.en, this.colour);

  final String ru;
  final String en;
  final Color colour;

  static const fallback = red;

  /// the colour as it reads on the paper (day) or on the black (night): by day a light one (yellow, lime) is darkened
  /// to read on the paper; "none" is the ink itself, black by day and white by night
  Color on({required bool dark}) {
    if (this == mono) return dark ? const Color(0xFFF2F2EE) : const Color(0xFF111111);
    if (dark) return colour;
    final hsl = HSLColor.fromColor(colour);
    return hsl.lightness > .46 ? hsl.withLightness(.4).toColor() : colour;
  }

  static DotsAccent fromName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => fallback);
}
