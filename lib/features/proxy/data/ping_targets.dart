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

/// The known target's name for [url], or null for an address of the user's own.
String? pingTargetName(String url) => pingTargets.where((p) => p.url == url).firstOrNull?.name;

/// The known target after [url] (the first one after an address of the user's own), round the list.
({String name, String url}) nextPingTarget(String url) {
  final i = pingTargets.indexWhere((p) => p.url == url);
  return pingTargets[(i + 1) % pingTargets.length];
}
