import 'dart:convert';

/// A provider that doesn't know the client answers with decoys in place of servers: "App not supported", "Download
/// Happ" at an address that leads nowhere. Told from the subscription's text, so another client name can be tried.
abstract class SubscriptionDecoy {
  /// The names a decoy server carries.
  static final _marks = RegExp(
    r'не\s+поддерживается|не\s+поддерживается|скачайте|установите\s+приложение|not\s+supported|unsupported|'
    r'download\s+(the\s+)?(happ|app)|use\s+happ|please\s+use|обновите\s+приложение',
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
