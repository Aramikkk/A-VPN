import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/directories/stale_files.dart';

void main() {
  test('stale files go, a live profile and its variants stay', () async {
    final root = await Directory.systemTemp.createTemp('stale');
    addTearDown(() async {
      try {
        await root.delete(recursive: true);
      } catch (_) {}
    });
    final now = DateTime(2026, 10, 21, 12);
    Future<File> make(String path, {Duration age = Duration.zero}) async {
      final file = File('${root.path}/$path');
      await file.create(recursive: true);
      await file.writeAsString('x' * 100);
      await file.setLastModified(now.subtract(age));
      return file;
    }

    final live = await make('configs/live.json');
    final liveVariant = await make('configs/live.json.blocked-only-wifi.json', age: const Duration(days: 30));
    final liveTmp = await make('configs/live.tmp.json');
    final oldTmp = await make('configs/live.tmp.json.old', age: const Duration(days: 30));
    final orphan = await make('configs/gone.json.europe.json', age: const Duration(days: 30));
    final orphanTmp = await make('configs/gone2.tmp.json', age: const Duration(days: 3));
    final log = await make('logs/a-vpn-2026-10-01.log', age: const Duration(days: 20));
    final freshLog = await make('logs/a-vpn-2026-10-21.log');
    final exported = await make('a-vpn-logs-3-days.txt', age: const Duration(days: 2));
    final freshExport = await make('app-logs.txt');
    final dump = await make('data/goroutine-stop.log', age: const Duration(days: 11));
    final other = await make('data/clash.db', age: const Duration(days: 90));

    final dir = Directory(root.path);
    final cleaned = await cleanStaleFiles((baseDir: dir, workingDir: dir, tempDir: dir), now: now);

    for (final keep in [live, liveVariant, liveTmp, oldTmp, freshLog, freshExport, other]) {
      expect(keep.existsSync(), isTrue, reason: keep.path);
    }
    for (final gone in [orphan, orphanTmp, log, exported, dump]) {
      expect(gone.existsSync(), isFalse, reason: gone.path);
    }
    expect(cleaned.files, 5);
    expect(cleaned.bytes, 500);
  });
}
