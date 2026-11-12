import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/strip_look.dart';
import 'package:hiddify/features/connection/notifier/vpn_pause.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The VPN paused by the service (a home Wi-Fi, or an app on screen): a thin strip under the title, in the look of the
/// theme in use, that says so, so the home screen is not just a frozen picture of the last measurements.
class PauseStrip extends ConsumerWidget {
  const PauseStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pause = ref.watch(vpnPauseProvider);
    if (!pause.paused) return const SizedBox.shrink();
    final t = ref.watch(translationsProvider).valueOrNull;
    if (t == null) return const SizedBox.shrink();
    final look = StripLook.of(context);
    final text = pause.home
        ? t.avpn.vpnStripHome
        : pause.app.isNotEmpty
        ? t.avpn.vpnStripApp(name: pause.app)
        : t.avpn.vpnStripOther;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Container(
        key: const Key('pause-strip'),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: look.decoration,
        child: Row(
          children: [
            Icon(Icons.pause_circle_outline_rounded, size: 20, color: look.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(look.dots ? text.toUpperCase() : text, style: look.text(12.5, look.ink, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
