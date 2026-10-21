/// The app's theme, picked in Settings → Themes: the layout and the logic are one (Contrast's), the themes are
/// different colours and backdrops; each has a day and a night version.
enum AraStyle {
  /// Contrast: a light upper half (dark grey by night) with frosted blocks over a backdrop of lines or shapes in the
  /// palette chosen, and the connect controls on a black panel under it; big tight Golos figures.
  contrast,

  /// Glass: the same layout over soft colour spots on the scheme's base (GlassScheme), its blocks frosted glass.
  glass;

  // a new install opens in Contrast
  static const fallback = contrast;
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
