/// Where the servers' pings go: a tiny page that answers at once, reached through each server. A few known ones that
/// work from anywhere, so one can be picked (or the next one taken) when the current one stops answering.
const pingTargets = <({String name, String url})>[
  (name: 'Google', url: 'http://www.gstatic.com/generate_204'),
  (name: 'Google · резерв', url: 'http://connectivitycheck.gstatic.com/generate_204'),
  (name: 'Cloudflare', url: 'http://cp.cloudflare.com/generate_204'),
  (name: 'Apple', url: 'http://captive.apple.com/hotspot-detect.html'),
  (name: 'Firefox', url: 'http://detectportal.firefox.com/success.txt'),
  (name: 'Microsoft', url: 'http://www.msftconnecttest.com/connecttest.txt'),
];

/// The targets that answer over HTTPS too (Microsoft's has no certificate for it).
bool pingTargetHasHttps(String url) => !url.contains('msftconnecttest.com');

/// The targets offered for the method: all for HTTP, those with HTTPS for HTTPS.
List<({String name, String url})> pingTargetsFor(bool https) => https
    ? [
        for (final p in pingTargets)
          if (pingTargetHasHttps(p.url)) p,
      ]
    : pingTargets;

/// The address a ping goes to: [url] (kept as http://) over HTTPS when [https] (the TLS handshake counted too, as
/// sites open), over HTTP otherwise. An address of the user's own keeps any other scheme.
String pingUrl(String url, bool https) {
  if (https && url.startsWith('http://')) return 'https://${url.substring(7)}';
  if (!https && url.startsWith('https://')) return 'http://${url.substring(8)}';
  return url;
}

/// The known target's name for [url], or null for an address of the user's own.
String? pingTargetName(String url) => pingTargets.where((p) => p.url == url).firstOrNull?.name;

/// The known target after [url] (the first one after an address of the user's own), round the list.
({String name, String url}) nextPingTarget(String url, {bool https = false}) {
  final targets = pingTargetsFor(https);
  final i = targets.indexWhere((p) => p.url == url);
  return targets[(i + 1) % targets.length];
}

/// What the site tiles call a good delay: green under [good] ms, amber under [slow], red from there; [scale] is the
/// delay at which a tile's water is lowest. Over HTTPS a delay is higher by nature (the TLS handshake takes round trips
/// of its own before the answer), so its marks are wider than for plain HTTP.
typedef SiteGrade = ({int good, int slow, int scale});

/// On mobile data ([mobile]) the marks are wider still: its delays are higher by nature (181-231 ms is good there).
SiteGrade siteGrade(bool https, {bool mobile = false}) => mobile
    ? (https ? (good: 500, slow: 900, scale: 1200) : (good: 300, slow: 600, scale: 900))
    : (https ? (good: 250, slow: 500, scale: 750) : (good: 150, slow: 300, scale: 450));
