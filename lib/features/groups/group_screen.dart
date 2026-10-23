import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/groups/sync_panel.dart';
import 'package:vsla_ledger/features/members/balance_card.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// One group: its totals, sync status and members.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return AsyncValueView(
      value: ref.watch(groupProvider(groupId)),
      builder: (group) => Scaffold(
        appBar: AppBar(title: Text(group?.name ?? '')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/groups/$groupId/members/new'),
          icon: const Icon(Icons.person_add),
          label: Text(l10n.addMemberButton),
        ),
        body: group == null
            ? Center(child: Text(l10n.loadError))
            : _GroupBody(group: group),
      ),
    );
  }
}

class _GroupBody extends ConsumerWidget {
  const _GroupBody({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(child: SelectableText(l10n.joinCode(group.joinCode))),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: l10n.copyJoinCode,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: group.joinCode));
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.joinCodeCopied)),
                  );
                },
              ),
            ],
          ),
        ),
        AsyncValueView(
          value: ref.watch(groupBalanceProvider(group.id)),
          builder: (balance) => BalanceCard(
            savingsLabel: l10n.groupSavingsLabel,
            loansLabel: l10n.groupLoansLabel,
            balance: balance,
          ),
        ),
        const SyncPanel(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.membersTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        AsyncValueView(
          value: ref.watch(membersProvider(group.id)),
          builder: (members) => Column(
            children: [
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.noMembersYet),
                ),
              for (final member in members)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(member.name),
                  subtitle: member.phone == null ? null : Text(member.phone!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/groups/${group.id}/members/${member.id}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
