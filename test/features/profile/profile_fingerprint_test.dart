import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';

void main() {
  test('a refresh that brings the same servers has the same fingerprint, a changed one has another', () async {
    final dir = Directory.systemTemp.createTempSync('fingerprint');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/p.json');
    expect(await profileContentFingerprint(file), isNull, reason: 'no file');
    file.writeAsStringSync('{"outbounds":[1,2,3]}');
    final first = await profileContentFingerprint(file);
    file.writeAsStringSync('{"outbounds":[1,2,3]}');
    expect(await profileContentFingerprint(file), first);
    file.writeAsStringSync('{"outbounds":[1,2,3,4]}');
    expect(await profileContentFingerprint(file), isNot(first));
  });
}
