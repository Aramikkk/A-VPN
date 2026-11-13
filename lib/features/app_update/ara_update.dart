import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:hiddify/core/native/ara_tools.dart';
import 'package:path_provider/path_provider.dart';

/// What the newest release says about its build (its latest.json).
class AraUpdateInfo {
  const AraUpdateInfo({
    required this.version,
    required this.build,
    required this.apk,
    required this.size,
    required this.notes,
    this.sha256 = '',
  });

  factory AraUpdateInfo.fromJson(Map<String, dynamic> json) => AraUpdateInfo(
    version: json['version'] as String,
    build: (json['build'] as num).toInt(),
    apk: json['apk'] as String,
    size: (json['size'] as num?)?.toInt() ?? 0,
    notes: (json['notes'] as String?) ?? '',
    sha256: ((json['sha256'] as String?) ?? '').trim().toLowerCase(),
  );

  /// "1.1.13"
  final String version;

  /// the Android build number, which grows with every release
  final int build;

  /// the APK's file name among the release's files
  final String apk;

  /// its size in bytes (0: not said)
  final int size;

  /// what is new, as written in the changelog
  final String notes;

  /// the APK's SHA-256 (hex; empty: not said, as in the builds before it was added)
  final String sha256;

  bool isNewerThan(int installedBuild) => build > installedBuild;
}

/// A-VPN's own update over the network: the newest build is looked up in the GitHub Releases of the project (a latest.json
/// and the APK among the release's files), downloaded to the cache and handed to the system's installer. The APK is checked
/// against the SHA-256 of latest.json, which comes from the same release.
abstract class AraUpdate {
  /// The project's releases: where the program updates itself from.
  static const defaultRepo = 'Aramikkk/hiddify-app';

  /// For tests only: the release's files are taken from this address (a local server) instead of GitHub. Empty in the app
  /// (set at build time with --dart-define=ARA_UPDATE_BASE=http://127.0.0.1:8099, or by a test).
  static String? testBase = const String.fromEnvironment('ARA_UPDATE_BASE').isEmpty
      ? null
      : const String.fromEnvironment('ARA_UPDATE_BASE');

  static final _repoPattern = RegExp(r'^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$');

  /// The "owner/repo" an update is looked for in. [setting] may be a repo, a GitHub link to it, or (as saved by the
  /// versions before 1.2, which updated from a folder on Yandex Disk) anything else: that gives [defaultRepo].
  static String repoOf(String setting) {
    var value = setting.trim();
    final link = RegExp(r'^https://github\.com/([^/]+/[^/#?]+)').firstMatch(value);
    if (link != null) value = link.group(1)!;
    if (value.endsWith('.git')) value = value.substring(0, value.length - 4);
    return _repoPattern.hasMatch(value) ? value : defaultRepo;
  }

