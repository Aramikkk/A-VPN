import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:hiddify/features/app_update/ara_update.dart';

void main() {
  test('latest.json is read, and only a larger build is newer', () {
    final info = AraUpdateInfo.fromJson({
      'version': '1.1.13',
      'build': 60113,
      'apk': 'A-VPN-1.1.13-arm64.apk',
      'size': 47000000,
      'notes': 'one\ntwo',
    });
    expect(info.version, '1.1.13');
    expect(info.apk, 'A-VPN-1.1.13-arm64.apk');
    expect(info.size, 47000000);
    expect(info.isNewerThan(60112), isTrue);
    expect(info.isNewerThan(60113), isFalse);
    expect(info.isNewerThan(60200), isFalse);
  });

  test('size and notes are optional', () {
    final info = AraUpdateInfo.fromJson({'version': '1.0.0', 'build': 1, 'apk': 'a.apk'});
    expect(info.size, 0);
    expect(info.notes, '');
  });

  test('the published SHA-256 is read, and a file is checked against it', () {
    final info = AraUpdateInfo.fromJson({
      'version': '1.1.23',
      'build': 60123,
      'apk': 'a.apk',
      'sha256': ' B5BB9D8014A0F9B1D61E21E796D78DCCDF1352F23CD32812F4850B878AE4944C ',
    });
    expect(info.sha256, 'b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c');
    final file = File('${Directory.systemTemp.path}/ara_sha_test.bin')..writeAsBytesSync([0x61, 0x62, 0x63]);
    addTearDown(file.deleteSync);
    // SHA-256 of "abc"
    const abc = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    expect(AraUpdate.matchesSha256(file, abc), isTrue);
    expect(AraUpdate.matchesSha256(file, abc.toUpperCase()), isTrue);
    expect(AraUpdate.matchesSha256(file, info.sha256), isFalse);
    // builds published before the hash was added say none: not refused
    expect(AraUpdate.matchesSha256(file, ''), isTrue);
    expect(AraUpdateInfo.fromJson({'version': '1', 'build': 1, 'apk': 'a'}).sha256, '');
  });

  test('updates come from the GitHub release of the project, whatever the old setting said', () {
    expect(AraUpdate.repoOf('Aramikkk/hiddify-app'), 'Aramikkk/hiddify-app');
    expect(AraUpdate.repoOf('https://github.com/Someone/fork.git'), 'Someone/fork');
    expect(AraUpdate.repoOf('https://github.com/Someone/fork/releases'), 'Someone/fork');
    // the folder on Yandex Disk of the versions before 1.2, an empty value, and nonsense: the project's own
    expect(AraUpdate.repoOf('https://disk.yandex.ru/d/BLa0rzQRrl98Ig'), AraUpdate.defaultRepo);
    expect(AraUpdate.repoOf(''), AraUpdate.defaultRepo);
    expect(AraUpdate.repoOf('a b/c'), AraUpdate.defaultRepo);
  });

  test('a file of the release is a plain name on github.com', () {
    expect(
      AraUpdate.fileUrl('Aramikkk/hiddify-app', 'latest.json'),
      'https://github.com/Aramikkk/hiddify-app/releases/latest/download/latest.json',
    );
    expect(AraUpdate.fileUrl('', 'A-VPN-1.2.0-arm64.apk'), contains('/Aramikkk/hiddify-app/releases/latest/download/'));
    for (final bad in ['', '../x.apk', 'a/b.apk', r'a\b.apk']) {
      expect(() => AraUpdate.fileUrl('', bad), throwsFormatException);
    }
  });

  test('the newest build is read from the release, and no release yet is no update', () async {
    // the test engine answers every request with 400: this one talks to a server of its own
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      if (request.uri.path == '/latest.json') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            '{"version":"1.2.1","build":60201,"apk":"A-VPN-1.2.1-arm64.apk","size":10,"sha256":"","notes":"One\\nTwo"}',
          );
      } else {
        request.response.statusCode = 404;
      }
      request.response.close();
    });
    final before = AraUpdate.testBase;
    addTearDown(() => AraUpdate.testBase = before);
    AraUpdate.testBase = 'http://127.0.0.1:${server.port}';
    final info = await AraUpdate.latest('');
    expect(info?.version, '1.2.1');
    expect(info?.build, 60201);
    expect(info?.isNewerThan(60200), isTrue);
    // a release without latest.json: nothing to offer
    AraUpdate.testBase = 'http://127.0.0.1:${server.port}/nothing-here';
    expect(await AraUpdate.latest(''), isNull);
  });

  group('the APK download', () {
    final bytes = Uint8List.fromList(List.generate(300001, (i) => (i * 31 + i ~/ 7) & 255));
    late HttpServer server;
    var ranged = 0;
    var cutOnce = false;
    var cut = <String>{};

    Future<void> serve({required bool ranges}) async {
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final range = request.headers.value('range');
        final m = range == null ? null : RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range);
        if (!ranges || m == null) {
          request.response.headers.contentLength = bytes.length;
          request.response.add(bytes);
          await request.response.close();
          return;
        }
        ranged++;
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(2)!);
        request.response
          ..statusCode = 206
          ..headers.set('content-range', 'bytes $a-$b/${bytes.length}')
          ..headers.contentLength = b - a + 1;
        // the first try of the second piece breaks half way: the rest must be asked for again
        if (cutOnce && a > 0 && b - a > 30000 && cut.add('$a')) {
          final socket = await request.response.detachSocket();
          socket.add(bytes.sublist(a, a + 20000));
          await socket.flush();
          await socket.close();
          return;
        }
        request.response.add(bytes.sublist(a, b + 1));
        await request.response.close();
      });
      final before = AraUpdate.testBase;
      addTearDown(() => AraUpdate.testBase = before);
      AraUpdate.testBase = 'http://127.0.0.1:${server.port}';
    }

    AraUpdateInfo info() => AraUpdateInfo.fromJson({
      'version': '9.9.9',
      'build': 90909,
      'apk': 'dl-test.apk',
      'size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    });

    setUp(() {
      ranged = 0;
      cutOnce = false;
      cut = {};
      PathProviderPlatform.instance = _TempPaths();
    });

    test('comes in pieces at once and arrives whole', () async {
      await serve(ranges: true);
      final seen = <double>[];
      final file = await AraUpdate.download('', info(), onProgress: seen.add);
      expect(file.readAsBytesSync(), bytes);
      expect(ranged, greaterThan(AraUpdate.parts));
      expect(seen.last, 1.0);
    });

    test('a broken piece is carried on from where it stopped', () async {
      cutOnce = true;
      await serve(ranges: true);
      final file = await AraUpdate.download('', info());
      expect(file.readAsBytesSync(), bytes);
      expect(cut, isNotEmpty);
    });

    test('a server without ranges gives the plain download', () async {
      await serve(ranges: false);
      final file = await AraUpdate.download('', info());
      expect(file.readAsBytesSync(), bytes);
    });
  });
}

class _TempPaths extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.createTempSync('ara_dl').path;
}
