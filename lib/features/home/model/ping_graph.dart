/// How the Dots ping block draws the history of the answers (picked in the menu of the big ping).
enum PingGraph {
  /// the bars on a scale (the first one)
  bars('Столбики', 'Bars'),

  /// each answer a stack of dots, like an equalizer
  equalizer('Эквалайзер', 'Equalizer'),

  /// one row of dots from 0 to 400 ms with a marker at the present ping
  ruler('Шкала', 'Ruler'),

  /// a dotted line through the answers
  trace('Трасса', 'Trace'),

  /// a grid of dots, one for an answer, the slow ones lit
  heat('Теплокарта', 'Heat map');

  const PingGraph(this.ru, this.en);

  final String ru;
  final String en;

  static const fallback = bars;

  static PingGraph fromName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => fallback);
}
