import 'package:yaml/yaml.dart';

/// Turns a Clash subscription into share links (vless://, hy2://, trojan://, ss://), one per line.
///
/// The provider sends its real "LTE Only" servers only in Clash format, and the core's Clash reader
/// rejects that file; share links are what the core reads most reliably.
abstract class ClashToLinks {
  /// The links, or null when [content] isn't a Clash config with proxies.
  static String? convert(String content) {
    final Object? doc;
    try {
      doc = loadYaml(content);
    } catch (_) {
      return null;
    }
    if (doc is! YamlMap || doc['proxies'] is! YamlList) return null;
    final links = <String>[];
    for (final proxy in doc['proxies'] as YamlList) {
      if (proxy is! YamlMap) continue;
      final link = _link(proxy);
      if (link != null) links.add(link);
    }
    return links.isEmpty ? null : links.join('\n');
  }

  static String? _link(YamlMap p) {
    final name = Uri.encodeComponent('${p['name'] ?? ''}'.trim());
    final server = p['server'];
    final port = p['port'];
    if (server == null || port == null) return null;
    final host = '$server'.contains(':') ? '[$server]:$port' : '$server:$port';
    return switch (p['type']) {
      'vless' => 'vless://${Uri.encodeComponent('${p['uuid']}')}@$host?${_query(_vlessParams(p))}#$name',
      'trojan' => 'trojan://${Uri.encodeComponent('${p['password']}')}@$host?${_query(_vlessParams(p))}#$name',
      'hysteria2' =>
        'hy2://${Uri.encodeComponent('${p['password'] ?? p['auth'] ?? ''}')}@$host?${_query(_hy2Params(p))}#$name',
      _ => null,
    };
  }

  static Map<String, String?> _vlessParams(YamlMap p) {
    final reality = p['reality-opts'];
    final network = '${p['network'] ?? 'tcp'}';
    final ws = p['ws-opts'];
    final grpc = p['grpc-opts'];
    return {
      if (p['type'] == 'vless') 'encryption': 'none',
      'type': network,
      'security': reality is YamlMap ? 'reality' : (p['tls'] == true ? 'tls' : 'none'),
      'sni': _str(p['servername'] ?? p['sni']),
      'fp': _str(p['client-fingerprint']),
      'flow': _str(p['flow']),
      if (reality is YamlMap) ...{'pbk': _str(reality['public-key']), 'sid': _str(reality['short-id'])},
      if (grpc is YamlMap) 'serviceName': _str(grpc['grpc-service-name']),
      if (ws is YamlMap) ...{
        'path': _str(ws['path']),
        'host': ws['headers'] is YamlMap ? _str((ws['headers'] as YamlMap)['Host']) : null,
      },
      if (p['skip-cert-verify'] == true) 'allowInsecure': '1',
      if (p['packet-encoding'] != null) 'packetEncoding': _str(p['packet-encoding']),
    };
  }

  static Map<String, String?> _hy2Params(YamlMap p) {
    final alpn = p['alpn'];
    return {
      'sni': _str(p['sni']),
      if (alpn is YamlList && alpn.isNotEmpty) 'alpn': alpn.join(','),
      if (p['skip-cert-verify'] == true) 'insecure': '1',
      'obfs': _str(p['obfs']),
      'obfs-password': _str(p['obfs-password']),
    };
  }

  static String? _str(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

  static String _query(Map<String, String?> params) => [
    for (final e in params.entries)
      if (e.value != null) '${e.key}=${Uri.encodeComponent(e.value!)}',
  ].join('&');
}
