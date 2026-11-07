import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profiles_update_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfilesPage extends HookConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final asyncProfiles = ref.watch(profilesNotifierProvider);

    ref.listen(hasAnyProfileProvider, (_, next) {
      if (next.value == false) {
        context.goNamed('home');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.profiles.title),
        actions: [
          IconButton(
            onPressed: () => ref.read(foregroundProfilesUpdateNotifierProvider.notifier).trigger(),
            icon: const Icon(Icons.sync_rounded),
            tooltip: t.pages.profiles.updateSubscriptions,
          ),
          IconButton(
            onPressed: () => ref.read(dialogNotifierProvider.notifier).showSortProfiles(),
            icon: const Icon(Icons.sort_rounded),
            tooltip: t.common.sort,
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => await ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
        label: Text(t.pages.profiles.add),
        icon: const Icon(Icons.add_rounded),
      ),
      body: asyncProfiles.when(
        // a card held a moment can be dragged to another place: the order is kept (choosing a sort in the dialog
        // above puts the cards back in that sort's order)
        data: (data) => ReorderableListView.builder(
          padding: const EdgeInsets.all(12).copyWith(bottom: 84),
          buildDefaultDragHandles: false,
          itemCount: data.length,
          onReorder: (from, to) => ref.read(profilesNotifierProvider.notifier).reorder(data, from, to),
          proxyDecorator: (child, index, animation) =>
              Material(color: Colors.transparent, elevation: 6, borderRadius: BorderRadius.circular(14), child: child),
          itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
            key: ValueKey(data[index].id),
            index: index,
            child: Padding(
              padding: EdgeInsets.only(bottom: index == data.length - 1 ? 0 : 12),
              child: ProfileTile(profile: data[index]),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(t.presentShortError(error)),
      ),
    );
  }
}
