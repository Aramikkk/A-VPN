import 'dart:convert';

/// A subscription in Xray's JSON form (what Happ-style panels answer): a list of configs, one server each, with a
/// `remarks` name and an `outbounds` list. The core reads share links, so the servers are handed to it as links.
abstract class XrayJsonToLinks {
  /// What the last conversion did: configs in the answer, links made, and what was left out (by the protocol).
  static ({int configs, int links, Map<String, int> skipped}) lastReport = (configs: 0, links: 0, skipped: const {});

  /// The links, one per config, or null when [content] isn't such a subscription.
  static String? convert(String content) {
    final text = content.trim();
    if (!text.startsWith('[') && !text.startsWith('{')) return null;
    final Object? doc;
    try {
      doc = jsonDecode(text);
    } catch (_) {
      return null;
    }
    final configs = doc is List ? doc : [doc];
    final links = <String>[];
    final skipped = <String, int>{};
    var count = 0;
    for (final config in configs) {
      if (config is! Map) continue;
      final outbounds = config['outbounds'];
      if (outbounds is! List) continue;
      count++;
      String? first;
      var found = false;
      for (final outbound in outbounds) {
        if (outbound is! Map) continue;
        final link = _link(Map<String, dynamic>.from(outbound), '${config['remarks'] ?? outbound['tag'] ?? ''}');
        if (link != null) {
          links.add(link);
          found = true;
          break;
        }
        // the first outbound that was a server but couldn't be made a link: what it was
        final protocol = '${outbound['protocol']}';
        if (first == null && !const ['freedom', 'blackhole', 'dns', 'direct', 'block'].contains(protocol)) {
          first = protocol;
        }
      }
      if (!found) skipped[first ?? 'no server'] = (skipped[first ?? 'no server'] ?? 0) + 1;
    }
    lastReport = (configs: count, links: links.length, skipped: skipped);
    return links.isEmpty ? null : links.join('\n');
  }

  static String? _link(Map<String, dynamic> outbound, String name) {
    final settings = _map(outbound['settings']);
    final stream = _map(outbound['streamSettings']);
    final fragment = Uri.encodeComponent(name);
    switch (outbound['protocol']) {
      case 'vless':
        final server = _server(settings, 'vnext');
        final user = _first(server['users']);
        final id = '${user['id'] ?? server['id'] ?? ''}';
        final host = '${server['address'] ?? ''}';
        final port = _int(server['port']);
        if (id.isEmpty || host.isEmpty || port == null) return null;
        final query = <String, String>{
          'encryption': '${user['encryption'] ?? server['encryption'] ?? 'none'}',
          if ('${user['flow'] ?? server['flow'] ?? ''}'.isNotEmpty) 'flow': '${user['flow'] ?? server['flow']}',
          ..._streamQuery(stream),
        };
        return 'vless://$id@${_host(host)}:$port?${_encode(query)}#$fragment';
      case 'trojan':
        final server = _server(settings, 'servers');
        final password = '${server['password'] ?? ''}';
        final host = '${server['address'] ?? ''}';
        final port = _int(server['port']);
        if (password.isEmpty || host.isEmpty || port == null) return null;
        return 'trojan://${Uri.encodeComponent(password)}@${_host(host)}:$port?${_encode(_streamQuery(stream))}#$fragment';
      case 'hysteria':
        // Hysteria 2 (Xray's `hysteria` outbound, version 2): the link the core reads
        final server = _server(settings, 'servers');
        final hysteria = _map(stream['hysteriaSettings']);
        final version = _int(hysteria['version'] ?? settings['version'] ?? server['version']) ?? 2;
        final host = '${server['address'] ?? ''}';
        final port = _int(server['port']);
        final auth = '${hysteria['auth'] ?? settings['auth'] ?? server['auth'] ?? ''}';
        if (version != 2 || host.isEmpty || port == null) return null;
        final tls = _map(stream['tlsSettings']);
        final query = <String, String>{};
        _put(query, 'sni', tls['serverName']);
        if (tls['allowInsecure'] == true) query['insecure'] = '1';
        final alpn = tls['alpn'];
        if (alpn is List && alpn.isNotEmpty) query['alpn'] = alpn.join(',');
        final userinfo = auth.isEmpty ? '' : '${Uri.encodeComponent(auth)}@';
        return 'hysteria2://$userinfo${_host(host)}:$port${query.isEmpty ? '' : '?${_encode(query)}'}#$fragment';
      case 'shadowsocks':
        final server = _server(settings, 'servers');
        final method = '${server['method'] ?? ''}';
        final password = '${server['password'] ?? ''}';
        final host = '${server['address'] ?? ''}';
        final port = _int(server['port']);
        if (method.isEmpty || password.isEmpty || host.isEmpty || port == null) return null;
        final userinfo = base64Url.encode(utf8.encode('$method:$password')).replaceAll('=', '');
        return 'ss://$userinfo@${_host(host)}:$port#$fragment';
      case 'vmess':
        final server = _server(settings, 'vnext');
        final user = _first(server['users']);
        final host = '${server['address'] ?? ''}';
        final port = _int(server['port']);
        final id = '${user['id'] ?? ''}';
        if (id.isEmpty || host.isEmpty || port == null) return null;
        final query = _streamQuery(stream);
        final body = {
          'v': '2',
          'ps': name,
          'add': host,
          'port': '$port',
          'id': id,
          'aid': '${user['alterId'] ?? 0}',
          'scy': '${user['security'] ?? 'auto'}',
          'net': query['type'] ?? 'tcp',
          'type': query['headerType'] ?? 'none',
          'host': query['host'] ?? '',
          'path': query['path'] ?? query['serviceName'] ?? '',
          'tls': query['security'] == 'tls' ? 'tls' : '',
          'sni': query['sni'] ?? '',
          'alpn': query['alpn'] ?? '',
          'fp': query['fp'] ?? '',
        };
        return 'vmess://${base64.encode(utf8.encode(jsonEncode(body)))}';
    }
    return null;
  }

