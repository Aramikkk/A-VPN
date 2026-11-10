import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/network_ping_timeout.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/settings/data/ai_group.dart';

void main() {
  pickerTests();
  const wifi = ['🇩🇪 Германия', '🇫🇮 Финляндия', '🇸🇪 Швеция', '🇳🇱 Нидерланды'];
  const mobile = ['🇸🇪 Швеция БС', '🇩🇪 Германия БС', '🇫🇮 Финляндия'];

  group('aiServersFor', () {
    test('Wi-Fi: the chosen servers in order, at most three', () {
      expect(
        aiServersFor(enabled: true, network: NetworkKind.wifi, wifi: wifi, mobile: const []),
        ['🇩🇪 Германия', '🇫🇮 Финляндия', '🇸🇪 Швеция'],
      );
    });

    test('a server chosen twice counts once', () {
      expect(
        aiServersFor(
          enabled: true,
          network: NetworkKind.wifi,
          wifi: const ['🇩🇪 Германия', '🇩🇪 Германия', '🇫🇮 Финляндия'],
          mobile: const [],
        ),
        ['🇩🇪 Германия', '🇫🇮 Финляндия'],
      );
    });

    test('LTE: only the whitelist servers', () {
      expect(
        aiServersFor(enabled: true, network: NetworkKind.mobile, wifi: wifi, mobile: mobile),
        ['🇸🇪 Швеция БС', '🇩🇪 Германия БС'],
      );
    });

    test('off: nothing', () {
      expect(aiServersFor(enabled: false, network: NetworkKind.wifi, wifi: wifi, mobile: mobile), isEmpty);
    });

    test('empty and blank entries are dropped', () {
      expect(
        aiServersFor(enabled: true, network: NetworkKind.wifi, wifi: const ['', '🇩🇪 Германия', ' '], mobile: const []),
        ['🇩🇪 Германия'],
      );
    });

    test('an unknown network uses the Wi-Fi list', () {
      expect(
        aiServersFor(enabled: true, network: NetworkKind.unknown, wifi: wifi, mobile: mobile).first,
        '🇩🇪 Германия',
      );
    });
  });

  test('the core gets the list in the monitoring block of the network config', () async {
    final dir = await Directory.systemTemp.createTemp('ai-group');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/profile.json');
    await file.writeAsString(jsonEncode({'outbounds': <dynamic>[], 'experimental': <String, dynamic>{}}));
    final withList = await withNetworkPingTimeout(
      file.path,
      NetworkKind.wifi,
      const Duration(seconds: 5),
      aiGroupServers: const ['a', 'b'],
    );
    final without = await withNetworkPingTimeout(file.path, NetworkKind.mobile, const Duration(seconds: 5));
    final w = jsonDecode(await File(withList).readAsString()) as Map<String, dynamic>;
    final m = jsonDecode(await File(without).readAsString()) as Map<String, dynamic>;
    expect(w['experimental']['monitoring']['ai_group_servers'], ['a', 'b']);
    expect((m['experimental']['monitoring'] as Map).containsKey('ai_group_servers'), isFalse);
  });
}

OutboundInfo _info(String tag, {int delay = 50, bool visible = true, bool group = false}) =>
    OutboundInfo(tag: tag, isVisible: visible, isGroup: group, urlTestDelay: delay);

void pickerTests() {
  group('setAiServer', () {
    test('fills the rows in order', () {
      expect(setAiServer(const [], 0, 'a'), ['a']);
      expect(setAiServer(const ['a'], 1, 'b'), ['a', 'b']);
      expect(setAiServer(const ['a', 'b'], 2, 'c'), ['a', 'b', 'c']);
    });
    test('a row past the end is added at the end', () {
      expect(setAiServer(const ['a'], 2, 'c'), ['a', 'c']);
    });
    test('replacing a row keeps the others', () {
      expect(setAiServer(const ['a', 'b', 'c'], 1, 'x'), ['a', 'x', 'c']);
    });
    test('a server already in another row moves, never repeats', () {
      expect(setAiServer(const ['a', 'b', 'c'], 0, 'c'), ['c', 'b']);
    });
    test('clearing a row removes it and the ones below move up', () {
      expect(setAiServer(const ['a', 'b', 'c'], 1, null), ['a', 'c']);
    });
  });

  group('aiCandidates', () {
    final items = [
      _info('🇩🇪 Германия'),
      _info('🇸🇪 Швеция БС'),
      _info('Auto', group: true),
      _info('hidden §hide§'),
      _info('🇫🇮 Финляндия', visible: false),
      _info('🇳🇱 Нидерланды'),
    ];
    test('Wi-Fi: the ordinary servers, no groups, no whitelist ones', () {
      expect(
        aiCandidates(items, network: NetworkKind.wifi, taken: const []).map((e) => e.tag),
        ['🇩🇪 Германия', '🇳🇱 Нидерланды'],
      );
    });
    test('LTE: only the whitelist servers', () {
      expect(aiCandidates(items, network: NetworkKind.mobile, taken: const []).map((e) => e.tag), ['🇸🇪 Швеция БС']);
    });
    test('the fastest first, the ones that did not answer last', () {
      final list = [_info('slow', delay: 200), _info('none', delay: 0), _info('fast', delay: 40), _info('mid', delay: 90)];
      expect(aiCandidates(list, network: NetworkKind.wifi, taken: const []).map((e) => e.tag), ['fast', 'mid', 'slow', 'none']);
    });
    test('the servers of the other rows are left out', () {
      expect(
        aiCandidates(items, network: NetworkKind.wifi, taken: const ['🇩🇪 Германия']).map((e) => e.tag),
        ['🇳🇱 Нидерланды'],
      );
    });
  });
}
