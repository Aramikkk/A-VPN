// Writes a start config with the real "only blocked" rules to $EXPORT (when set), so the core's own config
// builder can be run on it: HiddifyCli build -c <file>.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/data/blocked_only_routing.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';

void main() {
  test('export the blocked-only start config', () async {
    final out = Platform.environment['EXPORT'];
    if (out == null) return;
    final config = {
      'outbounds': [
        {'type': 'socks', 'tag': 'proxy-a', 'server': '127.0.0.1', 'server_port': 1080},
        {'type': 'socks', 'tag': 'proxy-b', 'server': '127.0.0.1', 'server_port': 1081},
      ],
      'route': {
        'rules': BlockedOnlyRouting.rules(
          list: [for (final builtin in BuiltinRule.values) builtin.rule..enabled = builtin.enabledByDefault],
          extraProxyHosts: ['www.gstatic.com'],
        ),
      },
    };
    await File(out).writeAsString(jsonEncode(config));
  });
}
