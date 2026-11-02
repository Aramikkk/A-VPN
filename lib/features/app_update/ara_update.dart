import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hiddify/core/native/ara_tools.dart';
import 'package:path_provider/path_provider.dart';

/// What the update folder says about the newest build (its latest.json).
class AraUpdateInfo {
  const AraUpdateInfo({
    required this.version,
    required this.build,
    required this.apk,
    required this.size,
    required this.notes,
  });

  factory AraUpdateInfo.fromJson(Map<String, dynamic> json) => AraUpdateInfo(
    version: json['version'] as String,
    build: (json['build'] as num).toInt(),
    apk: json['apk'] as String,
    size: (json['size'] as num?)?.toInt() ?? 0,
    notes: (json['notes'] as String?) ?? '',
  );

  /// "1.1.13"
  final String version;

  /// the Android build number, which grows with every release
  final int build;

  /// the APK's file name in the folder
  final String apk;

  /// its size in bytes (0: not said)
  final int size;

  /// what is new, as written in the changelog
  final String notes;

  bool isNewerThan(int installedBuild) => build > installedBuild;
}

/// A-VPN's own update over the network: the newest build is looked up in a public folder of Yandex Disk (a latest.json and
/// the APK beside it), downloaded to the cache and handed to the system's installer.
abstract class AraUpdate {
  static const _resolver = 'cloud-api.yandex.net';

  /// The address a file of the public folder [folder] ("https://disk.yandex.ru/d/...") can be downloaded from.
  static Future<String> _href(Dio dio, String folder, String path) async {
    final response = await dio.get<Map<String, dynamic>>(
      'https://$_resolver/v1/disk/public/resources/download',
      queryParameters: {'public_key': folder, 'path': path},
    );
    final href = response.data?['href'] as String?;
    if (href == null || href.isEmpty) throw const FormatException('no link to the file');
    return href;
  }

  static Dio _dio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
      responseType: ResponseType.json,
    ),
  );

  /// The newest build in [folder], or null when the folder says nothing usable.
  static Future<AraUpdateInfo?> latest(String folder) async {
    final link = folder.trim();
    if (link.isEmpty) return null;
    final dio = _dio();
    try {
      final href = await _href(dio, link, '/latest.json');
      final body = await dio.get<String>(href, options: Options(responseType: ResponseType.plain));
      return AraUpdateInfo.fromJson(jsonDecode(body.data ?? '') as Map<String, dynamic>);
    } finally {
      dio.close();
    }
  }

  /// Downloads the APK of [info] from [folder] to the cache, [onProgress] told the share done (0 to 1). The file is
  /// checked against the size latest.json gives.
  static Future<File> download(String folder, AraUpdateInfo info, {void Function(double)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/ara_update');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}/${info.apk}');
    final dio = _dio();
    try {
      final href = await _href(dio, folder.trim(), '/${info.apk}');
      await dio.download(
        href,
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
    return file;
  }

  /// Hands the downloaded APK to the installer: "ok", "permission" (the page for allowing it opened) or "error".
  static Future<String> install(File apk, {bool allowSettings = true}) =>
      AraTools.install(apk.path, allowSettings: allowSettings);
}