  /// The transport and security of the stream as a link's query.
  static Map<String, String> _streamQuery(Map<String, dynamic> stream) {
    final network = '${stream['network'] ?? 'tcp'}';
    final security = '${stream['security'] ?? 'none'}';
    final query = <String, String>{'type': network == 'splithttp' ? 'xhttp' : network, 'security': security};
    final tls = _map(stream['tlsSettings']);
    final reality = _map(stream['realitySettings']);
    if (security == 'reality') {
      _put(query, 'sni', reality['serverName']);
      _put(query, 'fp', reality['fingerprint']);
      _put(query, 'pbk', reality['publicKey']);
      _put(query, 'sid', reality['shortId']);
      _put(query, 'spx', reality['spiderX']);
    } else if (security == 'tls') {
      _put(query, 'sni', tls['serverName']);
      _put(query, 'fp', tls['fingerprint']);
      final alpn = tls['alpn'];
      if (alpn is List && alpn.isNotEmpty) query['alpn'] = alpn.join(',');
      if (tls['allowInsecure'] == true) query['allowInsecure'] = '1';
    }
    switch (network) {
      case 'ws':
        final ws = _map(stream['wsSettings']);
        _put(query, 'path', ws['path']);
        _put(query, 'host', ws['host'] ?? _map(ws['headers'])['Host']);
      case 'grpc':
        final grpc = _map(stream['grpcSettings']);
        _put(query, 'serviceName', grpc['serviceName']);
        if (grpc['multiMode'] == true) query['mode'] = 'multi';
      case 'httpupgrade':
        final http = _map(stream['httpupgradeSettings']);
        _put(query, 'path', http['path']);
        _put(query, 'host', http['host']);
      case 'xhttp' || 'splithttp':
        final http = _map(stream['xhttpSettings'] ?? stream['splithttpSettings']);
        _put(query, 'path', http['path']);
        _put(query, 'host', http['host']);
        _put(query, 'mode', http['mode']);
      case 'h2' || 'http':
        final http = _map(stream['httpSettings']);
        _put(query, 'path', http['path']);
        final hosts = http['host'];
        if (hosts is List && hosts.isNotEmpty) query['host'] = hosts.join(',');
      case 'tcp':
        final header = _map(_map(stream['tcpSettings'])['header']);
        if (header['type'] == 'http') {
          query['headerType'] = 'http';
          final request = _map(header['request']);
          final paths = request['path'];
          if (paths is List && paths.isNotEmpty) query['path'] = paths.join(',');
          final hosts = _map(request['headers'])['Host'];
          if (hosts is List && hosts.isNotEmpty) query['host'] = hosts.join(',');
          if (hosts is String) query['host'] = hosts;
        }
    }
    return query;
  }

  /// The server of a vless/vmess/trojan/shadowsocks outbound: the older `vnext`/`servers` list, or the newer flat form.
  static Map<String, dynamic> _server(Map<String, dynamic> settings, String key) {
    final list = settings[key];
    if (list is List && list.isNotEmpty && list.first is Map) return Map<String, dynamic>.from(list.first as Map);
    return settings;
  }

  static Map<String, dynamic> _first(Object? list) =>
      list is List && list.isNotEmpty && list.first is Map ? Map<String, dynamic>.from(list.first as Map) : {};

  static Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : {};

  static int? _int(Object? value) => value is int ? value : int.tryParse('$value');

  static void _put(Map<String, String> query, String key, Object? value) {
    final text = value == null ? '' : '$value';
    if (text.isNotEmpty) query[key] = text;
  }

  static String _host(String host) => host.contains(':') && !host.startsWith('[') ? '[$host]' : host;

  static String _encode(Map<String, String> query) =>
      query.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
}
