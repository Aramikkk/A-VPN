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
  static const defaultRepo = 'Aramikkk/A-VPN';

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

  /// Downloads the APK of [info] from the release to the cache, [onProgress] told the share done (0 to 1). The file is
  /// checked against the size latest.json gives.
  static Future<File> download(String setting, AraUpdateInfo info, {void Function(double)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/ara_update');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}/${info.apk}');
    final dio = _dio();
    try {
      await dio.download(
        fileUrl(setting, info.apk),
        file.path,
        onReceiveProgress: (done, total) {
          final whole = total > 0 ? total : info.size;
          if (whole > 0) onProgress?.call((done / whole).clamp(0.0, 1.0));
        },
      );
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

  /// Whether [file] has the SHA-256 [expected] (hex); true when none is expected.
  static bool matchesSha256(File file, String expected) {
    if (expected.isEmpty) return true;
    return sha256.convert(file.readAsBytesSync()).toString() == expected.trim().toLowerCase();
  }

  /// Hands the downloaded APK to the installer: "ok", "permission" (the page for allowing it opened) or "error".
  static Future<String> install(File apk, {bool allowSettings = true}) =>
      AraTools.install(apk.path, allowSettings: allowSettings);
}
