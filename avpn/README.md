# A-VPN — сборка и сопровождение

A-VPN — личный форк Hiddify v5 под провайдера **Sigma Gate** (панель Remnawave, gate.accessgate.link).
Android (`com.aravpn.app`) и Windows 11.

## Где что лежит

| Путь | Что это |
|---|---|
| `.\hiddify` | Приложение (Flutter). Ветка **`aravpn`** |
| `.\tools\hcore-build` | Ядро hiddify-core v5 с патчами A-VPN. Ветка **`aravpn`** (и в подмодуле `hiddify-sing-box` тоже `aravpn`) |
| `.\tools\flutter`, `go`, `jdk-17…`, `llvm-mingw`, `innosetup` | Инструменты сборки |
| `.\tools\core-backup\hiddify-core-5.0.0-official.aar` | Официальное ядро (откат на крайний случай) |
| `.\A-VPN` | Готовые сборки: `A-VPN-5.0.0-arm64.apk`, `-armv7.apk`, `windows\A-VPN-Setup-5.0.0.exe`, `share\A-VPN.apk` (для ссылки на телефон) |
| `aravpn\scripts\` (в этом репо) | Копии скриптов сборки: `env.sh`, `build-core.sh`, `build-core-windows.sh`, `make_icon.py`, `gen_rkn_domains.py` |

Все команды — в Git Bash.

## 1. Ядро (нужно только после правок в `hcore-build`)

```bash
bash ./tools/build-core.sh            # Android → hcore-build/bin/hiddify-core.aar
bash ./tools/build-core-windows.sh    # Windows → hcore-build/bin/windows/{hiddify-core.dll,HiddifyCli.exe}
cp ./tools/hcore-build/bin/hiddify-core.aar ./hiddify/android/app/libs/hiddify-core.aar
cp ./tools/hcore-build/bin/windows/{hiddify-core.dll,HiddifyCli.exe} ./hiddify/hiddify-core/bin/
```

Тесты ядра (тест `TestPanelURIsConvert` падает и без наших правок — в сборке нет naive):

```bash
export PATH="./tools/go/bin:$PATH" GOPATH="./tools/gopath" GOMODCACHE="./tools/gopath/pkg/mod" GOCACHE="./tools/gocache" GOTOOLCHAIN=local GOFLAGS=-mod=mod
cd ./tools/hcore-build && go test -tags=with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,tfogo_checklinkname0 -ldflags=-checklinkname=0 ./v2/config/ ./v2/hcore/ ./hiddify-sing-box/protocol/group/balancer/
```

## 2. Android

```bash
. ./tools/env.sh && cd ./hiddify
dart run slang                                         # после правок в assets/translations/*.i18n.json
dart run build_runner build --delete-conflicting-outputs   # после правок моделей/провайдеров
flutter analyze --no-pub lib && flutter test --no-pub
flutter build apk --release --target lib/main_prod.dart --split-per-abi --target-platform android-arm,android-arm64 --no-pub
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ./A-VPN/share/A-VPN.apk
```

Ссылка для телефона (в домашнем Wi-Fi): `python -m http.server 8765 --bind 192.168.0.10 --directory ./A-VPN/share`
→ `http://192.168.0.10:8765/A-VPN.apk`. Проверять curl'ом с `--noproxy '*'` (в окружении стоит HTTP_PROXY).

## 3. Windows

```bash
. ./tools/env.sh && cd ./hiddify
flutter build windows --release --target lib/main_prod.dart --no-pub
cd windows/packaging/aravpn && ./tools/innosetup/ISCC.exe //Q avpn.iss
cp ./hiddify/build/windows/installer/A-VPN-Setup-5.0.0.exe ./A-VPN/windows/
```

Нужны Visual Studio 2022 Build Tools («Разработка классических приложений на C++»).
Если `pub get` не может скачать пакеты (прокси), работать с `--no-pub` / `flutter pub get --offline`.

## Что изменено относительно Hiddify

