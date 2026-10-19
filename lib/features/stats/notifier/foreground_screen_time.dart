import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ForegroundScreenTime {
  const ForegroundScreenTime({required this.hasUsageAccess, this.apps = const {}});

  final bool hasUsageAccess;
  final Map<String, Duration> apps;
}

ForegroundScreenTime parseForegroundScreenTime(Object? value) {
  if (value is! Map) return const ForegroundScreenTime(hasUsageAccess: false);
  final appValues = value['apps'];
  return ForegroundScreenTime(
    hasUsageAccess: value['hasUsageAccess'] == true,
    apps: {
      if (appValues is Map)
        for (final entry in appValues.entries)
          if (entry.key is String && entry.value is num && (entry.value as num) > 0)
            entry.key as String: Duration(milliseconds: (entry.value as num).round()),
    },
  );
}

const _screenTimeChannel = MethodChannel('com.aravpn.app/autopause');
const foregroundScreenTimePollInterval = Duration(seconds: 10);

Stream<ForegroundScreenTime> pollForegroundScreenTime(
  Future<Object?> Function() readSnapshot, {
  Duration interval = foregroundScreenTimePollInterval,
}) async* {
  while (true) {
    try {
      yield parseForegroundScreenTime(await readSnapshot());
    } on PlatformException {
      yield const ForegroundScreenTime(hasUsageAccess: false);
    } on MissingPluginException {
      yield const ForegroundScreenTime(hasUsageAccess: false);
    }
    await Future<void>.delayed(interval);
  }
}

final foregroundScreenTimeProvider = StreamProvider.autoDispose<ForegroundScreenTime>(
  (ref) => pollForegroundScreenTime(() => _screenTimeChannel.invokeMethod<Object?>('screenTimeSnapshot')),
);

Future<void> openForegroundUsageAccessSettings() => _screenTimeChannel.invokeMethod<void>('openUsageAccessSettings');
