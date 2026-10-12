import 'package:hiddify/features/route_rules/notifier/blocked_list.dart';
import 'package:hiddify/features/route_rules/notifier/rkn_ru_domains.dart';

/// The groups of sites and apps that always go through the VPN, as the routing page shows them: AI, Google and
/// YouTube, social networks and messengers, and the rest of what is blocked in Russia. Each blocked domain is in
/// exactly one group, the first one it fits. Alice (Yandex) is in none on purpose: it is Russian and goes direct
/// with the rest of Yandex.

/// AI services: they refuse Russian addresses even where they aren't blocked.
const _aiSites = [
  'openai.com',
  'chatgpt.com',
  'chat.com',
  'ai.com',
  'oaistatic.com',
  'oaiusercontent.com',
  'sora.com',
  'anthropic.com',
  'claude.ai',
  'claude.com',
  'claudeusercontent.com',
  'gemini.google.com',
  'aistudio.google.com',
  'notebooklm.google.com',
  'perplexity.ai',
  'pplx.ai',
  'x.ai',
  'grok.com',
  'grok.x.com',
  'mistral.ai',
  'cohere.com',
  'cohere.ai',
  'huggingface.co',
  'hf.co',
  'midjourney.com',
  'poe.com',
  'character.ai',
  'chub.ai',
  'deepseek.com',
  'meta.ai',
  'copilot.microsoft.com',
  'designer.microsoft.com',
  'sydney.bing.com',
  'githubcopilot.com',
  'cursor.com',
  'cursor.sh',
  'cursorapi.com',
  'cursor-cdn.com',
  'codeium.com',
  'windsurf.com',
  'augmentcode.com',
  'api.jetbrains.ai',
  'data.cline.bot',
  'kilo.ai',
  'kilocode.ai',
  'qoder.com',
  'trae.ai',
  'genspark.ai',
  'manus.im',
  'hume.ai',
  'langdock.com',
  'elevenlabs.io',
  'runwayml.com',
  'suno.com',
  'suno.ai',
  'stability.ai',
  'leonardo.ai',
  'ideogram.ai',
  'recraft.ai',
  'reve.art',
  'sonara.ai',
  'blinkshot.io',
  'groq.com',
  'together.ai',
  'replicate.com',
  'openrouter.ai',
  'qwen.ai',
  'kimi.com',
  'moonshot.ai',
  'giga.chat',
  'gigachat.ru',
];

/// Google, the Play Store and YouTube.
const _googleSites = [
  'google', // the .google zone: gemini.google, deepmind.google, notebooklm.google…
  'google.com',
  'google.ru',
  'googleapis.com',
  'gstatic.com',
  'googleusercontent.com',
  'ggpht.com',
  'googlevideo.com',
  'gvt1.com',
  'gvt2.com',
  'gvt3.com',
  'youtube.com',
  'youtu.be',
  'yt.be',
  'ytimg.com',
  'yting.com',
  'youtube-nocookie.com',
  'youtubekids.com',
  'returnyoutubedislikeapi.com',
  'android.com',
  'withgoogle.com',
  'goo.gl',
  'g.co',
  'gmail.com',
  'googlemail.com',
  'firebaseio.com',
  'firebaseapp.com',
  'recaptcha.net',
  'blogger.com',
  'blogspot.com',
  'google.dev',
  'deepmind.com',
];

