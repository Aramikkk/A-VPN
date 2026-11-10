<p align="center">
  <img src="docs/screenshots/hero.png" alt="A-VPN: VPN-клиент для Android, который следит за качеством связи">
</p>

<h1 align="center">A-VPN</h1>

<p align="center">
  Клиент для Android на ядре sing-box. Подбирает серверы под текущую сеть, переключается между Wi‑Fi и LTE без разрыва и показывает, как работает соединение.
</p>

<p align="center">
  <a href="https://github.com/Aramikkk/A-VPN/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/Aramikkk/A-VPN?label=release"></a>
  <a href="https://github.com/Aramikkk/A-VPN/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/Aramikkk/A-VPN/total?label=downloads"></a>
  <img alt="Platform" src="https://img.shields.io/badge/Android-7%2B%20%C2%B7%20arm64-3ddc84">
  <a href="LICENSE.md"><img alt="License" src="https://img.shields.io/badge/license-Hiddify%20Extended%20GPL%20v3-blue"></a>
</p>

<p align="center">
  <b>Русский</b> · <a href="#english">English</a>
</p>

> A-VPN — независимый форк [Hiddify](https://github.com/hiddify/hiddify-app), выпущенный по условиям его лицензии. Он не связан с командой Hiddify и не одобрен ею.

## Главные фичи

<p align="center">
  <img src="docs/screenshots/why.png" alt="Wi-Fi и LTE без разрыва, свои серверы для каждой сети, устойчивое соединение">
</p>

- **Wi‑Fi и LTE без разрыва.** Вышли из дома или подключились к Wi‑Fi: VPN не отключается и переподключается сам, нажимать ничего не нужно.
- **Свои серверы для каждой сети.** В LTE работают серверы для белых списков, в Wi‑Fi обычные. Страны для каждой сети выбираются отдельно.
- **Устойчивое соединение.** Приложение постоянно измеряет задержку и потери, вовремя меняет сервер, перезапускает ядро при потере связи и проверяет соединение после сна устройства.

## Возможности

<p align="center">
  <img src="docs/screenshots/inside.png" alt="Контроль качества связи, быстрый выбор сервера, отдельный сервер для сервиса, статистика">
</p>

**Серверы**
- Несколько подписок в одном списке. Порядок задаётся перетаскиванием, одну подписку можно сделать приоритетной.
- Автоматический выбор по минимальной задержке с отдельным допуском для Wi‑Fi и мобильной сети.
- Кнопка быстрого выбора: проверяет все серверы и выбирает самый быстрый из доступных по вашим правилам.
- Отдельный сервер для выбранных сервисов и приложений (Instagram, WhatsApp, Telegram, YouTube и других) с измерением задержки до каждого.

**Маршрутизация**
- Режим «только заблокированное через VPN»: остальной трафик идёт напрямую. Список обновляется.
- Раздельное туннелирование по приложениям и доменам, готовые группы для российских сервисов, банков и маркетплейсов.
- Блокировка рекламы, трекеров, фишинговых сайтов и майнеров на уровне VPN.
- Автопауза: VPN приостанавливается, пока на экране приложение из вашего списка (например, Госуслуги или банк), и включается снова.
- Домашний Wi‑Fi: если на роутере уже работает свой VPN, приложение приостанавливается и возвращается вне дома. Сеть определяется по роутеру, доступ к геолокации не нужен.

**Статистика**
- Топология: куда ушёл трафик (VPN, напрямую, заблокировано) и через какие страны.
- Серверы: объём и время по каждому серверу за сессию, сутки, месяц и весь период.
- Задержка и потери с историей, трафик по приложениям.

**Работа в фоне**
- Ночной режим и режим лёгкой работы: реже опросы, меньше пробуждений устройства.
- Уведомление службы не обновляется, пока экран выключен.

## Интерфейс

<p align="center">
  <img src="docs/screenshots/looks.png" alt="Два стиля интерфейса, светлая и тёмная версии">
</p>

<p align="center">
  <img src="docs/screenshots/screens.png" alt="Выбор сервера, трафик, качество связи, настройки">
</p>

Два стиля на выбор (минимализм и плитки; есть также стеклянный и контрастный), светлая и тёмная версии, масштаб интерфейса и шрифта.

<sub>На картинках экраны статистики и топологии дополнены примерными данными, остальное снято в приложении.</sub>

## Установка

1. Скачайте `A-VPN-<версия>-arm64.apk` из [последнего релиза](https://github.com/Aramikkk/A-VPN/releases/latest).
2. Проверьте контрольную сумму. Рядом лежит файл `*.apk.sha256`:
   ```bash
   sha256sum -c A-VPN-<версия>-arm64.apk.sha256
   ```
3. Установите APK (Android запросит разрешение на установку из этого источника) и добавьте подписку: «Профили» → «+».

**Подпись.** Все релизы подписаны одним ключом. SHA‑256 сертификата:

```
95:CC:05:9F:8E:1A:E2:E0:B8:59:43:66:6E:C4:5D:D3:2D:66:F8:1E:80:7B:3F:6E:7A:D6:CD:75:BE:A6:B1:9A
```

Проверить: `apksigner verify --print-certs A-VPN-<версия>-arm64.apk`. Если отпечаток другой, это не наша сборка.

**Архитектура.** Только 64-битный ARM (`arm64-v8a`), то есть подавляющее большинство устройств последних лет. Сборок для 32-битного ARM и x86 нет.

**Обновления.** Приложение раз в сутки запрашивает `latest.json` в последнем релизе этого репозитория, показывает уведомление о новой версии и устанавливает её после вашего подтверждения.

## Приватность и разрешения

| Разрешение | Назначение |
|---|---|
| `INTERNET`, `BIND_VPN_SERVICE`, `FOREGROUND_SERVICE*` | работа VPN |
| `QUERY_ALL_PACKAGES` | список приложений для раздельного туннелирования и статистики по приложениям |
| `PACKAGE_USAGE_STATS` | определение приложения на экране для автопаузы (по желанию) |
| `REQUEST_INSTALL_PACKAGES` | установка обновления после вашего подтверждения |
| `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | запуск после перезагрузки, работа в фоне |
| `POST_NOTIFICATIONS` | уведомление службы со скоростью и сервером |
| `CAMERA` | сканирование QR-кода подписки |

- Телеметрии и аналитики в сборках нет: ключ отправки отчётов не задан.
- Приложение само обращается только к github.com: раз в сутки за `latest.json`. GitHub видит IP-адрес, как при открытии любого сайта; идентификаторов приложение не добавляет.
- Запросы подписки уходят вашему провайдеру. Если его панель ограничивает число устройств, передаётся случайный идентификатор установки, созданный при первом запуске.
- Подписки, списки приложений и статистика хранятся только на устройстве.
- Управление ядром идёт через локальный gRPC (`127.0.0.1`) с секретом, уникальным для каждой установки. Другие приложения к ядру подключиться не могут.
- Журналы очищаются от ссылок подписок, ключей, паролей и UUID.
- Обновление проверяется по SHA‑256 из того же релиза.

## Вопросы и обратная связь

- **Вопрос или помощь с настройкой:** [Обсуждения](https://github.com/Aramikkk/A-VPN/discussions).
- **Ошибка:** [новое обращение](https://github.com/Aramikkk/A-VPN/issues/new/choose). Укажите версию приложения (в «О программе»), устройство и приложите журнал: «Настройки» → «Логи». Не публикуйте ссылку на подписку.
- **Предложение:** тоже в [обращениях](https://github.com/Aramikkk/A-VPN/issues/new/choose).
- **Проблема безопасности:** [приватное сообщение](https://github.com/Aramikkk/A-VPN/security/advisories/new), не в открытом обращении.

## Отличия от Hiddify

Полный список по версиям: [`avpn/CHANGELOG.md`](avpn/CHANGELOG.md). Основное:

- собственный интерфейс и главный экран с задержкой, потерями, сайтами и текущим сервером;
- страницы статистики «Топология» и «Серверы», история потерь и задержки;
- выбор серверов по сети, приоритетная подписка, отдельные серверы для сервисов;
- маршрутизация «только заблокированное», группы российских сервисов, блокировка рекламы;
- изменения ядра ([`avpn/core54-patches`](avpn/core54-patches)) поверх `hiddify-core` 5.4.0 и `hiddify-sing-box`: горячая перезагрузка при смене сети, статистика трафика, группы сайтов;
- работа в фоне: ночной режим, проверка связи после сна, перезапуск ядра при необходимости;
- обновления из GitHub Releases;
- настройки под провайдера Sigma Gate (название «Sigma» вместо «Доступ», запрос подписки как Clash Meta) вынесены в отдельный переключатель в «Общие» и по умолчанию выключены.

## Сборка

Релизы собирает только GitHub Actions ([`.github/workflows/release.yml`](.github/workflows/release.yml)): ядро с патчами, затем подписанный APK. Нужны секреты репозитория `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

Локально понадобятся Flutter 3.38.5, JDK 17, Android SDK с NDK 28, Go (версия из `go.mod` ядра) и `gomobile`. Шаги те же, что в workflow. Проверка кода:

```bash
flutter pub get
dart run slang
dart run build_runner build --delete-conflicting-outputs
flutter test
```

Подробнее о ядре: [`avpn/core54-patches/README.md`](avpn/core54-patches/README.md).

## Лицензия

Проект распространяется по **Hiddify Extended GNU GPL v3** ([`LICENSE.md`](LICENSE.md)): GPL v3 с дополнительными условиями Hiddify. В частности: исходный код опубликован как форк Hiddify, релизы собираются в GitHub Actions, указана атрибуция Hiddify, приложение не публикуется в магазинах приложений, коммерческое использование без письменного разрешения запрещено, производные работы распространяются на тех же условиях. Полные условия приведены в `LICENSE.md` и обязательны.

Благодарности: команде [Hiddify](https://github.com/hiddify), проекту [sing-box](https://github.com/SagerNet/sing-box) и авторам библиотек, на которых построено приложение.

## Поддержать проект

Проект бесплатный. Если приложение оказалось полезным, реквизиты для добровольной поддержки есть в «О программе» → «Поблагодарить разработчика». Это ни на что не влияет.

---

## English

**A-VPN** is an Android VPN client built on the sing-box core. It picks servers for the network you are on, switches between Wi‑Fi and LTE without dropping the tunnel, and shows how the connection performs. It is an independent fork of [Hiddify](https://github.com/hiddify/hiddify-app) released under its license and is not affiliated with the Hiddify team.

- **Wi‑Fi and LTE without a break.** Servers and settings follow the network; the VPN stays on.
- **Servers per network.** Whitelist-friendly servers on mobile data, regular ones on Wi‑Fi; countries are set per network.
- **Steady connection.** Latency and loss are measured all the time, the server is switched in good time, the core restarts if the link is lost, and the connection is checked after the device wakes up.
- Per-service servers, blocked-only routing, per-app split tunnelling, ad/tracker/phishing blocking, per-server traffic statistics.
- No telemetry. Updates come only from this repository's releases and are verified by SHA‑256.

**Install:** download `A-VPN-<version>-arm64.apk` from the [latest release](https://github.com/Aramikkk/A-VPN/releases/latest) and verify it with the `.sha256` file and the certificate fingerprint above. Android 7+, 64-bit ARM only. Source, build workflow and the core patches are in this repository.