**Подписка и сервера**
- `lib/core/http_client/device_headers.dart` — заголовки `x-hwid`, `x-device-os`, `x-device-model`; UA `clash.meta` (без HWID панель отдаёт заглушки, с UA Hiddify — фальшивые БС-сервера).
- `lib/features/profile/data/clash_to_links.dart` — Clash YAML → vless/trojan/hy2 ссылки, **до** `expandRemoteLinesInParallel` (иначе YAML ломается).
- `lib/features/proxy/data/server_region_filter.dart` — только Европа; Wi-Fi → «Доступ», мобильная сеть → «LTE Only»/БС; на ПК всегда Wi-Fi.
- `android/.../NetworkTypeHandler.kt` + `active_proxy_notifier.dart` — надёжное определение сети и переключение.
- Имена «Доступ» показываются как **Sigma** (`sigmaName()` в `avpn_home_body.dart`).

**Маршрутизация** — `lib/features/route_rules/notifier/rules_notifier.dart`: РКН-домены (.ru/.su/.рф из antifilter, `gen_rkn_domains.py`) через прокси, остальные .ru/.su/.рф и LAN напрямую, QUIC заблокирован. DNS: удалённый `https://8.8.8.8/dns-query`, прямой `udp://77.88.8.8` (DoH Яндекса не работает).

**Режим «Сервер»** — `lib/features/proxy/data/home_network.dart`: WireGuard-профиль (Mechta.conf) как отдельный режим: домашняя сеть через WG, остальное напрямую.

**Раздача** — `lan_sharing.dart`: прокси на порту 12334 для устройств в точке доступа.

**Интерфейс** — `lib/features/home/widget/avpn_home_body.dart` (главная в стиле INCY), `lib/features/stats/widget/side_bar_stats_overview.dart` (статистика: сайдбар на ПК, вкладка «Статистика» (телефон и ПК) с графиком скорости, пингом/потерями — `connection_quality.dart`, замер через локальный прокси раз в 2 с, — и активными соединениями), `lib/core/theme/` (темы: `ara_accent.dart` — A-VPN/Windows 11/Аврора/Закат/Лагуна/Неон; на ПК шрифт Segoe UI Variable). Иконки — `avpn/scripts/make_icon.py`.

**Автозапуск**
- Android: `bg/BootReceiver.kt` + «Автоподключение» при запуске приложения.
- Windows: задача Планировщика `A-VPN` (`windows/packaging/avpn/autostart.ps1`): при входе, с наивысшими правами, `A-VPN.exe --autostart` → в трей и подключение (`lib/core/app_info/launch_args.dart`).

**Патчи ядра (hcore-build, ветка aravpn)**
1. `v2/config/builder.go` — `prependInputRouteRules`: правила из профиля идут сразу после sniff/hijack-dns (нужно для режима «Сервер»).
2. `url-test-timeout` — таймаут пинга из настроек.
3. `v2/hcore/vpn_traffic.go` — трафик «через VPN» в SystemInfo как неизвестные поля 100/101 (protoc на ПК нет; Dart читает в `lib/features/stats/model/vpn_traffic.dart`).
5. `hiddify-sing-box/daemon/started_service.go` — время начала сессии не сбрасывается при перезагрузке конфигурации (смена сети/сервера); отдаётся в SystemInfo полем 102 (таймер на главной).
4. `hiddify-sing-box/protocol/group/balancer/lowest_delay.go` — допуск (tolerance): сервер не меняется, пока другой не быстрее на 150 мс или текущий не умер; `balancer-keep-connections` не рвёт соединения. Включено только на ПК (`config_option_repository.dart`).

## Подводные камни

- Claude Code работает в песочнице MSIX: реальные `%APPDATA%` и часть реестра установленного A-VPN ему не видны — логи просить у пользователя (Логи → сохранить).
- Строки `[ERROR] status` в app.log — шум (переподключение к ядру), не ошибка.
- Каналы уведомлений Android неизменяемы: для смены настроек нужен новый id (`service_no_badge`).
- Ядро скачивает rule-set'ы через `select` при старте и зависает — поэтому список РКН встроен.
- У `A-VPN.exe` может стоять флаг совместимости «от имени администратора» — установщик запускает приложение с `runascurrentuser`.

## Безопасность

- Ссылку на подписку в репозиторий не класть (`.\A-VPN\check-sub.ps1` содержит её — держать вне git, при утечке сбросить в кабинете Sigma Gate).
- Ключи WireGuard на ПК удалены; профиль Mechta живёт только в приложении.
- В панели провайдера осталось тестовое устройство «A-VPN-test» — удалить.
