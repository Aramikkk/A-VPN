/// How the home screen is laid out (Contrast): the blocks as they were, or one of the newer ones.
enum HomeLayout {
  /// the three tiles on top, the servers, the sites' tiles
  classic,

  /// the ping's live graph, the sites' tiles with a pulse of their own behind them
  pulse,

  /// solid tiles of different sizes, as a phone's widgets, one bright hero tile
  bento,

  /// dotted paper, figures of dots, a monospaced face, black with one red
  dots;

  /// in the order the picker shows them
  static const shown = [bento, dots, classic, pulse];

  // the vessel (1.0.4x–1.0.57) is gone: Bento in its place
  static HomeLayout fromName(String? name) =>
      name == 'vessel' ? bento : values.firstWhere((e) => e.name == name, orElse: () => classic);
}
