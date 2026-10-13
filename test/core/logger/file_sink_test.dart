import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/logger/sinks/file_sink_io.dart';

void main() {
  late Directory dir;

  String today() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  File todayFile([String? folder]) => File('${folder ?? dir.path}/a-vpn-${today()}.log');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hiddify_log_sink');
  });

  tearDown(() async {
    await closeLogFile();
    await dir.delete(recursive: true);
  });

  test('an error is on disk before anything else runs', () {
    openLogFile(dir.path);
    writeLogLine('SEVERE something broke', urgent: true);

    // No await: the point of the file is to survive a crash that happens on the very next line.
    expect(todayFile().readAsStringSync(), 'SEVERE something broke\n');
  });

  test('ordinary lines gather and go together', () {
    openLogFile(dir.path);
    writeLogLine('one');
    writeLogLine('two');
    expect(todayFile().existsSync(), isFalse);
    flushLog();
    expect(todayFile().readAsStringSync(), 'one\ntwo\n');
  });

  test('a second run appends to the same day rather than starting over', () async {
    openLogFile(dir.path);
    writeLogLine('first run', urgent: true);
    await closeLogFile();

    openLogFile(dir.path);
    writeLogLine('second run', urgent: true);

    expect(todayFile().readAsStringSync(), 'first run\nsecond run\n');
  });

  test('days older than three go, the last three stay', () {
    final old = File('${dir.path}/a-vpn-2000-01-01.log')..writeAsStringSync('old');
    final other = File('${dir.path}/notes.txt')..writeAsStringSync('mine');
    todayFile().writeAsStringSync('today\n');
    openLogFile(dir.path);

    expect(old.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(logDayFiles().map((f) => f.uri.pathSegments.last), ['a-vpn-${today()}.log']);
  });

  test('a missing folder is created rather than refused', () {
    openLogFile('${dir.path}/nested/deeper');
    writeLogLine('made it', urgent: true);

    expect(todayFile('${dir.path}/nested/deeper').readAsStringSync(), 'made it\n');
  });

  test('an unwritable path leaves the sink closed instead of throwing', () {
    // A file where a folder should be: the only way to make a path unusable that behaves the same on Windows and
    // POSIX.
    final blocker = File('${dir.path}/blocker')..writeAsStringSync('x');

    expect(() => openLogFile('${blocker.path}/logs'), returnsNormally);
    expect(isLogFileOpen, isFalse);
    expect(() => writeLogLine('dropped', urgent: true), returnsNormally);
  });

  test('writing before opening does nothing', () {
    writeLogLine('dropped', urgent: true);
    expect(todayFile().existsSync(), isFalse);
  });
}
