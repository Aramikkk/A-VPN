import 'package:hiddify/core/preferences/light_mode.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/stats/data/stats_data_providers.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/riverpod_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_notifier.g.dart';

/// [source] without the readings that come within [gap] of the one before.
Stream<T> _atMostEvery<T>(Stream<T> source, Duration gap) {
  DateTime? last;
  return source.where((_) {
    final now = DateTime.now();
    if (last != null && now.difference(last!) < gap) return false;
    last = now;
    return true;
  });
}

@riverpod
class StatsNotifier extends _$StatsNotifier with AppLogger {
  @override
  Stream<SystemInfo> build() {
    ref.disposeDelay(const Duration(seconds: 10));
    final serviceRunning = ref.watch(serviceRunningProvider);
    // the core gets a new gRPC channel when the app comes back from the background
    ref.watch(coreRestartSignalProvider);
    final superLight = ref.watch(superLightProvider);
    if (serviceRunning) {
      final stream = ref
          .watch(statsRepositoryProvider)
          .watchStats()
          .map((event) => event.getOrElse((_) => SystemInfo.create()));
      // the super light mode: a reading every ten seconds, so what shows the numbers redraws that seldom
      return superLight ? _atMostEvery(stream, const Duration(seconds: 10)) : stream;
    } else {
      return Stream.value(SystemInfo.create());
    }
  }
}