  /// The address of a file of the newest release of [setting]'s repo. The name is a plain file name.
  static String fileUrl(String setting, String name) {
    if (name.isEmpty || name.contains('/') || name.contains(r'\') || name.contains('..')) {
      throw const FormatException('not a file name');
    }
    final base = testBase;
    if (base != null) return '$base/${Uri.encodeComponent(name)}';
    return 'https://github.com/${repoOf(setting)}/releases/latest/download/${Uri.encodeComponent(name)}';
  }

  static Dio _dio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
      responseType: ResponseType.json,
    ),
  );

  /// The newest build of the project in [setting] (see [repoOf]), or null when the release says nothing usable.
  static Future<AraUpdateInfo?> latest(String setting) async {
    final dio = _dio();
    try {
      final body = await dio.get<String>(
        fileUrl(setting, 'latest.json'),
        options: Options(responseType: ResponseType.plain),
      );
      return AraUpdateInfo.fromJson(jsonDecode(body.data ?? '') as Map<String, dynamic>);
    } on DioException catch (e) {
      // no release yet
      if (e.response?.statusCode == 404) return null;
      rethrow;
    } finally {
      dio.close();
    }
  }

  /// How many pieces the APK is fetched in at once: a carrier that holds one connection to the CDN down (a few KB/s) does not
  /// do so for each of several.
  static const parts = 6;

  /// Downloads the APK of [info] from the release to the cache, [onProgress] told the share done (0 to 1). The file comes in
  /// [parts] pieces at once (HTTP Range) when the server allows it, and what already came of a broken download is kept and
  /// carried on from. It is checked against the size and the SHA-256 latest.json gives.
  static Future<File> download(String setting, AraUpdateInfo info, {void Function(double)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/ara_update');
    dir.createSync(recursive: true);
    // anything left of other builds goes; the pieces of this one stay
    for (final e in dir.listSync()) {
      if (!e.path.split(RegExp(r'[\/]')).last.startsWith(info.apk)) e.deleteSync(recursive: true);
    }
    final file = File('${dir.path}/${info.apk}');
    if (file.existsSync()) file.deleteSync();
    final url = fileUrl(setting, info.apk);
    final dio = _dio();
    try {
      final total = await _rangeTotal(dio, url);
      if (total == null) {
        // no ranges: the plain download, as before
        await dio.download(
          url,
          file.path,
          onReceiveProgress: (done, whole) {
            final all = whole > 0 ? whole : info.size;
            if (all > 0) onProgress?.call((done / all).clamp(0.0, 1.0));
          },
        );
      } else {
        await _fetchInParts(dio, url, file, total, onProgress);
      }
    } finally {
      dio.close();
    }
    if (info.size > 0 && file.lengthSync() != info.size) {
      file.deleteSync();
      throw const FormatException('the file came incomplete');
    }
    if (!matchesSha256(file, info.sha256)) {
      file.deleteSync();
      throw const FormatException('the file is not the one that was published');
    }
    return file;
  }

  /// The size of the file when the server takes ranges (it answers 206 with a Content-Range), else null.
  static Future<int?> _rangeTotal(Dio dio, String url) async {
    try {
      final r = await dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream, headers: {'Range': 'bytes=0-0'}),
      );
      await r.data!.stream.drain<void>();
      if (r.statusCode != 206) return null;
      final total = int.tryParse((r.headers.value('content-range') ?? '').split('/').last);
      return total != null && total > parts ? total : null;
    } on DioException {
      return null;
    }
  }

  static Future<void> _fetchInParts(
    Dio dio,
    String url,
    File file,
    int total,
    void Function(double)? onProgress,
  ) async {
    final size = (total / parts).ceil();
    final have = List<int>.filled(parts, 0);
    void report() => onProgress?.call((have.fold<int>(0, (a, b) => a + b) / total).clamp(0.0, 1.0));

    Future<void> piece(int n) async {
      final from = n * size;
      final to = (from + size < total ? from + size : total) - 1;
      final want = to - from + 1;
      final part = File('${file.path}.part$n');
      if (part.existsSync() && part.lengthSync() > want) part.deleteSync();
      have[n] = part.existsSync() ? part.lengthSync() : 0;
      report();
      for (var attempt = 0; have[n] < want; attempt++) {
        try {
          final r = await dio.get<ResponseBody>(
            url,
            options: Options(
              responseType: ResponseType.stream,
              // a stalled connection is given up on and carried on from where it stopped
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Range': 'bytes=${from + have[n]}-$to'},
            ),
          );
          if (r.statusCode != 206) throw const FormatException('no range');
          final sink = part.openWrite(mode: FileMode.append);
          try {
            await for (final chunk in r.data!.stream) {
              sink.add(chunk);
              have[n] += chunk.length;
              report();
            }
          } finally {
            await sink.close();
          }
        } catch (_) {
          have[n] = part.existsSync() ? part.lengthSync() : 0;
          if (attempt >= 6) rethrow;
          await Future<void>.delayed(Duration(seconds: attempt < 3 ? 1 : 3));
        }
      }
    }

    await Future.wait([for (var n = 0; n < parts; n++) piece(n)]);
    final out = file.openWrite();
    try {
      for (var n = 0; n < parts; n++) {
        final part = File('${file.path}.part$n');
        await out.addStream(part.openRead());
        part.deleteSync();
      }
    } finally {
      await out.close();
    }
  }

  /// Whether [file] has the SHA-256 [expected] (hex); true when none is expected.
  static bool matchesSha256(File file, String expected) {
    if (expected.isEmpty) return true;
    return sha256.convert(file.readAsBytesSync()).toString() == expected.trim().toLowerCase();
  }

  /// Hands the downloaded APK to the installer: "ok", "permission" (the page for allowing it opened) or "error".
  static Future<String> install(File apk, {bool allowSettings = true}) =>
      AraTools.install(apk.path, allowSettings: allowSettings);
}
