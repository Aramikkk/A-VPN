import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/data/profile_merge.dart';

Map<String, dynamic> _server(String tag, String host, {String id = 'u', int port = 443, String? detour}) => {
  'type': 'vless',
  'tag': tag,
  'server': host,
  'server_port': port,
  'uuid': id,
  if (detour != null) 'detour': detour,
};

List<Object?> _tags(Map<String, dynamic> config) => [for (final o in config['outbounds'] as List) (o as Map)['tag']];

void main() {
  test('the extra profile servers are added with their own numbers, the active ones are kept', () {
    final primary = {
      'outbounds': [
        {
          'type': 'selector',
          'tag': 'select',
          'outbounds': ['A § 1'],
        },
        _server('A § 1', 'a.example'),
      ],
    };
    final extra = {
      'outbounds': [_server('B § 1', 'b.example'), _server('C § 2', 'c.example')],
    };
    expect(_tags(ProfileMerge.merge(primary, [extra])!), ['select', 'A § 1', 'B § 1001', 'C § 1002']);
  });

  test('a second extra profile is numbered from 2000, and the same server twice is added once', () {
    final primary = {
      'outbounds': [_server('A § 1', 'a.example')],
    };
    final first = {
      'outbounds': [_server('B § 1', 'b.example')],
    };
    final second = {
      'outbounds': [_server('B again § 1', 'b.example'), _server('C § 1', 'c.example')],
    };
    expect(_tags(ProfileMerge.merge(primary, [first, second])!), ['A § 1', 'B § 1001', 'C § 2001']);
  });

  test('a tag with no number gets one, the detour follows the new name, dummy servers stay out', () {
    final primary = {
      'outbounds': [_server('A § 1', 'a.example')],
    };
    final extra = {
      'outbounds': [
        _server('hop', 'h.example'),
        _server('through hop', 'x.example', id: 'x', detour: 'hop'),
        _server('App not supported § 0', '0.0.0.0', port: 1),
      ],
    };
    final merged = ProfileMerge.merge(primary, [extra])!;
    expect(_tags(merged), ['A § 1', 'hop § 1001', 'through hop § 1002']);
    expect(((merged['outbounds'] as List).last as Map)['detour'], 'hop § 1001');
  });

  test('nothing to add: no new config', () {
    final primary = {
      'outbounds': [_server('A § 1', 'a.example')],
    };
    final same = {
      'outbounds': [_server('A copy § 1', 'a.example')],
    };
    expect(ProfileMerge.merge(primary, [same]), isNull);
  });
  _countryTests();
}

void _countryTests() {
  Map<String, dynamic> profile(List<String> tags, {String host = 'h'}) => {
    'outbounds': [for (final (i, tag) in tags.indexed) _server(tag, '$host$i.example', id: '$host$i')],
  };

  test('countries of a profile, the most servers first, dummy servers not counted', () {
    final config = profile(['🇸🇪 Швеция § 1', '🇸🇪 Швеция 2 § 2', '🇩🇪 Германия § 3']);
    (config['outbounds'] as List).add(_server('App not supported § 0', '0.0.0.0', port: 1));
    expect(ProfileMerge.countries(config), [('SE', 2), ('DE', 1)]);
  });

  test('a country switched off marks its servers hidden, the others stay', () {
    final merged = ProfileMerge.merge(
      profile(['🇸🇪 Швеция § 1', '🇩🇪 Германия § 2']),
      const [],
      primaryHidden: {'DE'},
    )!;
    expect(_tags(merged), ['🇸🇪 Швеция § 1', '🇩🇪 Германия § 2 §hide§']);
  });

  test('every country switched off leaves the profile as it is', () {
    final config = profile(['🇸🇪 Швеция § 1', '🇩🇪 Германия § 2']);
    expect(ProfileMerge.merge(config, const [], primaryHidden: {'SE', 'DE'}), isNull);
  });

  test('an extra profile leaves its switched-off countries out', () {
    final merged = ProfileMerge.merge(
      profile(['🇸🇪 Швеция § 1']),
      [
        profile(['🇫🇮 Финляндия § 1', '🇳🇱 Нидерланды § 2'], host: 'x'),
      ],
      extrasHidden: [
        {'NL'},
      ],
    )!;
    expect(_tags(merged), ['🇸🇪 Швеция § 1', '🇫🇮 Финляндия § 1001']);
  });

  test('whitelist servers of a country are a choice of their own', () {
    final config = profile(['🇸🇪 Доступ - Швеция § 1', '🇸🇪 LTE Only - Швеция § 2', '🇸🇪 Швеция БС § 3']);
    expect(ProfileMerge.countries(config), [('SE:bs', 2), ('SE', 1)]);
    // the whitelist ones off, the ordinary one stays
    final merged = ProfileMerge.merge(config, const [], primaryHidden: {'SE:bs'})!;
    expect(_tags(merged), [
      '🇸🇪 Доступ - Швеция § 1',
      '🇸🇪 LTE Only - Швеция § 2 §hide§',
      '🇸🇪 Швеция БС § 3 §hide§',
    ]);
    // the ordinary one off, the whitelist ones stay
    final other = ProfileMerge.merge(
      profile(['🇸🇪 Доступ - Швеция § 1', '🇸🇪 LTE Only - Швеция § 2']),
      const [],
      primaryHidden: {'SE'},
    )!;
    expect(_tags(other), ['🇸🇪 Доступ - Швеция § 1 §hide§', '🇸🇪 LTE Only - Швеция § 2']);
  });

  test('country names and flags', () {
    expect(ProfileMerge.countryName('SE'), 'Швеция');
    expect(ProfileMerge.flag('SE'), '🇸🇪');
    expect(ProfileMerge.countryName('SE:bs'), 'Швеция');
    // a country the filter has no name for is named from the full list, and an unknown code stays as it is
    expect(ProfileMerge.countryName('LU'), 'Люксембург');
    expect(ProfileMerge.countryName('MT:bs'), 'Мальта');
    expect(ProfileMerge.countryName('ZZ'), 'ZZ');
    expect(ProfileMerge.flag('SE:bs'), '🇸🇪');
    expect(ProfileMerge.isWhitelist('SE:bs'), isTrue);
    expect(ProfileMerge.isWhitelist('SE'), isFalse);
  });
}
