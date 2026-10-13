/// The app's look, picked in Settings → Themes; each one has a day and a night version, and the accent colour
/// (the colour theme) colours it.
enum AraStyle {
  /// Graphite: near-black (or light grey) with glass cards, a glowing ring button and big Unbounded figures.
  graphite,

  /// Editorial: paper (or dark paper), black and one accent colour, huge type, monospaced labels and thin rules.
  editorial,

  /// Glass: see-through panels over a soft coloured backdrop, the menu and the connect panel
  /// floating over it, in one of its own colour schemes (GlassScheme).
  glass,

  /// The look before 5.8: cards on white or black, the accent gradient on the speed block.
  classic;

  // a new install opens in Glass (its scheme: GlassScheme.fallback)
  static const fallback = glass;
}

/// The three kinds of glass (each scheme has a day and a night look; by night Liquid turns smoky like Frost).
enum GlassVariant {
  /// milky white panels over bright colour spots (the accent, blue and pink)
  liquid,

  /// smoky dark panels over black with the accent glowing through
  frost,

  /// nearly clear panels with bright edges over a calm grey-blue
  clear;

  bool get dark => this == frost;
}
