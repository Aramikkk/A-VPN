import 'dart:convert';

/// A provider that doesn't know the client answers with decoys in place of servers: "App not supported", "Download
/// Happ" at an address that leads nowhere. Told from the subscription's text, so another client name can be tried.
abstract class SubscriptionDecoy {
  /// The names a decoy server carries.
  static final _marks = RegExp(
    r'не\s+поддерживается|не\s+поддерживается|скачайте|установите\s+приложение|not\s+supported|unsupported|'
    r'download\s+(the\s+)?(happ|app)|use\s+happ|please\s+use|обновите\s+приложение|missing[-\s]?hwid|идентификатор\s+устройства',
    caseSensitive: false,
    unicode: true,
  );

  /// Whether every server in the subscription [content] (share links, plain or base64) is a decoy. A subscription with
  /// no server to read in it isn't called a decoy: there is nothing to tell.
  static bool isDecoy(String content) {
    final links = _links(content);
    if (links.isEmpty) return false;
    return links.every(_isDecoyLink);
  }

  /// Whether [content] can be a subscription at all: share links, a JSON or Clash/YAML config, a WireGuard file or a
  /// base64 text. A number, an error line or an empty answer is not (the core says "got float64" to those).
  static bool looksLikeProfile(String content) {
    final text = content.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(text)) return true;
    if (text.startsWith('{') || text.startsWith('[')) return true;
    final head = text.length > 4096 ? text.substring(0, 4096) : text;
    if (RegExp(r'^\s*(proxies|outbounds|proxy-providers)\s*:', multiLine: true).hasMatch(head)) return true;
    if (head.contains('"outbounds"') || head.contains('[Interface]')) return true;
    // base64 of a list of links: long, and nothing but the alphabet
    return text.length >= 40 && RegExp(r'^[A-Za-z0-9+/=_\-\s]+$').hasMatch(text);
  }

  /// The shape of [content] for the log, with no keys, addresses or names: its size, what it starts with and how many
  /// share links it holds.
  static String describe(String content) {
    final text = content.trim();
    final links = _links(content).length;
    final scheme = RegExp(r'^([a-z][a-z0-9+.-]*)://', caseSensitive: false).firstMatch(text)?.group(1);
    final String kind;
    if (text.isEmpty) {
      kind = 'empty';
    } else if (scheme != null) {
      kind = 'share links ($scheme://)';
    } else if (text.startsWith('{') || text.startsWith('[')) {
      kind = 'JSON';
    } else if (RegExp(r'^\s*(proxies|mixed-port|port|proxy-groups)\s*:', multiLine: true).hasMatch(text)) {
      kind = 'Clash YAML';
    } else if (text.length <= 12) {
      kind = 'short text "$text"';
    } else {
      kind = 'text starting with "${text.substring(0, 6).replaceAll(RegExp(r'\s'), ' ')}"';
    }
    return '${text.length} chars, $kind, $links links';
  }

  static List<String> _links(String content) {
    var text = content.trim();
    if (text.isEmpty) return const [];
    if (!text.contains('://')) {
      // base64 of the list of links
      try {
        text = utf8.decode(base64.decode(base64.normalize(text.replaceAll(RegExp(r'\s'), ''))));
      } catch (_) {
        return const [];
      }
    }
    return [
      for (final line in text.split(RegExp(r'[\r\n]+')))
        if (RegExp(
          r'^(vless|trojan|ss|hysteria2?|hy2|tuic|wireguard|socks)://',
          caseSensitive: false,
        ).hasMatch(line.trim()))
          line.trim(),
    ];
  }

  static bool _isDecoyLink(String link) {
    final hash = link.indexOf('#');
    var name = hash < 0 ? '' : link.substring(hash + 1);
    try {
      name = Uri.decodeComponent(name);
    } catch (_) {
      /* the name as it is */
    }
    if (_marks.hasMatch(name)) return true;
    final uri = Uri.tryParse(link);
    final host = uri?.host ?? '';
    final port = uri != null && uri.hasPort ? uri.port : 443;
    return host == '0.0.0.0' || host == 'siski.com' || port < 2;
  }
}
