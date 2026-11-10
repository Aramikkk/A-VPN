# Патчи A-VPN к ядру

A-VPN работает на ядре [`hiddify-core`](https://github.com/hiddify/hiddify-core) 5.4.0 и [`hiddify-sing-box`](https://github.com/hiddify/hiddify-sing-box). Изменения лежат здесь в виде патчей (`git format-patch`), а не в копии чужих репозиториев.

| Папка | К чему применяется | База |
|---|---|---|
| `core/` | `hiddify/hiddify-core` | коммит `b097daad` (v5.4.0) |
| `sing-box/` | подмодуль `hiddify-sing-box` | коммит `004371d6b` |

## Что в патчах

- `core/`: статистика трафика по серверам и сессии в `SystemInfo`, горячая перезагрузка (`Reload`, `Rebuild`, `Suspend`) при смене сети, группы сайтов («мульти серверы») и их пороги по сети, блокировка рекламы на уровне VPN, правила «только заблокированное», допуск и приоритет подписки, поиск приложения для каждого соединения.
- `sing-box/`: сохранение времени начала сессии, трафик по исходящим, выбор лучшего сервера балансировщиком, настройки urltest.

Патчи пронумерованы в порядке применения; в заголовке каждого сказано, что он меняет.

## Как собирается

Это делает workflow [`.github/workflows/release.yml`](../../.github/workflows/release.yml):

```bash
git clone https://github.com/hiddify/hiddify-core core && cd core
git checkout b097daad
git submodule update --init hiddify-sing-box
(cd hiddify-sing-box && git checkout 004371d6b)
git am --3way ../avpn/core54-patches/core/*.patch
(cd hiddify-sing-box && git am --3way ../../avpn/core54-patches/sing-box/*.patch)
# затем gomobile bind (теги и флаги указаны в workflow)
```

Получается `hiddify-core.aar`, который кладётся в `android/app/libs/`.

## Если патч не применился

Чаще всего это значит, что база (`b097daad` или `004371d6b`) другая. Переход на новую версию ядра требует переноса патчей вручную (`git am --3way`, затем правка конфликтов).
