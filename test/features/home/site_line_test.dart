import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';

void main() {
  setUp(resetSiteLine);

  test('no site has a server of its own yet: no line is kept', () {
    expect(keepSiteLine(false), isFalse);
    expect(keepSiteLine(false), isFalse);
  });

  test('once a site has had one, the line stays when the data is read again and there is none for a moment', () {
    expect(keepSiteLine(true), isTrue);
    // the app came back: the sites' servers are being read again, none shown
    expect(keepSiteLine(false), isTrue);
    expect(keepSiteLine(false), isTrue);
    expect(keepSiteLine(true), isTrue);
  });
}
