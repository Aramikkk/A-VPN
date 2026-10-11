import 'dart:io';

/// Where other devices reach the phone's proxy port when it shares its VPN (the hotspot, or the Wi-Fi it is on).
abstract class LanSharing {
  /// Interfaces Android uses for the hotspot (and USB / Bluetooth tethering).
  static final _tetherName = RegExp(r'^(ap\d|swlan\d|softap\d|wlan[1-9]|rndis\d|usb\d|bt-pan|ncm\d)');

  /// Interfaces that can't carry another device's traffic: loopback, the VPN tunnel, mobile data.
  static final _skipName = RegExp('^(lo|tun|ppp|rmnet|ccmni|dummy|ip6tnl|sit|clat|v4-)');

  /// The phone's private IPv4 addresses other devices can use, hotspot ones first.
  static Future<List<({String interface, String address, bool hotspot})>> addresses() async {
    final found = <({String interface, String address, bool hotspot})>[];
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        final name = iface.name.toLowerCase();
        if (_skipName.hasMatch(name)) continue;
        for (final address in iface.addresses) {
          if (!isPrivate(address.address)) continue;
          found.add((interface: iface.name, address: address.address, hotspot: _tetherName.hasMatch(name)));
        }
      }
    } catch (_) {
      // no interface list: the dialog then asks to turn the hotspot on
    }
    found.sort((a, b) => (b.hotspot ? 1 : 0) - (a.hotspot ? 1 : 0));
    return found;
  }

  static bool isPrivate(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }
}
