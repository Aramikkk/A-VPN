/// The finer groups on the routing page: app stores, YouTube and Twitch, foreign apps through the VPN; Yandex,
/// marketplaces and banks direct. Each takes its apps (and the sites they need) out of the broader groups after
/// it; the Russian ones stay in the Russian apps too, so they still go direct with their group switched off.

/// App stores: through the VPN (Play's downloads and its region need it). RuStore is Russian and stays direct
/// with the Russian apps.
const storeApps = [
  'com.android.vending', // Google Play
  'com.sec.android.app.samsungapps', // Galaxy Store
  'org.fdroid.fdroid',
  'com.aurora.store',
  'com.apkpure.installer',
  'com.apkpure.aegon',
  'taco.apkmirror',
  'dev.imranr.obtainium',
  'com.aefyr.sai',
  'com.aefyr.sai.fdroid',
];
const storeDomains = [
  'apkmirror.com',
  'apkpure.com',
  'apkpure.net',
  'f-droid.org',
  'galaxystore.samsung.com',
  'play-fe.googleapis.com',
  'play-lh.googleusercontent.com',
  'play.google.com',
  'play.googleapis.com',
  'samsungapps.com',
];

/// YouTube and Twitch: the apps and their video servers.
const videoApps = [
  'com.google.android.youtube',
  'com.google.android.apps.youtube.music',
  'com.google.android.apps.youtube.kids',
  'com.google.android.youtube.tv',
  'com.google.android.videos',
  'tv.twitch.android.app',
];
const videoSites = [
  'ext-twitch.tv',
  'googlevideo.com',
  'jtvnw.net',
  'live-video.net',
  'returnyoutubedislikeapi.com',
  'ttvnw.net',
  'twitch.a2z.com',
  'twitch.tv',
  'twitchcdn.net',
  'twitchsvc.net',
  'youtu.be',
  'youtube-nocookie.com',
  'youtube.com',
  'youtubei.googleapis.com',
  'youtubekids.com',
  'yt.be',
  'ytimg.com',
  'yting.com',
];

/// Foreign apps that need a foreign address (the rest of what isn't Russian goes by the "everything else" switch):
/// office, games, cars, routers, exchanges. Browsers aren't here: they open Russian sites too.
const foreignApps = [
  'com.microsoft.office.excel',
  'com.microsoft.office.outlook',
  'com.microsoft.office.powerpoint',
  'com.microsoft.office.word',
  'com.microsoft.office.officehubrow',
  'com.microsoft.teams',
  'com.microsoft.rdc.androidx',
  'com.azure.authenticator',
  'com.pinterest',
  'com.playstation.remoteplay',
  'com.scee.psxandroid',
  'com.valvesoftware.android.steam.community',
  'com.valvesoftware.android.steam.friendsui',
  'com.tripadvisor.tripadvisor',
  'com.devhd.feedly',
  'com.cron.calendar', // Notion Calendar
  'com.iternio.abrpapp', // A Better Routeplanner
  'com.tplink.tether',
  'com.tplink.tpm5',
  'com.mikrotik.android.tikapp',
  'com.carriez.flutter_hbb', // RustDesk
  'gg.op.lol.android',
  'com.vectorunit.cobalt.googleplay',
  'upgames.pokerup.android',
  'com.bybit.app',
  'com.roboforex.webtrader',
  'com.dropbox.android',
  'com.zoom.videomeetings',
  'us.zoom.videomeetings',
  'com.amazon.mShop.android.shopping',
  'com.ebay.mobile',
];

