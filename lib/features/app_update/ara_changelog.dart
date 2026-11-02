import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One version of the changelog: what changed in it, as the lines of its section.
class AraRelease {
  const AraRelease({required this.version, required this.date, required this.points});

  /// "1.1.19"
  final String version;

  /// "02.11.2026" (as written; empty when the heading has none)
  final String date;

  /// "02.11" for the About list
  String get shortDate {
    final parts = date.split('.');
    return parts.length >= 2 ? '${parts[0]}.${parts[1]}' : date;
  }

  final List<String> points;
}

final _heading = RegExp(r'^##\s+(\d+(?:\.\d+)+)\s*(?:[—–-]\s*(.*))?$');

/// The changelog (avpn/CHANGELOG.md: "## 1.1.19 — 02.11.2026" and a "- ..." line for each change), newest first as written.
List<AraRelease> parseChangelog(String text) {
  final releases = <AraRelease>[];
  String? version;
  var date = '';
  var points = <String>[];
  void close() {
    if (version != null) releases.add(AraRelease(version: version, date: date, points: points));
  }

  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    final match = _heading.firstMatch(line.trim());
    if (match != null) {
      close();
      version = match.group(1);
      date = (match.group(2) ?? '').trim();
      points = [];
    } else if (version != null && line.trimLeft().startsWith('- ')) {
      points.add(line.trimLeft().substring(2).trim());
    }
  }
  close();
  return releases;
}

/// The lines of latest.json's "notes" (one change to a line).
List<String> notePoints(String notes) => [
  for (final line in notes.split('\n'))
    if (line.trim().isNotEmpty) line.trim().replaceFirst(RegExp(r'^-\s+'), ''),
];

/// The changelog that came with this build.
final araChangelogProvider = FutureProvider<List<AraRelease>>((ref) async {
  try {
    return parseChangelog(await rootBundle.loadString('avpn/CHANGELOG.md'));
  } catch (_) {
    return const [];
  }
});