/// Social networks and messengers; a blocked domain holding one of [_socialWords] is one too.
const _socialSites = [
  'instagram.com',
  'cdninstagram.com',
  'ig.me',
  'facebook.com',
  'facebook.net',
  'fb.com',
  'fbcdn.net',
  'fbsbx.com',
  'meta.com',
  'internalfb.com',
  'oculus.com',
  'threads.com',
  'threads.net',
  'whatsapp.com',
  'whatsapp.net',
  'whatsapp.biz',
  'wa.me',
  't.me',
  'tdesktop.com',
  'telegra.ph',
  'telesco.pe',
  'dis.gd',
  'guilded.gg',
  'x.com',
  't.co',
  'twimg.com',
  'twttr.com',
  'twttr.net',
  'twtrdns.net',
  'twvid.com',
  'tweetdeck.com',
  'periscope.tv',
  'pscp.tv',
  'vine.co',
  'tellapart.com',
  'cms-twdigitalassets.com',
  'musical.ly',
  'ibytedtos.com',
  'byteoversea.com',
  'ttwstatic.com',
  'muscdn.com',
  'linkedin.com',
  'licdn.com',
  'signal.org',
  'viber.com',
  'simplex.chat',
  'simplex.im',
  'threema.ch',
  'truthsocial.com',
  'snapchat.com',
  'snap.com',
  'sc-cdn.net',
  'snapkit.com',
  'sc-static.net',
];
const _socialWords = ['telegram', 'discord', 'twitter', 'tiktok'];

/// Whether [domain] is [site] or under it.
bool _under(String domain, String site) => domain == site || domain.endsWith('.$site');

bool _isAi(String domain) =>
    _aiSites.any((site) => _under(domain, site)) || domain.contains('openai') || domain.contains('anthropic');
bool _isGoogle(String domain) => _googleSites.any((site) => _under(domain, site)) || domain.contains('youtube');
bool _isSocial(String domain) =>
    _socialSites.any((site) => _under(domain, site)) || _socialWords.any((word) => domain.contains(word));

/// Sorted and without repeats; the first one is how the connections list recognises the group (see `ruleLabel`).
List<String> _sorted(Iterable<String> domains) => domains.toSet().toList()..sort();

final aiDomains = _sorted([..._aiSites, ...blockedDomains.where(_isAi)]);
final googleDomains = _sorted([..._googleSites, ...blockedDomains.where((d) => !_isAi(d) && _isGoogle(d))]);
final socialDomains = _sorted([
  ..._socialSites,
  ...blockedDomains.where((d) => !_isAi(d) && !_isGoogle(d) && _isSocial(d)),
]);

/// The social networks' addresses: their apps often connect by IP.
const socialCidrs = blockedCidrs;

/// Everything else blocked in Russia, the .ru sites in the registry among it.
final otherBlockedDomains = _sorted([
  ...blockedDomains.where((d) => !_isAi(d) && !_isGoogle(d) && !_isSocial(d)),
  ...rknRuDomains,
]);

/// The AI apps on the phone: all their traffic through the VPN, whatever servers they use.
const aiApps = [
  'com.openai.chatgpt',
  'com.anthropic.claude',
  'com.google.android.apps.bard', // Gemini
  'com.google.android.apps.labs.language.tailwind', // NotebookLM
  'ai.perplexity.app.android',
  'ai.x.grok',
  'com.microsoft.copilot',
  'com.deepseek.chat',
  'ai.character.app',
  'com.quora.poe',
];

/// Google's apps on the phone. The list is for the normal mode; "only blocked through the VPN" takes every
/// `com.google.*` app by [googleAppPatterns].
const googleApps = [
  'com.google.android.gms',
  'com.google.android.gsf',
  'com.android.vending',
  'com.google.android.youtube',
  'com.google.android.apps.youtube.music',
  'com.google.android.apps.youtube.kids',
  'com.google.android.googlequicksearchbox',
  'com.google.android.gm',
  'com.google.android.apps.docs',
  'com.google.android.apps.photos',
  'com.google.android.apps.translate',
  'com.google.android.keep',
  'com.google.android.calendar',
  'com.google.android.apps.maps',
  'com.google.android.apps.nbu.files',
  'com.google.android.apps.messaging',
  'com.google.android.apps.walletnfcrel',
  'com.google.ar.lens',
  'com.google.android.apps.tachyon',
  'com.google.android.apps.subscriptions.red',
  'com.google.android.play.games',
];
const googleAppPatterns = [r'^com\.google\.'];
