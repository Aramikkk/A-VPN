# A-VPN поверх ядра Hiddify 5.4.0

Патчи A-VPN, перенесённые на ядро 5.4.0 (версия приложения 1.1.16).

- `core/` — патчи слоя `hiddify-core` поверх `hiddify/hiddify-core` @ `b097daad` (v5.4.0).
- `sing-box/` — патчи `hiddify-sing-box` поверх `004371d6b`.
- Сборка: `.\tools\build-core54.sh` (Android AAR) и `build-core-windows54.sh` (Windows DLL), Go 1.27.3
  (`GOTOOLCHAIN=go1.27.3`), исходники в `.\tools\hcore54`.
- Прежнее ядро (на 5.0.0) осталось в `.\tools\hcore-build`; его сборки: `.\tools\core-backup`
  (`hiddify-core-aravpn-1.1.14-old-core.aar`, `win-1.1.14\`). Откат — вернуть эти файлы в
  `android/app/libs/hiddify-core.aar` и `hiddify-core/bin/`, а протофайлы Dart/Kotlin из версии 1.1.15 (git-тег `avpn-1.1.15`).
