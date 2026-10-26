import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/network_ping_timeout.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';

void main() {
  test('network variants retain distinct timeouts without overwriting profile', () async {
    final dir = await Directory.systemTemp.createTemp('network-ping');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/profile.json');
    await file.writeAsString(
      jsonEncode({
        'outbounds': [
          {
            'type': 'urltest',
            'tag': 'lowest',
            'options': {'tolerance': 150},
          },
          {'type': 'direct', 'tag': 'plain'},
        ],
        'experimental': {
          'cache_file': {'enabled': true},
        },
      }),
    );
    final wifi = await withNetworkPingTimeout(
      file.path,
      NetworkKind.wifi,
      const Duration(seconds: 1),
      balancerTolerance: 150,
      siteGroups: true,
      siteGroupsTolerance: 2500,
    );
    final mobile = await withNetworkPingTimeout(
      file.path,
      NetworkKind.mobile,
      const Duration(seconds: 30),
      balancerTolerance: 25,
    );
    final w = jsonDecode(await File(wifi).readAsString()) as Map<String, dynamic>;
    final m = jsonDecode(await File(mobile).readAsString()) as Map<String, dynamic>;
    expect(w['experimental']['monitoring']['url_test_timeout'], '1s');
    expect(m['experimental']['monitoring']['url_test_timeout'], '30s');
    expect(w['outbounds'][0]['options']['tolerance'], 150);
    expect(m['outbounds'][0]['options']['tolerance'], 25);
    expect(m['outbounds'][1]['tag'], 'plain');
    expect(w['experimental']['cache_file']['enabled'], true);
    expect(jsonDecode(await file.readAsString())['experimental'].containsKey('monitoring'), false);
    // each network's own site groups choice
    expect(w['experimental']['monitoring']['site_groups'], true);
    expect(w['experimental']['monitoring']['site_groups_tolerance'], 2500);
    expect(m['experimental']['monitoring']['site_groups'], false);
    // Wi-Fi has many servers: its background checks are spread; mobile data checks them all at once
    expect(w['outbounds'][0]['options']['start_batch'], 8);
    expect(w['outbounds'][0]['options']['start_gap'], '20s');
    expect(m['outbounds'][0]['options'].containsKey('start_batch'), false);
    expect(wifi, isNot(mobile));
  });
}
