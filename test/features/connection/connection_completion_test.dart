import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConnectionState extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(const Disconnected());
}

class _Profile extends ActiveProfile {
  _Profile(this.profile);
  final ProfileEntity profile;
  @override
  Stream<ProfileEntity?> build() => Stream.value(profile);
}

class _PendingConnection implements ConnectionRepository {
  final started = Completer<void>();
  final finish = Completer<void>();

  @override
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity profile, bool disableMemoryLimit) => TaskEither(() async {
    started.complete();
    await finish.future;
    return right(unit);
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RetryingConnection extends _PendingConnection {
  int attempts = 0;
  @override
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity profile, bool disableMemoryLimit) {
    if (++attempts == 1) return TaskEither.left(const InvalidConfig('retry test'));
    return super.connect(profile, disableMemoryLimit);
  }
}

void main() {
  test('mayConnect finishes only after the repository has finished connecting', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _PendingConnection();
    final profile = ProfileEntity.local(id: 'test', active: true, name: 'test', lastUpdate: DateTime(2026));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(preferences)),
        activeProfileProvider.overrideWith(() => _Profile(profile)),
        connectionRepositoryProvider.overrideWithValue(repository),
        connectionNotifierProvider.overrideWith(_ConnectionState.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    await container.read(connectionNotifierProvider.future);
    final notifier = container.read(connectionNotifierProvider.notifier);
    var completed = false;
    final pending = notifier.mayConnect().then((_) => completed = true);
    await repository.started.future;
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    repository.finish.complete();
    await pending;
    expect(completed, isTrue);
  });

  test('startup restore waits for its asynchronous retry to finish', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _RetryingConnection();
    final profile = ProfileEntity.local(id: 'test', active: true, name: 'test', lastUpdate: DateTime(2026));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(preferences)),
        activeProfileProvider.overrideWith(() => _Profile(profile)),
        connectionRepositoryProvider.overrideWithValue(repository),
        connectionNotifierProvider.overrideWith(_ConnectionState.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    await container.read(connectionNotifierProvider.future);
    await container.read(Preferences.startedByUser.notifier).update(true);
    final notifier = container.read(connectionNotifierProvider.notifier);
    var completed = false;
    final pending = notifier.restoreConnectionOnStartup().then((_) => completed = true);
    await repository.started.future;
    await Future<void>.delayed(Duration.zero);
    try {
      expect(completed, isFalse);
    } finally {
      repository.finish.complete();
      await pending;
    }
  });
}
