import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/features/proxy/data/server_region_filter.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/ai_group.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings / Sites: the AI group. One server for ChatGPT, Claude, Gemini, Perplexity and DeepSeek, chosen for each
/// network: the main one and two backups. [onChanged] applies the choice (the connection restarts with it).
class AiGroupCard extends HookConsumerWidget {
  const AiGroupCard({required this.onChanged, super.key});

  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final onMobile = useState(false);
    final network = onMobile.value ? NetworkKind.mobile : NetworkKind.wifi;
    final pref = onMobile.value ? ConfigOptions.aiServersMobile : ConfigOptions.aiServersWifi;
    final switchPref = onMobile.value ? ConfigOptions.aiGroupMobile : ConfigOptions.aiGroupWifi;
    final enabled = ref.watch(switchPref);
    final servers = ref.watch(pref);
    final items = ref.watch(proxiesOverviewNotifierProvider).valueOrNull?.items ?? const <OutboundInfo>[];
    final labels = [t.avpn.aiPrimary, t.avpn.aiBackup1, t.avpn.aiBackup2];

    String nameOf(String tag) {
      final info = items.where((e) => e.tag == tag).firstOrNull;
      final name = info == null ? serverNameOf(tag) : serverName(info);
      final text = [name.flag, name.title].whereType<String>().join(' ');
      final ms = info?.urlTestDelay ?? 0;
      return ms > 0 && ms < 65000 ? '$text · $ms ms' : text;
    }

    Future<void> pick(int row) async {
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.avpn.aiNeedConnect)));
        return;
      }
      final taken = [
        for (var i = 0; i < servers.length; i++)
          if (i != row) servers[i],
      ];
      final candidates = aiCandidates(items, network: network, taken: taken);
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('${t.avpn.aiPickTitle} · ${labels[row]}'),
          children: [
            if (row < servers.length)
              ListTile(title: Text(t.avpn.aiNotChosen), onTap: () => Navigator.of(context).pop('')),
            for (final item in candidates)
              ListTile(
                selected: row < servers.length && servers[row] == item.tag,
                title: Text(nameOf(item.tag), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(item.tag),
              ),
          ],
        ),
      );
      if (chosen == null) return;
      await ref.read(pref.notifier).update(setAiServer(servers, row, chosen.isEmpty ? null : chosen));
      await onChanged();
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome_rounded),
          title: Text(t.avpn.aiGroup),
          subtitle: Text(t.avpn.aiGroupMsg),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Wi-Fi'), icon: Icon(Icons.wifi_rounded)),
              ButtonSegment(value: true, label: Text('LTE'), icon: Icon(Icons.signal_cellular_alt_rounded)),
            ],
            selected: {onMobile.value},
            onSelectionChanged: (v) => onMobile.value = v.first,
          ),
        ),
        // this network's own switch: the group can work on Wi-Fi only, or on mobile data only
        SwitchListTile.adaptive(
          title: Text(onMobile.value ? t.avpn.aiGroupOnLte : t.avpn.aiGroupOnWifi),
          value: enabled,
          onChanged: (on) async {
            await ref.read(switchPref.notifier).update(on);
            await onChanged();
          },
        ),
        if (enabled)
          for (var row = 0; row < 3; row++)
            ListTile(
              enabled: row <= servers.length,
              leading: Text(
                '${row + 1}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              title: Text(labels[row]),
              subtitle: Text(row < servers.length ? nameOf(servers[row]) : t.avpn.aiNotChosen),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pick(row),
            ),
      ],
    );
  }
}
