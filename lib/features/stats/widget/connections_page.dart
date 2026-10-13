import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/route_rules/notifier/ru_services.dart';
import 'package:hiddify/features/route_rules/notifier/rule_groups.dart';
import 'package:hiddify/features/stats/model/vpn_traffic.dart';
import 'package:hiddify/features/stats/notifier/connections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';

/// The phone's installed apps by package: their names and icons, for the connection list.
final installedAppsProvider = FutureProvider<Map<String, ({String name, Uint8List? icon})>>((ref) async {
  if (!Platform.isAndroid) return const {};
  // reading every app with its icon holds up the phone's main thread for seconds (the interface freezes): the
  // saved list shows at once, and a fresh one is read only when it's a day old (a new app shows by its package
  // until then)
  if (_freshApps != null) return _freshApps!;
  final dirs = await ref.watch(appDirectoriesProvider.future);
  final file = File('${dirs.baseDir.path}/installed_apps.json');
  Future<Map<String, ({String name, Uint8List? icon})>> fresh() async {
    try {
      final apps = await InstalledApps.getInstalledApps(false, true);
      final map = {for (final a in apps) a.packageName: (name: a.name, icon: a.icon)};
      unawaited(
        file
            .writeAsString(
              jsonEncode({
                '@at': DateTime.now().millisecondsSinceEpoch,
                for (final e in map.entries)
                  e.key: [e.value.name, if (e.value.icon != null) base64Encode(e.value.icon!)],
              }),
            )
            .then((_) {}, onError: (_) {}),
      );
      return _freshApps = map;
    } catch (_) {
      return _freshApps = const {};
    }
  }

  try {
    if (file.existsSync()) {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final cached = <String, ({String name, Uint8List? icon})>{
        for (final e in json.entries)
          if (e.value is List && (e.value as List).isNotEmpty)
            e.key: (
              name: (e.value as List)[0] as String,
              icon: (e.value as List).length > 1 ? base64Decode((e.value as List)[1] as String) : null,
            ),
      };
      final at = json['@at'] is int ? DateTime.fromMillisecondsSinceEpoch(json['@at'] as int) : DateTime(2000);
      if (DateTime.now().difference(at) > const Duration(days: 1)) {
        unawaited(fresh().then((_) => ref.invalidateSelf()));
      } else {
        _freshApps = cached;
      }
      return cached;
    }
  } catch (_) {
    // an unreadable copy: wait for the fresh list
  }
  return fresh();
});

Map<String, ({String name, Uint8List? icon})>? _freshApps;

enum _View { apps, sites }

enum _Filter { all, vpn, direct }

