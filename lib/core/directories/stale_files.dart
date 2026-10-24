import 'dart:io';

import 'package:hiddify/core/model/directories.dart';
import 'package:path/path.dart' as p;

/// What [cleanStaleFiles] removed.
typedef CleanedFiles = ({int files, int bytes});

/// Deletes what the app leaves behind and never reads again:
///
/// - the config files of profiles that are gone (a profile's variants are named after its file) and the half-made
///   `*.tmp.json` ones a day old;
/// - the daily logs older than a week;
/// - the logs the user exported (`a-vpn-logs-*`, `app-logs.txt`) a day after they were made;
/// - the core's old stack dump.
///
/// A file of a profile that still exists is never touched (the running core may read its variants), and every
/// failure is left alone: it's a clean-up, not a job that may stop anything.
Future<CleanedFiles> cleanStaleFiles(Directories dirs, {DateTime? now}) async {
  final clock = now ?? DateTime.now();
  var files = 0;
  var bytes = 0;

  Future<void> remove(File file) async {
    try {
      final size = await file.length();
      await file.delete();
      files++;
      bytes += size;
    } catch (_) {
      // in use, or gone already
    }
  }

  Future<List<File>> filesIn(Directory dir) async {
    try {
      if (!await dir.exists()) return const [];
      return [
        await for (final e in dir.list(followLinks: false))
          if (e is File) e,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> older(File file, Duration age) async {
    try {
      return clock.difference(await file.lastModified()) > age;
    } catch (_) {
      return false;
    }
  }

  final roots = {dirs.workingDir.path, dirs.baseDir.path};
  for (final root in roots) {
    // the configs: a profile is `<id>.json`; everything else that starts with its id is made from it
    final configs = await filesIn(Directory(p.join(root, 'configs')));
    final profiles = {
      for (final f in configs)
        if (RegExp(r'^[^.]+\.json$').hasMatch(p.basename(f.path))) p.basename(f.path).split('.').first,
    };
    for (final f in configs) {
      final name = p.basename(f.path);
      if (!name.contains('.')) continue;
      final id = name.split('.').first;
      if (name.endsWith('.tmp.json')) {
        if (await older(f, const Duration(days: 1))) await remove(f);
      } else if (!profiles.contains(id) && name.length > id.length + '.json'.length) {
        // a variant of a profile that no longer exists
        await remove(f);
      }
    }
    for (final f in await filesIn(Directory(p.join(root, 'logs')))) {
      final name = p.basename(f.path);
      if ((name.startsWith('a-vpn-') || name.startsWith('service-')) && name.endsWith('.log') && await older(f, const Duration(days: 7))) {
        await remove(f);
      }
    }
    for (final f in await filesIn(Directory(root))) {
      final name = p.basename(f.path);
      final export = name.startsWith('a-vpn-logs-') || name == 'app-logs.txt';
      if (export && await older(f, const Duration(days: 1))) await remove(f);
    }
    for (final f in await filesIn(Directory(p.join(root, 'data')))) {
      if (p.basename(f.path) == 'goroutine-stop.log' && await older(f, const Duration(days: 3))) await remove(f);
    }
  }
  return (files: files, bytes: bytes);
}
