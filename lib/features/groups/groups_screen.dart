import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// The first screen: every group on this phone.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupsTitle),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/groups/join'),
            icon: const Icon(Icons.group_add),
            label: Text(l10n.joinGroupButton),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.createGroupButton),
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView(
              value: ref.watch(groupsProvider),
              builder: (groups) {
                if (groups.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noGroupsYet,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView(
                  children: [
                    for (final group in groups)
                      ListTile(
                        leading: const Icon(Icons.groups),
                        title: Text(group.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/groups/${group.id}'),
                      ),
                  ],
                );
              },
            ),
          ),
          // Room at the bottom for the button that floats at the right.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            child: Text(
              l10n.demoDataNotice,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
