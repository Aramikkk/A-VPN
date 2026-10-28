/// How the home screen is laid out (Contrast): the blocks as they were, or one of the newer ones.
enum HomeLayout {
  /// the three tiles on top, the servers, the sites' tiles
  classic,

  /// a big vessel of water for the connection's quality, the sites as a row of bars
  vessel,

  /// the ping's live graph, the sites as chips
  pulse,

  /// the connections as a small flow diagram: the apps and where they go
  route;

  static HomeLayout fromName(String? name) => values.firstWhere((e) => e.name == name, orElse: () => classic);
}
