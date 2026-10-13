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

/// Chinese sites: the .cn zone and the big Chinese services; from Russia many of them are slow or refuse to
/// work without the VPN.
const _chinaSites = [
  'cn',
  'baidu.com',
  'bdstatic.com',
  'bdimg.com',
  'qq.com',
  'gtimg.com',
  'tencent.com',
  'tencent-cloud.com',
  'myqcloud.com',
  'wechat.com',
  'weixin.com',
  'alibaba.com',
  'alibabacloud.com',
  'alicdn.com',
  'aliyun.com',
  'aliyuncs.com',
  'alipay.com',
  'alipayobjects.com',
  'taobao.com',
  'tmall.com',
  '1688.com',
  'aliexpress.com',
  'aliexpress-media.com',
  'jd.com',
  '360buyimg.com',
  'pinduoduo.com',
  'temu.com',
  'kwcdn.com',
  'shein.com',
  'ltwebstatic.com',
  'bilibili.com',
  'bilibili.tv',
  'biliapi.net',
  'hdslb.com',
  'weibo.com',
  'sina.com',
  'douyin.com',
  'douyinpic.com',
  'douyinvod.com',
  'bytedance.com',
  'xiaohongshu.com',
  'xhscdn.com',
  'rednote.com',
  'kuaishou.com',
  'zhihu.com',
  'zhimg.com',
  '163.com',
  '126.net',
  'netease.com',
  'iqiyi.com',
  'iq.com',
  'youku.com',
  'sohu.com',
  'csdn.net',
  'meituan.com',
  'didiglobal.com',
  'ctrip.com',
  'trip.com',
];

/// Adult sites (18+): always through the VPN, and never shown in the statistics, Connections or Topology.
/// Matched by name, not by fragments, which hit unrelated sites (Netflix's nflxvideo.net has "xvideo" in it).
const _adultSites = [
  'babepedia.com',
  'beeg.com',
  'bongacams.com',
  'brazzers.com',
  'cam4.com',
  'camsoda.com',
  'chaturbate.com',
  'coomer.su',
  'danbooru.donmai.us',
  'e-hentai.org',
  'e621.net',
  'eporner.com',
  'erome.com',
  'exhentai.org',
  'f95-zone.to',
  'f95zone.to',
  'fansly.com',
  'fapello.com',
  'freeones.com',
  'gelbooru.com',
  'hclips.com',
  'hentai-foundry.com',
  'hitomi.la',
  'hqporner.com',
  'imagefap.com',
  'ixxx.com',
  'kemono.su',
  'literotica.com',
  'livejasmin.com',
  'manyvids.com',
  'mmcdn.com',
  'motherless.com',
  'multporn.net',
  'nhentai.com',
  'nhentai.net',
  'nude-moon.org',
  'onlyfans.com',
  'phncdn.com',
  'playboy.com',
  'porn.com',
  'pornhub.com',
  'pornhub.org',
  'pornolab.net',
  'porntrex.com',
  'realbooru.com',
  'reddxxx.com',
  'redgifs.com',
  'redtube.com',
  'rule34.art',
  'rule34.us',
  'rule34.xxx',
  'sex.com',
  'spankbang.com',
  'stripchat.com',
  'sunporno.com',
  'theporndude.com',
  'thumbzilla.com',
  'tnaflix.com',
  'tube8.com',
  'txxx.com',
  'vipergirls.to',
  'xhamster.com',
  'xhamsterlive.com',
  'xhcdn.com',
  'xnxx-cdn.com',
  'xnxx-ru.com',
  'xnxx.com',
  'xnxx.net',
  'xnxx.tv',
  'xnxx3.com',
  'xvideos-cdn.com',
  'xvideos.com',
  'youjizz.com',
  'youporn.com',
];

/// Words that mark an adult site safely enough, for the routing rule.
const adultKeywords = ['porn', 'hentai', 'xxx'];

/// Whether [host] is an adult site, so the statistics leave it out.
bool isAdultHost(String host) {
  final h = host.toLowerCase();
  return _adultSites.any((site) => _under(h, site)) || adultKeywords.any(h.contains);
}

/// AnyDesk: its remote sessions get cut from Russia without the VPN.
const _anydeskSites = ['anydesk.com', 'anydesk.net', 'net.anydesk.com'];

