/// How the figures of the Dots look are drawn (Settings → Themes → Dots): the dots of the matrix (as it always was), or solid
/// ones, thick, in the way of the sites' columns.
enum DotsDigits {
  dots('Матрица', 'Matrix'),
  mono('Моно', 'Mono'),
  wide('Гротеск', 'Grotesk'),
  blocks('Пиксель', 'Pixel');

  const DotsDigits(this.ru, this.en);

  final String ru;
  final String en;

  static const fallback = dots;

  static DotsDigits fromName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => fallback);
}
