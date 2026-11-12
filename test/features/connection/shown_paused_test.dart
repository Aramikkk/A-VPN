import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/connection/notifier/shown_connection.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Conn extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(const Connected());
}

class _Pause extends VpnPauseNotifier {
  _Pause(this._raw);

  final String _raw;

  @override
  VpnPause build() => parseVpnPause(_raw);

  void set(String raw) => state = parseVpnPause(raw);
}

void main() {
  ProviderContainer make(String raw) {
    final container = ProviderContainer(
      overrides: [
        connectionNotifierProvider.overrideWith(_Conn.new),
        vpnPauseProvider.overrideWith(() => _Pause(raw)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(ProviderContainer c) async {
    c.listen(shownConnectionProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('connected and not paused: the screen shows it connected', () async {
    final c = make('');
    await settle(c);
    expect(c.read(shownConnectionProvider), isA<Connected>());
  });

  test('connected but paused by the service: the screen shows the VPN as off, as it is for the traffic', () async {
    final c = make('home');
    await settle(c);
    expect(c.read(shownConnectionProvider), isA<Disconnected>());
    expect(c.read(shownConnectionProvider).isConnected, isFalse);
  });

  test('the pause begins and ends: the screen follows at once, with no wait', () async {
    final c = make('');
    await settle(c);
    (c.read(vpnPauseProvider.notifier) as _Pause).set('app:Банк');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(shownConnectionProvider), isA<Disconnected>());
    (c.read(vpnPauseProvider.notifier) as _Pause).set('');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(shownConnectionProvider), isA<Connected>());
  });
}
