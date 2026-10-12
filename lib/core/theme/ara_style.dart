/// The app's look, picked in Settings → Themes; each one has a day and a night version, and the accent colour
/// (the colour theme) colours it.
enum AraStyle {
  /// Graphite: near-black (or light grey) with glass cards, a glowing ring button and big Unbounded figures.
  graphite,

  /// Editorial: paper (or dark paper), black and one accent colour, huge type, monospaced labels and thin rules.
  editorial,

  /// Cyberpunk: pure black by night, pure white by day, with contrasting neons (orange, cyan, magenta); cut corners,
  /// monospaced labels and a neon glow. Its colours are its own, whatever the colour theme.
  cyberpunk,

  /// The look before 5.8: cards on white or black, the accent gradient on the speed block.
  classic;

  static const fallback = graphite;
}