/// Yandex's apps and sites: direct (its servers sit in Russia; abroad Music plays fewer tracks). Yandex Browser
/// isn't here: it opens foreign and blocked sites too.
const yandexApps = [
  'com.yandex.aliceapp',
  'com.yandex.alice',
  'com.yandex.searchapp',
  'com.yandex.iot',
  'com.yandex.internetometer',
  'com.yandex.lavka',
  'com.yandex.mobile.drive',
  'com.yandex.mobile.realty',
  'com.yandex.mobile.auto',
  'com.yandex.travel.app',
  'com.yandex.plus.home',
  'ru.yandex.androidkeyboard',
  'ru.yandex.disk',
  'ru.yandex.eda',
  'ru.yandex.key',
  'ru.yandex.lavka',
  'ru.yandex.mail',
  'ru.yandex.messenger',
  'ru.yandex.mobile.gasstations',
  'ru.yandex.music',
  'ru.yandex.searchplugin',
  'ru.yandex.taxi',
  'ru.yandex.taximeter',
  'ru.yandex.telemost',
  'ru.yandex.translate',
  'ru.yandex.travel',
  'ru.yandex.uber',
  'ru.yandex.weatherplugin',
  'ru.yandex.yandexmaps',
  'ru.yandex.yandexnavi',
  'ru.yandex.zen',
  'ru.foodfox.client', // Яндекс Еда
  'ru.kinopoisk',
  'ru.kinopoisk.tv',
  'ru.plus.bookmate',
];
const yandexDomains = [
  'kinopoisk.ru',
  'ya.ru',
  'yandex',
  'yandex.by',
  'yandex.com',
  'yandex.kz',
  'yandex.net',
  'yandex.ru',
  'yandexcloud.net',
  'yastatic.net',
];

/// Russian marketplaces, shops and delivery: direct.
const marketApps = [
  'ru.ozon.app.android',
  'travel.ozon.mobile',
  'com.wildberries.ru',
  'com.avito.android',
  'com.allgoritm.youla',
  'ru.beru.android', // Яндекс Маркет
  'ru.yandex.market',
  'ru.megamarket.marketplace',
  'ru.sbermegamarket.app',
  'com.kazanexpress.ke_app', // Магнит Маркет
  'ru.lamoda',
  'ru.citilink',
  'ru.dns.shop.android',
  'ru.mvideo.mobile',
  'ru.eldorado.app',
  'ru.detmir.dmbonus',
  'ru.apteka',
  'ru.instamart',
  'ru.samokat.mobile',
  'ru.vkusvill',
  'ru.perekrestok.app',
  'ru.x5.pyaterochka',
  'ru.x5.omni',
  'ru.magnit.express.android',
  'ru.lenta.lentochka',
  'com.icemobile.lenta.prod',
  'ru.myspar',
  'ru.auchan.android',
  'ru.napoleonit.kb', // Красное&Белое
  'com.deliveryclub',
  'ru.delivery.club',
];
const marketDomains = [
  'avito.ru',
  'avito.st',
  'citilink.ru',
  'detmir.ru',
  'dns-shop.ru',
  'lamoda.ru',
  'megamarket.ru',
  'mvideo.ru',
  'ozon.ru',
  'ozone.ru',
  'ozonusercontent.com',
  'wb.ru',
  'wbbasket.ru',
  'wbstatic.net',
  'wildberries.ru',
];

/// Russian banks and payments: direct (many refuse foreign addresses).
const bankApps = [
  'ru.sberbankmobile',
  'ru.sberbank.sberbankid',
  'ru.sberbank.spasibo',
  'ru.sberbank_sbbol',
  'ru.sberins.insureapp.android',
  'com.idamob.tinkoff.android',
  'ru.tinkoff.investing',
  'ru.tinkoff.sme',
  'ru.alfabank.mobile.android',
  'ru.vtb24.mobilebanking.android',
  'ru.vtb.smb',
  'ru.gazprombank.android.mobilebank.app',
  'ru.raiffeisennews',
  'ru.psbank.online',
  'ru.rosbank.android',
  'ru.mkb.mobile',
  'ru.openbank.mobile',
  'ru.sovcombank.halvacard',
  'ru.pochtabank.android',
  'ru.nspk.mirpay',
  'ru.nspk.sbp.pay',
  'ru.ozon.fintech.finance',
  'com.wildberries.bank',
  'com.yandex.bank',
  'ru.yandex.bank',
  'ru.mw', // QIWI
  'ru.cardsmobile.mw3', // Кошелёк
];
const bankDomains = [
  'alfabank.ru',
  'cdn-tinkoff.ru',
  'gazprombank.ru',
  'nspk.ru',
  'qiwi.com',
  'sber.ru',
  'sberbank.com',
  'sberbank.ru',
  'tbank-online.com',
  'tbank.ru',
  'tinkoff.ru',
  'vtb.ru',
];