/// The Connections tab: which apps connected to which sites, and whether each went through the VPN (and which
/// server) or direct. Grouped by app or by site, the most traffic first; a group opens to its connections.
class ConnectionsPage extends HookConsumerWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // a tab out of sight (another one is open) stops following the list, so it isn't worked out again every two
    // seconds for nothing; it catches up when it's back on screen
    final visible = TickerMode.of(context);
    final state = visible ? ref.watch(connectionsProvider) : ref.read(connectionsProvider);
    final apps = ref.watch(installedAppsProvider).valueOrNull ?? const {};
    final view = useState(_View.apps);
    final filter = useState(_Filter.all);
    final showSmall = useState(false);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String appName(String app) => connectionAppName(t, apps, app);

    final items = state.items.where((c) {
      if (filter.value == _Filter.vpn && c.route != ConnectionRoute.vpn) return false;
      if (filter.value == _Filter.direct && c.route == ConnectionRoute.vpn) return false;
      return true;
    }).toList();
    final allGroups = groupConnections(items, view.value == _View.apps ? (c) => c.app : (c) => c.host);
    // apps and sites that moved less than a megabyte are left out unless asked for
    final fresh = showSmall.value ? allGroups : allGroups.where((g) => g.total >= smallTraffic).toList();
    // the order by traffic is redone every 30 seconds, not on every update, so the cards don't jump around
    // while they're read; a new app or site comes in at the end until then
    final order = useRef(<String>[]);
    final sortedAt = useRef(DateTime.fromMillisecondsSinceEpoch(0));
    final sortedFor = useRef('');
    final sortKey = '${view.value}|${filter.value}|${showSmall.value}';
    final now = DateTime.now();
    if (sortKey != sortedFor.value || now.difference(sortedAt.value) > const Duration(seconds: 30)) {
      order.value = [for (final g in fresh) g.key];
      sortedAt.value = now;
      sortedFor.value = sortKey;
    }
    final place = {for (final (i, k) in order.value.indexed) k: i};
    final groups = [...fresh]..sort((a, b) => (place[a.key] ?? 1 << 30).compareTo(place[b.key] ?? 1 << 30));
    final hidden = allGroups.length - groups.length;
    Widget card(ConnectionGroup g) => _GroupCard(
      key: ValueKey('${view.value}:${g.key}'),
      group: g,
      byApp: view.value == _View.apps,
      appName: appName,
      iconOf: (app) => apps[app]?.icon,
    );
    final all = state.items;
    final open = all.where((c) => c.active).length;
    int count(ConnectionRoute route) => all.where((c) => c.route == route).fold(0, (n, c) => n + c.count);
    final viaVpn = count(ConnectionRoute.vpn);
    final direct = count(ConnectionRoute.direct);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.avpn.connectionsTab),
        actions: [
          if (all.any((c) => !c.active))
            IconButton(
              tooltip: t.avpn.connClear,
              icon: const Icon(Icons.cleaning_services_rounded),
              onPressed: () => ref.read(connectionsProvider.notifier).clearClosed(),
            ),
        ],
      ),
      body: !state.available && all.isEmpty
          ? _Empty(icon: Icons.link_off_rounded, text: t.avpn.connNotConnected)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverList.list(
                        children: [
                          Row(
                            children: [
                              _Count(label: t.avpn.connOpen, value: open, color: scheme.onSurface),
                              const Gap(8),
                              _Count(label: t.avpn.statsViaVpn, value: viaVpn, color: scheme.primary),
                              const Gap(8),
                              _Count(label: t.avpn.statsDirect, value: direct, color: scheme.onSurfaceVariant),
                            ],
                          ),
                          const Gap(12),
                          SegmentedButton<_View>(
                            segments: [
                              ButtonSegment(
                                value: _View.apps,
                                icon: const Icon(Icons.apps_rounded),
                                label: Text(t.avpn.connByApp),
                              ),
                              ButtonSegment(
                                value: _View.sites,
                                icon: const Icon(Icons.public_rounded),
                                label: Text(t.avpn.connBySite),
                              ),
                            ],
                            selected: {view.value},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => view.value = s.first,
                          ),
                          const Gap(10),
                          Row(
                            children: [
                              for (final (f, label) in [
                                (_Filter.all, t.avpn.connAll),
                                (_Filter.vpn, 'VPN'),
                                (_Filter.direct, t.avpn.statsDirect),
                              ]) ...[
                                ChoiceChip(
                                  label: Text(label),
                                  selected: filter.value == f,
                                  onSelected: (_) => filter.value = f,
                                ),
                                const Gap(6),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (groups.isEmpty && hidden == 0)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(icon: Icons.hourglass_empty_rounded, text: t.avpn.connEmpty),
                      )
                    else
                      SliverLayoutBuilder(
                        builder: (context, box) {
                          final rows = groups.length;
                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            sliver: SliverList.separated(
                              itemCount: rows + (hidden > 0 || showSmall.value ? 1 : 0),
                              separatorBuilder: (_, _) => const Gap(6),
                              itemBuilder: (context, i) => i == rows
                                  ? Center(
                                      child: TextButton.icon(
                                        icon: Icon(
                                          showSmall.value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          showSmall.value ? t.avpn.connHideSmall : t.avpn.connShowSmall(n: hidden),
                                        ),
                                        onPressed: () => showSmall.value = !showSmall.value,
                                      ),
                                    )
                                  : card(groups[i]),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The app's name as people know it: its label on the phone, the program's name on a computer.
String connectionAppName(Translations t, Map<String, ({String name, Uint8List? icon})> apps, String app) =>
    app.isEmpty ? t.avpn.connUnknownApp : (apps[app]?.name ?? _shortApp(app));

/// "C:\Program Files\Google\Chrome\Application\chrome.exe" → "chrome"; a package keeps its last parts.
String _shortApp(String app) {
  final file = app.split(RegExp(r'[\\/]')).last;
  if (file.toLowerCase().endsWith('.exe')) return file.substring(0, file.length - 4);
  return file;
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: .3,
              ),
            ),
            const Gap(2),
            Text(
              '$value',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            const Gap(12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// An app (or a site) with its traffic and the way its connections went; tapped, the sites it connected to (or
/// the apps that connected to it), each with its own way.
class _GroupCard extends HookConsumerWidget {
  const _GroupCard({super.key, required this.group, required this.byApp, required this.appName, required this.iconOf});

  final ConnectionGroup group;
  final bool byApp;
  final String Function(String app) appName;
  final Uint8List? Function(String app) iconOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final expanded = useState(false);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = t.avpn.bytesUnits.split(',');
    String size(int bytes) => formatBytes(bytes, units);

    final title = byApp ? appName(group.key) : (group.key.isEmpty ? '—' : group.key);
    final subtitle = byApp
        ? [
            t.avpn.connSites(n: {for (final c in group.items) c.host}.length),
          ].join(' · ')
        : {for (final c in group.items) appName(c.app)}.take(3).join(', ');
    // inside: by site for an app, by app for a site
    final inner = groupConnections(group.items, byApp ? (c) => c.host : (c) => c.app);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => expanded.value = !expanded.value,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
              child: Row(
                children: [
                  if (byApp)
                    ConnectionAppIcon(icon: iconOf(group.key), name: title)
                  else
                    _RouteDot(route: group.mainRoute, size: 32),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Gap(3),
                        // where it went, then the package or the apps, on one line
                        Row(
                          children: [
                            Flexible(flex: 3, child: _RouteBadge(group: group)),
                            const Gap(6),
                            Expanded(
                              flex: 2,
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        size(group.total),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Gap(2),
                      // the count shrinks rather than push the card's text aside on a narrow phone
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 76),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            group.open > 0
                                ? t.avpn.connOpenOf(open: group.open, n: group.count)
                                : t.avpn.connCount(n: group.count),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: group.open > 0 ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded.value) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            for (final g in inner.take(50))
              _InnerRow(title: byApp ? (g.key.isEmpty ? '—' : g.key) : appName(g.key), group: g, size: size),
            if (inner.length > 50)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('+${inner.length - 50}', style: theme.textTheme.labelSmall),
              ),
          ],
        ],
      ),
    );
  }
}

class _InnerRow extends ConsumerWidget {
  const _InnerRow({required this.title, required this.group, required this.size});

  final String title;
  final ConnectionGroup group;
  final String Function(int) size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ports = {
      for (final c in group.items)
        if (c.port > 0) '${c.network}:${c.port}',
    }.take(3).join(', ');
    final rules = {
      for (final c in group.items)
        if (ruleLabel(c.rule, t) case final r?) r,
    }.take(2).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Row(
        children: [
          _RouteDot(route: group.mainRoute, size: 10),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                Text(
                  [_routeText(t, group), ports, if (rules.isNotEmpty) '${t.avpn.connRule}: $rules'].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(size(group.total), style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (group.open > 0)
                Text(
                  t.avpn.connOpenCount(n: group.open),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "rule_set=[blocked ru-blocked] => route(select)" → "blocked, ru-blocked"; "domain_suffix=[.ru] => …" → ".ru";
/// null for the default route ("final").
///
/// The app's own rules read by name: the blocked-sites list, the Russian sites and the Russian apps.
String? ruleLabel(String rule, Translations t) {
  final match = rule.split('=>').first.trim();
  if (match.isEmpty || match == 'final') return null;
  // the built-in groups, by their lists' first entries (the core prints a long list as its first few)
  final groups = {
    aiDomains.first: t.avpn.ruleAi,
    aiApps.first: t.avpn.ruleAi,
    googleDomains.first: t.avpn.ruleGoogle,
    googleApps.first: t.avpn.ruleGoogle,
    socialDomains.first: t.avpn.ruleSocial,
    chinaDomains.first: t.avpn.ruleChina,
    chinaApps.first: t.avpn.ruleChina,
    otherBlockedApps.first: t.avpn.ruleBlocked,
    otherBlockedProcesses.first: t.avpn.ruleBlocked,
    otherBlockedDomains.first: t.avpn.ruleBlocked,
    'xn--p1ai': t.avpn.ruleRuSites,
    ruAppPackages.first: t.avpn.ruleRuApps,
  };
  for (final MapEntry(key: first, value: label) in groups.entries) {
    if (RegExp(r'[\[ ]' + RegExp.escape(first) + r'[ \]]').hasMatch(match)) return label;
  }
  final action = rule.contains('=>') ? rule.split('=>').last : '';
  final listed = RegExp(r'\[([^\]]*)\]').allMatches(match).expand((m) => m.group(1)!.split(' ')).length;
  final direct = action.contains('direct');
  // a list (the core shortens long ones to their first few and "..."): named by what it holds and where it sends
  if (listed > 3 || match.contains('...')) {
    if (match.contains('ip_cidr')) return direct ? t.avpn.ruleLocalNet : t.avpn.ruleBlockedIps;
    if (match.contains('domain') || match.contains('rule_set')) {
      return direct ? t.avpn.ruleRuSites : t.avpn.ruleBlocked;
    }
    if (match.contains('package_name')) return direct ? t.avpn.ruleRuApps : t.avpn.ruleAppsVpn;
  }
  // only the protocol left to match: everything the other rules didn't take
  if (RegExp(r'^network=\[[a-z ]+\]$').hasMatch(match)) return t.avpn.ruleEverythingElse;
  final values = RegExp(
    r'\[([^\]]*)\]',
  ).allMatches(match).expand((m) => m.group(1)!.split(' ')).where((v) => v.isNotEmpty);
  final text = values.isEmpty ? match : values.join(', ');
  return text.length > 40 ? '${text.substring(0, 39)}…' : text;
}

String _routeText(Translations t, ConnectionGroup g) {
  if (g.mixed) return t.avpn.connMixed;
  return switch (g.mainRoute) {
    ConnectionRoute.vpn => g.servers.isEmpty ? 'VPN' : 'VPN · ${serverFlags(g.servers)}',
    ConnectionRoute.direct => t.avpn.statsDirect,
    ConnectionRoute.block => t.avpn.connBlocked,
  };
}

Color routeColor(ColorScheme scheme, ConnectionRoute route) => switch (route) {
  ConnectionRoute.vpn => scheme.primary,
  ConnectionRoute.direct => scheme.onSurfaceVariant,
  ConnectionRoute.block => scheme.error,
};

/// "VPN · 🇸🇪 Швеция 2", "Напрямую", or both when an app went both ways.
class _RouteBadge extends ConsumerWidget {
  const _RouteBadge({required this.group});

  final ConnectionGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget pill(ConnectionRoute route, String text, int count) {
      final color = routeColor(scheme, route);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: route == ConnectionRoute.vpn ? color.withValues(alpha: .16) : null,
          border: Border.all(color: color.withValues(alpha: route == ConnectionRoute.vpn ? .0 : .6)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          group.mixed ? '$text $count' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      );
    }

    final servers = group.servers;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (group.vpn > 0)
          pill(ConnectionRoute.vpn, servers.isEmpty ? 'VPN' : 'VPN · ${serverFlags(servers)}', group.vpn),
        if (group.direct > 0) pill(ConnectionRoute.direct, t.avpn.statsDirect, group.direct),
        if (group.blocked > 0) pill(ConnectionRoute.block, t.avpn.connBlocked, group.blocked),
      ],
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.route, required this.size});

  final ConnectionRoute route;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = routeColor(Theme.of(context).colorScheme, route);
    if (size < 16) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
      child: Icon(
        route == ConnectionRoute.vpn
            ? Icons.shield_rounded
            : (route == ConnectionRoute.block ? Icons.block_rounded : Icons.alt_route_rounded),
        size: size * .5,
        color: color,
      ),
    );
  }
}

/// An app's icon, or its first letter on a tinted tile when it has none.
class ConnectionAppIcon extends StatelessWidget {
  const ConnectionAppIcon({super.key, required this.icon, required this.name, this.size = 32});

  final Uint8List? icon;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .3),
        child: Image.memory(icon!, width: size, height: size, gaplessPlayback: true),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}
