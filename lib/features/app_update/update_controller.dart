import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_update/ara_update.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum UpdatePhase { idle, checking, offer, downloading, ready, failed }

/// Where the program's own update is: nothing, looking, a newer build is offered, being downloaded, downloaded.
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.info,
    this.progress = 0,
    this.speed = 0,
    this.problem,
    this.upToDate = false,
  });

  final UpdatePhase phase;

  /// the newer build (offer, downloading, ready)
  final AraUpdateInfo? info;

  /// the share downloaded, 0 to 1
  final double progress;

  /// bytes a second, smoothed
  final double speed;

  /// what went wrong (failed): "check", "download", "install" or "permission"
  final String? problem;

  /// the last look found nothing newer
  final bool upToDate;

  UpdateState copyWith({UpdatePhase? phase, double? progress, double? speed, String? problem}) => UpdateState(
    phase: phase ?? this.phase,
    info: info,
    progress: progress ?? this.progress,
    speed: speed ?? this.speed,
    problem: problem,
    upToDate: upToDate,
  );
}

final araUpdateProvider = NotifierProvider<AraUpdateController, UpdateState>(AraUpdateController.new);

class AraUpdateController extends Notifier<UpdateState> {
  File? _apk;

  @override
  UpdateState build() => const UpdateState();

  int get _build => int.tryParse(ref.read(appInfoProvider).valueOrNull?.buildNumber ?? '') ?? 0;

  /// Looks in the update folder. A newer build becomes the offer and is returned; null when there is none (or no way to look:
  /// the state says which).
  Future<AraUpdateInfo?> check() async {
    // a download that runs is not interrupted by a look
    if (state.phase == UpdatePhase.downloading || state.phase == UpdatePhase.ready) return state.info;
    final folder = ref.read(Preferences.updateFolder).trim();
    if (folder.isEmpty) {
      state = const UpdateState(phase: UpdatePhase.failed, problem: 'folder');
      return null;
    }
    state = const UpdateState(phase: UpdatePhase.checking);
    try {
      final info = await AraUpdate.latest(folder);
      if (info == null || !info.isNewerThan(_build)) {
        state = const UpdateState(upToDate: true);
        return null;
      }
      state = UpdateState(phase: UpdatePhase.offer, info: info);
      return info;
    } catch (_) {
      state = const UpdateState(phase: UpdatePhase.failed, problem: 'check');
      return null;
    }
  }

  /// Offers a build that is already known to be newer (the daily look found it).
  void offer(AraUpdateInfo info) {
    if (state.phase == UpdatePhase.downloading || state.phase == UpdatePhase.ready) return;
    state = UpdateState(phase: UpdatePhase.offer, info: info);
  }

  /// Downloads the offered build; the progress is in the state, and the download goes on with the card closed.
  Future<void> download() async {
    final info = state.info;
    if (info == null || state.phase == UpdatePhase.downloading) return;
    final folder = ref.read(Preferences.updateFolder).trim();
    state = UpdateState(phase: UpdatePhase.downloading, info: info);
    final clock = Stopwatch()..start();
    var lastAt = 0;
    var lastDone = 0.0;
    var speed = 0.0;
    try {
      _apk = await AraUpdate.download(
        folder,
        info,
        onProgress: (share) {
          final at = clock.elapsedMilliseconds;
          if (at - lastAt >= 500) {
            final moved = (share - lastDone) * info.size;
            final now = moved * 1000 / (at - lastAt);
            speed = speed == 0 ? now : speed * .6 + now * .4;
            lastAt = at;
            lastDone = share;
          }
          state = state.copyWith(progress: share, speed: speed);
        },
      );
      state = UpdateState(phase: UpdatePhase.ready, info: info, progress: 1);
    } catch (_) {
      state = UpdateState(phase: UpdatePhase.failed, info: info, problem: 'download');
    }
  }

  /// Hands the downloaded build to the system's installer (the one tap is on "Install").
  Future<void> install() async {
    final apk = _apk;
    final info = state.info;
    if (apk == null || info == null) return;
    final result = await AraUpdate.install(apk);
    if (result == 'ok') return;
    state = UpdateState(
      phase: UpdatePhase.ready,
      info: info,
      progress: 1,
      problem: result == 'permission' ? 'permission' : 'install',
    );
  }

  /// Puts the card back to nothing (the offer was turned down).
  void dismiss() {
    if (state.phase == UpdatePhase.downloading || state.phase == UpdatePhase.ready) return;
    state = const UpdateState();
  }
}
