/// How the Dots sites block shows each site's delay (picked in the menu of the button at the block's right).
enum SiteGraph {
  /// the name and the figure
  list('Список', 'List'),

  /// the name with the figure over a row of dots filled up to the delay
  scales('Шкалы', 'Scales'),

  /// the delay in big dots, three to a row
  digits('Цифры', 'Digits'),

  /// a column of dots for each site
  columns('Столбцы', 'Columns'),

  /// a runner on a track for each site: the faster, the nearer the finish
  lanes('Дорожки', 'Lanes');

  const SiteGraph(this.ru, this.en);

  final String ru;
  final String en;

  static const fallback = columns;

  static SiteGraph fromName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => fallback);
}
