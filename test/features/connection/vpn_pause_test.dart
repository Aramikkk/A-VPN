import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';

void main() {
  group('parseVpnPause', () {
    test('nothing from the service: not paused', () {
      for (final raw in [null, '']) {
        final p = parseVpnPause(raw);
        expect(p.paused, isFalse);
        expect(p.home, isFalse);
        expect(p.app, isEmpty);
      }
    });

    test('paused for a home Wi-Fi', () {
      final p = parseVpnPause('home');
      expect(p.paused, isTrue);
      expect(p.home, isTrue);
      expect(p.app, isEmpty);
    });

    test('paused while an app is on screen: its name comes with it', () {
      final p = parseVpnPause('app:Госуслуги');
      expect(p.paused, isTrue);
      expect(p.home, isFalse);
      expect(p.app, 'Госуслуги');
    });

    test('an app whose name has a colon keeps the whole name', () {
      expect(parseVpnPause('app:Банк: личный кабинет').app, 'Банк: личный кабинет');
    });

    test('something unknown from a newer service still means paused', () {
      final p = parseVpnPause('other');
      expect(p.paused, isTrue);
      expect(p.home, isFalse);
    });
  });

  group('tunnelUp', () {
    test('connected and not paused: the tunnel is up', () {
      expect(tunnelUp(connected: true, pause: parseVpnPause('')), isTrue);
    });
    test('connected but paused: the tunnel is closed, nothing is to be asked of the core', () {
      expect(tunnelUp(connected: true, pause: parseVpnPause('home')), isFalse);
      expect(tunnelUp(connected: true, pause: parseVpnPause('app:X')), isFalse);
    });
    test('not connected: down whatever the pause says', () {
      expect(tunnelUp(connected: false, pause: parseVpnPause('')), isFalse);
    });
  });

  group('noServersText', () {
    test('not paused: the old words, connect to see the servers', () async {
      final t = await AppLocale.ru.build();
      expect(noServersText(t, noVpnPause), t.avpn.connectToSeeServers);
    });
    test('paused for a home Wi-Fi: it says so, and not that there is no connection', () async {
      final t = await AppLocale.ru.build();
      final text = noServersText(t, parseVpnPause('home'));
      expect(text, contains('пауз'));
      expect(text, contains('Wi-Fi'));
      expect(text, isNot(t.avpn.connectToSeeServers));
    });
    test('paused for an app: the app is named', () async {
      final t = await AppLocale.ru.build();
      expect(noServersText(t, parseVpnPause('app:Госуслуги')), contains('Госуслуги'));
    });
    test('paused, nothing known of why: still the pause', () async {
      final t = await AppLocale.en.build();
      expect(noServersText(t, parseVpnPause('other')), t.avpn.vpnPausedOther);
    });
  });
}
