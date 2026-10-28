import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/app/widgets.dart';
import 'package:vsla_ledger/core/ledger/balance_calculator.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
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
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        AsyncValueView(
          value: ref.watch(groupBalanceProvider(group.id)),
          builder: (balance) => BalanceCard(
            savingsLabel: l10n.groupSavingsLabel,
            loansLabel: l10n.groupLoansLabel,
            balance: balance,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/groups/${group.id}/meeting'),
                icon: const Icon(Icons.event_available),
                label: Text(l10n.startMeetingButton),
              ),
              const SizedBox(height: 12),
              _JoinCodeRow(code: group.joinCode),
              const SizedBox(height: 12),
              const SyncPanel(),
            ],
          ),
        ),
        SectionHeader(l10n.membersTitle),
        AsyncValueView(
          value: ref.watch(membersProvider(group.id)),
          builder: (members) => members.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.noMembersYet),
                )
              : _MemberList(
                  groupId: group.id,
                  members: members,
                  entries:
                      ref.watch(groupEntriesProvider(group.id)).valueOrNull ??
                      const [],
                ),
        ),
      ],
    );
  }
}

/// The join code, easy to read out loud and to copy.
class _JoinCodeRow extends StatelessWidget {
  const _JoinCodeRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.key, color: scheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(l10n.joinCode(code))),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.copyJoinCode,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: code));
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.joinCodeCopied)),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The members, each with what they have saved and still owe, worked out in
/// one pass over the group's entries.
class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.groupId,
    required this.members,
    required this.entries,
  });

  final String groupId;
  final List<Member> members;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, member) in members.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            Builder(
              builder: (context) {
                final balance = computeBalance([
                  for (final e in entries)
                    if (e.memberId == member.id) e,
                ]);
                final owed = l10n.amountUgx(balance.loansOutstandingUgx);
                final money = [
                  '${l10n.savingsLabel} ${l10n.amountUgx(balance.savingsUgx)}',
                  if (balance.loansOutstandingUgx > 0)
                    '${l10n.loansOutstandingLabel} $owed',
                ].join(' · ');
                return ListTile(
                  minVerticalPadding: 12,
                  leading: InitialsAvatar(member.name),
                  title: Text(
                    member.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    member.phone == null ? money : '$money\n${member.phone}',
                  ),
                  isThreeLine: member.phone != null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/groups/$groupId/members/${member.id}'),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
