import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A card the developer can be thanked on: the bank, the 16 digits and who the card is in the name of.
typedef DonationCard = ({String bank, String number, String holder});

/// The cards shown in About → «Поблагодарить разработчика». A transfer is voluntary and opens nothing in the app.
const donationCards = <DonationCard>[
  (bank: 'Сбербанк', number: '2202205332798831', holder: 'Арам Аракелян'),
  (bank: 'Т-Банк', number: '2200700617588750', holder: 'Арам Аракелян'),
];

/// "2202 2053 3279 8831": a card number in groups of four.
String formatCardNumber(String number) => [
  for (var i = 0; i < number.length; i += 4) number.substring(i, i + 4 > number.length ? number.length : i + 4),
].join(' ');

/// Whether [number] passes the Luhn check every bank card number does (a typo in a number on this page is caught by
/// the test).
bool isValidCardNumber(String number) {
  if (!RegExp(r'^\d{13,19}$').hasMatch(number)) return false;
  var sum = 0;
  for (var i = 0; i < number.length; i++) {
    var digit = int.parse(number[number.length - 1 - i]);
    if (i.isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return sum % 10 == 0;
}

/// The "thank the developer" line of the About page: it opens the cards, each with its copy button.
class DonateTile extends ConsumerWidget {
  const DonateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return ListTile(
      leading: const Icon(Icons.favorite_rounded),
      title: Text(t.avpn.donateTitle),
      subtitle: Text(t.avpn.donateHint),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _DonateSheet(),
      ),
    );
  }
}

class _DonateSheet extends ConsumerWidget {
  const _DonateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.avpn.donateTitle, style: theme.textTheme.titleLarge),
            const Gap(8),
            Text(t.avpn.donateText, style: theme.textTheme.bodyMedium),
            const Gap(16),
            for (final card in donationCards) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.bank, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                    const Gap(6),
                    SelectableText(
                      formatCardNumber(card.number),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Gap(2),
                    Text(card.holder, style: theme.textTheme.bodySmall),
                    const Gap(10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(t.avpn.donateCopy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: card.number));
                          ref.read(inAppNotificationControllerProvider).showInfoToast(t.avpn.donateCopied);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
            ],
            Text(t.avpn.donateThanks, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
