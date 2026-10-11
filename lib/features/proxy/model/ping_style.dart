/// How the home screen's server list shows a server's ping.
enum PingStyle {
  /// "84 ms", coloured by speed.
  numbers,

  /// Signal bars, more of them the faster the server.
  bars,

  /// Bars and the number.
  barsAndNumbers,

  /// A dot: coloured when the server answered.
  dots,
}
