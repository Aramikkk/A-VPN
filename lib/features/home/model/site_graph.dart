/// How the Dots sites block shows each site's delay (picked in the menu a tap on the block opens).
enum SiteGraph {
  /// the name and the figure
  list('Список', 'List'),

  /// the name, the dotted history of the last rounds and the figure
  history('История', 'History'),

  /// the name with the figure over a row of dots filled up to the delay
  scales('Шкалы', 'Scales'),

  /// all the sites as dots on one axis of the delay
  axis('Ось', 'Axis');

  const SiteGraph(this.ru, this.en);

  final String ru;
  final String en;

  static const fallback = scales;

  static SiteGraph fromName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => fallback);
}
