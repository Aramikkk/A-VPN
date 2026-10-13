import 'dart:io';

/// web build — there is no file system, so every call does nothing
void openLogFile(String path) {}

void writeLogLine(String line, {bool urgent = false}) {}

void flushLog() {}

const logDays = 3;

List<File> logDayFiles() => const [];

bool get isLogFileOpen => false;

Future<void> closeLogFile() async {}

Future<void> writeLinesToFile(String path, Iterable<String> lines) async {}
