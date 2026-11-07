import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(AraUpdate.repoOf('Aramikkk/A-VPN'), 'Aramikkk/A-VPN');
    expect(AraUpdate.repoOf('https://github.com/Someone/fork.git'), 'Someone/fork');
    expect(AraUpdate.repoOf('https://github.com/Someone/fork/releases'), 'Someone/fork');
    // the folder on Yandex Disk of the versions before 1.2, an empty value, and nonsense: the project's own
    expect(AraUpdate.repoOf('https://disk.yandex.ru/d/REPLACED'), AraUpdate.defaultRepo);
    expect(AraUpdate.repoOf(''), AraUpdate.defaultRepo);
    expect(AraUpdate.repoOf('a b/c'), AraUpdate.defaultRepo);
  });

  test('a file of the release is a plain name on github.com', () {
    expect(
      AraUpdate.fileUrl('Aramikkk/A-VPN', 'latest.json'),
      'https://github.com/Aramikkk/A-VPN/releases/latest/download/latest.json',
    );
    expect(AraUpdate.fileUrl('', 'A-VPN-1.2.0-arm64.apk'), contains('/Aramikkk/A-VPN/releases/latest/download/'));
    for (final bad in ['', '../x.apk', 'a/b.apk', r'a\b.apk']) {
      expect(() => AraUpdate.fileUrl('', bad), throwsFormatException);
    }
  });
}
