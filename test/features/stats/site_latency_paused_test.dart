import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';
import 'package:hiddify/features/stats/notifier/site_latency.dart';

class _Probe extends SiteLatency {
  void put(Map<String, int?> ms) => state = (ms: ms, at: DateTime.now(), testing: false, done: ms.length);
}

final _up = StateProvider<bool>((ref) => true);

void main() {
  ProviderContainer make() {
    final container = ProviderContainer(
      overrides: [
        superLightProvider.overrideWithValue(true),
        tunnelUpProvider.overrideWith((ref) => ref.watch(_up)),
        siteLatencyProvider.overrideWith(_Probe.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('while the tunnel is up the sites keep their delays', () {
    final c = make();
    (c.read(siteLatencyProvider.notifier) as _Probe).put({'instagram': 46, 'telegram': 67});
    expect(c.read(siteLatencyProvider).ms, {'instagram': 46, 'telegram': 67});
  });

  test('the tunnel closes (a pause, or the VPN off): the sites show no delays, not the old ones', () {
    final c = make();
    (c.read(siteLatencyProvider.notifier) as _Probe).put({'instagram': 46});
    c.read(_up.notifier).state = false;
    expect(c.read(siteLatencyProvider).ms, isEmpty);
    expect(c.read(siteLatencyProvider).at, isNull);
  });
}
