import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/country_scan.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';

void main() {
  test('LTE-only servers by the names providers give them', () {
    for (final name in [
      '🇸🇪 LTE Only - Швеция § 4',
      '🇪🇪 Эстония БС',
      '🇵🇱 Польша LTE',
      '🇩🇪 Германия (Белые списки)',
      '🇩🇪 Германия белый список',
      '🇫🇮 Финляндия Антиглушилка',
      '🇫🇮 Финляндия Whitelist',
      '🇱🇻 Латвия White List',
    ]) {
      expect(ServerRegionFilter.isMobileOnly(name), isTrue, reason: name);
    }
    for (final name in [
      '🇸🇪 Доступ - Швеция 2 § 29',
      '🇩🇪 Доступ - Германия § 36',
      '🇲🇹 Мальта § 3',
      '🇨🇿 Чехия (Обычный)',
    ]) {
      expect(ServerRegionFilter.isMobileOnly(name), isFalse, reason: name);
    }
  });

  test('the region filter lets a country in: Europe only, World and CIS, or none', () {
    expect(CountryScan.allowedByFilter('SE', europeOnly: true, cisOnly: false), isTrue);
    expect(CountryScan.allowedByFilter('US', europeOnly: true, cisOnly: false), isFalse);
    expect(CountryScan.allowedByFilter('RU', europeOnly: false, cisOnly: true), isFalse);
    expect(CountryScan.allowedByFilter('KZ', europeOnly: false, cisOnly: true), isTrue);
    expect(CountryScan.allowedByFilter('JP', europeOnly: false, cisOnly: false), isTrue);
  });
}
