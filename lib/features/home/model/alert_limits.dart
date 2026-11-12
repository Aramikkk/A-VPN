/// Where the home screen turns a figure to the accent colour ("bad"): a ping this slow, a loss this heavy, a site's delay
/// this long. Mobile data is milder: its pings and losses are higher by nature (a ping of 200-230 ms and a loss of
/// 30-40 % are what it is there), and painting them as an alarm every time said nothing.
typedef AlertLimits = ({int ping, double loss, int siteSlow});

AlertLimits alertLimits({required bool mobile}) =>
    mobile ? (ping: 450, loss: 50.0, siteSlow: 450) : (ping: 300, loss: 15.0, siteSlow: 240);
