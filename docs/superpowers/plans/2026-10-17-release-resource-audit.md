# Release 5.9.40: device regressions and resource audit

Preserve the selected theme, routing and saved preferences. Fix confirmed causes before broadening scope.

- [x] Regression: native session time remains visible across an empty stats reading.
- [x] Regression: landscape with real system insets and small remaining card height.
- [x] Reduce session snapshot disk flushes without losing the final reading on disposal.
- [x] Reduce blurred backdrop texture size and release temporary recorded pictures.
- [x] Replace frequent background timer wakeups with lifecycle-aware scheduling.
- [x] Run complete Flutter tests/analyzer; examine remaining failures and logs.
- [x] Build numbered Android/Windows artifacts into releases/5.9.40.
- [x] Install and retest on connected phone: rotation, handoff, Instagram, foreground/background resource samples.
- [x] Save evidence and report limits; do not call unverified checks passed.

Known limits are documented in the release QA report: experimental monitoring changes still require a native rebuild; foreground CPU and long-term battery life need longer profiling. Windows runtime TUN testing was not performed.
