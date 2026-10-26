import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/notifier/session_start.dart';
import 'package:hiddify/features/stats/notifier/session_totals.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

SystemInfo reading(int up, int down, {int vpn = 0, int start = 1000}) =>
    SystemInfo(uplinkTotal: Int64(up), downlinkTotal: Int64(down))
      ..unknownFields.mergeVarintField(100, Int64(vpn))
      ..unknownFields.mergeVarintField(101, Int64(vpn))
      ..unknownFields.mergeVarintField(102, Int64(start));

class _NoStats extends StatsNotifier {
  @override
  Stream<SystemInfo> build() => const Stream.empty();
}

late Directory _temporary;

class _Directories extends AppDirectories {
  @override
  Future<Directories> build() async => (baseDir: _temporary, workingDir: _temporary, tempDir: _temporary);
}

void main() {
  test('disk checkpoints are throttled and disposal saves the latest counters', () async {
    _temporary = await Directory.systemTemp.createTemp('aravpn-totals-');
    final container = ProviderContainer(
      overrides: [
        appDirectoriesProvider.overrideWith(_Directories.new),
        statsNotifierProvider.overrideWith(_NoStats.new),
      ],
    );
    var disposed = false;
    addTearDown(() async {
      if (!disposed) container.dispose();
      // the last checkpoint may still be writing (Windows holds the file a moment): try again, then let it be
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          await _temporary.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    });
    await container.read(appDirectoriesProvider.future);
    container.read(sessionTotalsProvider);
    final notifier = container.read(sessionTotalsProvider.notifier);
    final file = File('${_temporary.path}/session_totals.json');
    Future<void> saved(int down) async {
      for (var i = 0; i < 100; i++) {
        try {
          final json = jsonDecode(await file.readAsString()) as Map;
          if ((json['last'] as List)[1] == down) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return;
          }
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('checkpoint did not persist $down');
    }

    notifier.add(reading(10, 100));
    await saved(100);
    for (var n = 101; n <= 200; n++) {
      notifier.add(reading(20, n));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final checkpoint = jsonDecode(await file.readAsString()) as Map;
    expect((checkpoint['last'] as List)[1], 100);
    container.dispose();
    disposed = true;
    await saved(200);
  });
  test('carried counters survive UI process recreation for the same native session', () {
    final before = SessionTotalsNotifier();
    before.add(reading(100, 200));
    before.add(reading(10, 20));
    final after = SessionTotalsNotifier()..restore(before.snapshot());
    expect(after.add(SystemInfo()).down, 220);
    expect(after.add(reading(15, 30)).down, 230);
    manualStopCount++; // switched off by hand, then on: a new session
    expect(after.add(reading(1, 2, start: 2000)).down, 2);
  });
  test('a reload within the session keeps what was counted before it', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(10, 100, vpn: 50));
    totals.add(reading(20, 300, vpn: 80));
    final after = totals.add(reading(5, 40, vpn: 10)); // the core restarted its counters
    expect(after.up, 25);
    expect(after.down, 340);
    expect(after.vpnDown, 90);
  });

  test('a new session after the VPN was switched off by hand starts from zero', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(20, 300));
    manualStopCount++;
    final next = totals.add(reading(5, 40, start: 2000));
    expect(next.down, 40);
  });

  test('the core starting again without a manual stop (auto-pause, Wi-Fi to LTE) is the same session', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(20, 300, vpn: 80));
    final next = totals.add(reading(5, 40, vpn: 10, start: 2000));
    expect(next.down, 340);
    expect(next.up, 25);
    expect(next.vpnDown, 90);
  });

  test('an empty reading during a network handoff keeps the session totals', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(20, 300, vpn: 80));
    final gap = totals.add(SystemInfo());
    expect(gap.down, 300);
    expect(gap.vpnDown, 80);
    final next = totals.add(reading(5, 40, vpn: 10));
    expect(next.down, 340);
    expect(next.vpnDown, 90);
  });

  test('replacing VPN outbounds keeps their traffic when overall counters continue', () {
    final totals = SessionTotalsNotifier();
    totals.add(reading(20, 300, vpn: 80));
    final next = totals.add(reading(25, 340, vpn: 10));
    expect(next.down, 340);
    expect(next.vpnDown, 90);
  });
}
