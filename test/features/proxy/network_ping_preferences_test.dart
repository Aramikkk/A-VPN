import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('network timeouts migrate legacy value, remain independent and enforce 1..30', () async {
    SharedPreferences.setMockInitialValues({'url-test-timeout': 12});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs))],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    expect(container.read(ConfigOptions.urlTestTimeoutWifi), const Duration(seconds: 12));
    expect(container.read(ConfigOptions.urlTestTimeoutMobile), const Duration(seconds: 12));
    expect(container.read(ConfigOptions.balancerToleranceMobile), 50);
    expect(container.read(ConfigOptions.balancerToleranceWifi), 150);
    await container.read(ConfigOptions.urlTestTimeoutWifi.notifier).update(const Duration(seconds: 1));
    await container.read(ConfigOptions.urlTestTimeoutMobile.notifier).update(const Duration(seconds: 30));
    await container.read(ConfigOptions.urlTestTimeoutWifi.notifier).update(Duration.zero);
    await container.read(ConfigOptions.urlTestTimeoutMobile.notifier).update(const Duration(seconds: 31));
    expect(container.read(ConfigOptions.urlTestTimeoutWifi), const Duration(seconds: 1));
    expect(container.read(ConfigOptions.urlTestTimeoutMobile), const Duration(seconds: 30));
    expect(prefs.getInt('url-test-timeout-wifi'), 1);
    expect(prefs.getInt('url-test-timeout-mobile'), 30);
  });
}
