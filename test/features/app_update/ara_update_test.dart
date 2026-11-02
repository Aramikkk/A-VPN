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
}