/// Whether [domain] is [site] or under it.
bool _under(String domain, String site) => domain == site || domain.endsWith('.$site');

bool _isAi(String domain) =>
    _aiSites.any((site) => _under(domain, site)) || domain.contains('openai') || domain.contains('anthropic');
bool _isGoogle(String domain) => _googleSites.any((site) => _under(domain, site)) || domain.contains('youtube');
bool _isChina(String domain) => _chinaSites.any((site) => _under(domain, site));
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

/// The social networks' and messengers' apps on the phone.
const socialApps = [
  'com.instagram.android',
  'com.instagram.barcelona', // Threads
  'com.facebook.katana',
  'com.facebook.orca', // Messenger
  'com.facebook.lite',
  'com.whatsapp',
  'com.whatsapp.w4b',
  'org.telegram.messenger',
  'org.telegram.messenger.web',
  'org.thunderdog.challegram', // Telegram X
  'com.twitter.android',
  'com.discord',
  'com.zhiliaoapp.musically', // TikTok
  'com.ss.android.ugc.trill',
  'com.snapchat.android',
  'com.linkedin.android',
  'org.thoughtcrime.securesms', // Signal
  'com.viber.voip',
  // Meta's services preinstalled on the phone: they reach the same blocked servers
  'com.facebook.appmanager',
  'com.facebook.services',
  'com.facebook.system',
];

final adultDomains = _sorted([..._adultSites, ...blockedDomains.where(isAdultHost)]);

final chinaDomains = _sorted([
  ..._chinaSites,
  ...blockedDomains.where((d) => !_isAi(d) && !_isGoogle(d) && !_isSocial(d) && _isChina(d)),
]);

/// Everything else blocked in Russia, the .ru sites in the registry and AnyDesk among it.
final otherBlockedDomains = _sorted([
  ...blockedDomains.where((d) => !_isAi(d) && !_isGoogle(d) && !_isSocial(d) && !_isChina(d) && !isAdultHost(d)),
  ...rknRuDomains.where((d) => !isAdultHost(d)),
  ..._anydeskSites,
]);

/// AnyDesk on the phone and on the computer.
const otherBlockedApps = [
  'com.anydesk.anydeskandroid',
  'com.anydesk.adcontrol.ad1',
  'com.adobe.lrmobile', // Lightroom
  'com.adobe.psmobile', // Photoshop Express
  'com.adobe.scan.android',
  'com.adobe.reader',
  'notion.id',
  'com.soundcloud.android',
  'tv.twitch.android.app',
  'com.roblox.client',
  'com.spotify.music',
  'com.netflix.mediaclient',
  'com.lemon.lvoverseas', // CapCut
  'ru.fourpda.client', // 4PDA, blocked though Russian
  'llc.itdev.incy',
  'com.teslamotors.tesla', // Tesla's servers refuse Russian addresses
  'io.tessie.app',
];
const otherBlockedProcesses = ['AnyDesk.exe', 'anydesk.exe'];

/// The Chinese apps on the phone.
const chinaApps = [
  'com.tencent.mm', // WeChat
  'com.tencent.mobileqq',
  'com.tencent.wework',
  'com.alibaba.aliexpresshd',
  'com.alibaba.intl.android.apps.poseidon', // Alibaba.com
  'com.taobao.taobao',
  'com.tmall.wireless',
  'com.eg.android.AlipayGphone',
  'com.jingdong.app.mall',
  'com.xunmeng.pinduoduo',
  'com.einnovation.temu',
  'com.zzkko', // SHEIN
  'tv.danmaku.bili', // bilibili
  'com.sina.weibo',
  'com.ss.android.ugc.aweme', // Douyin
  'com.xingin.xhs', // Xiaohongshu (RedNote)
  'com.smile.gifmaker', // Kuaishou
  'com.zhihu.android',
  'com.baidu.searchbox',
  'com.netease.cloudmusic',
  'com.qiyi.video',
  'com.youku.phone',
  'ctrip.english', // Trip.com
  'com.alibaba.wireless', // 1688
  'com.byd.bydautolink',
  'com.midea.ai.overseas',
  'com.roborock.smart',
  'com.xiaomi.smarthome', // Mi Home
  'com.cmlink.esim',
  'com.multibyte.esender.jiedian',
];

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
  'ai.mainfunc.genspark',
  'com.rokid.sprite.global.aiapp',
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
