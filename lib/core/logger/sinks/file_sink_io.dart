import 'dart:async';
import 'dart:io';

/// The log's folder: one file a day (`a-vpn-2026-10-13.log`), the last [logDays] days kept.
String? _dir;

/// How many days of log are kept; older files are deleted.
const logDays = 3;

bool get isLogFileOpen => _dir != null;

/// Opens by creating the folder and proving it is writable, so a bad path is known now rather than silently
/// swallowed at the first line worth recording. Days past [logDays] go at once.
void openLogFile(String dir) {
  try {
    final folder = Directory(dir)..createSync(recursive: true);
    File('${folder.path}/.probe').writeAsStringSync('');
    _dir = folder.path;
    _prune();
  } catch (_) {
    _dir = null;
  }
}

String _day(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

String? _lastDay;
final _pending = StringBuffer();
Timer? _flushTimer;

/// Lines gather for a few seconds and go to the file together, so a busy moment isn't a disk write per line;
/// an error goes at once ([urgent]), since the crash that may follow would lose what is still in memory.
void writeLogLine(String line, {bool urgent = false}) {
  if (_dir == null) return;
  _pending.writeln(line);
  if (urgent) {
    flushLog();
  } else {
    _flushTimer ??= Timer(const Duration(seconds: 5), flushLog);
  }
}

void flushLog() {
  _flushTimer?.cancel();
  _flushTimer = null;
  final dir = _dir;
  if (dir == null || _pending.isEmpty) return;
  final day = _day(DateTime.now());
  try {
    File('$dir/a-vpn-$day.log').writeAsStringSync(_pending.toString(), mode: FileMode.append);
  } catch (_) {
    // A log file that cannot be written must never take the app down.
  }
  _pending.clear();
  if (_lastDay != day) {
    _lastDay = day;
    _prune();
  }
}

final _dayFile = RegExp(r'^(?:a-vpn|service)-(\d{4}-\d{2}-\d{2})\.log$');

/// Deletes the days older than [logDays].
void _prune() {
  final dir = _dir;
  if (dir == null) return;
  final keep = {for (var i = 0; i < logDays; i++) _day(DateTime.now().subtract(Duration(days: i)))};
  try {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final match = _dayFile.firstMatch(f.uri.pathSegments.last);
      if (match != null && !keep.contains(match.group(1))) f.deleteSync();
    }
  } catch (_) {}
}

/// The kept days' files, oldest first.
List<File> logDayFiles() {
  final dir = _dir;
  if (dir == null) return const [];
  flushLog();
  try {
    return Directory(dir).listSync().whereType<File>().where((f) => _dayFile.hasMatch(f.uri.pathSegments.last)).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  } catch (_) {
    return const [];
  }
}

Future<void> closeLogFile() async {
  flushLog();
  _dir = null;
}

/// Writes [lines] to [path] in one go, replacing whatever was there. Used by
/// the logs page to export the in-memory history, which is a different file.
Future<void> writeLinesToFile(String path, Iterable<String> lines) async {
  await File(path).writeAsString(lines.join('\n'));
}
