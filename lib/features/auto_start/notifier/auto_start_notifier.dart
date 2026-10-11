import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_start_notifier.g.dart';

@Riverpod(keepAlive: true)
class AutoStartNotifier extends _$AutoStartNotifier with InfraLogger {
  Timer? _timer;

  /// A-VPN on Windows starts from a scheduled task (see windows/packaging/avpn/autostart.ps1), which the
  /// installer puts next to the exe. A build without it (the portable folder) keeps the Run-key entry.
  static const _taskName = 'A-VPN';

  File get _taskScript => File(p.join(p.dirname(Platform.resolvedExecutable), 'autostart.ps1'));

  bool get _usesTask => Platform.isWindows && _taskScript.existsSync();

  @override
  Future<bool> build() async {
    if (!PlatformUtils.isDesktop) return false;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    launchAtStartup.setup(
      appName: appInfo.name,
      appPath: Platform.resolvedExecutable,
      packageName: "Hiddify.HiddifyNext",
    );
    final isEnabled = await _isEnabled();
    loggy.info("auto start is [${isEnabled ? "Enabled" : "Disabled"}]");
    _startTimer();
    ref.onDispose(() => _timer?.cancel());
    return isEnabled;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) => updateStatus());
  }

  Future<bool> _isEnabled() async {
    if (!_usesTask) return launchAtStartup.isEnabled();
    final result = await Process.run('schtasks', ['/Query', '/TN', _taskName]);
    return result.exitCode == 0;
  }

  /// Runs the task script with admin rights: Windows asks once with UAC, unless the app already has them
  /// (it does when the task started it).
  Future<void> _runTaskScript(String flag) async {
    final script = _taskScript.path.replaceAll("'", "''");
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      "Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden "
              "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','\"$script\"','$flag'"
          .toString(),
    ]);
    if (result.exitCode != 0) loggy.warning("autostart script $flag failed: ${result.stderr}");
  }

  Future<bool> updateStatus() async {
    loggy.debug("update auto start status");
    final isEnabled = await _isEnabled();
    state = AsyncValue.data(isEnabled);
    return isEnabled;
  }

  Future<void> enable() async {
    loggy.debug("enabling auto start");
    if (_usesTask) {
      await _runTaskScript('-Enable');
    } else {
      await launchAtStartup.enable();
    }
    await updateStatus();
  }

  Future<void> disable() async {
    loggy.debug("disabling auto start");
    if (_usesTask) {
      await _runTaskScript('-Disable');
    } else {
      await launchAtStartup.disable();
    }
    await updateStatus();
  }
}
