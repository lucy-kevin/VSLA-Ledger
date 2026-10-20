import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/ledger/entry_tile.dart';
import 'package:vsla_ledger/features/members/balance_card.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// One member: their balance, buttons to record money, and their history.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({
    required this.groupId,
    required this.memberId,
    super.key,
  });

  final String groupId;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final memberName = ref.watch(memberProvider(memberId)).valueOrNull?.name;
    final here = '/groups/$groupId/members/$memberId';

    return Scaffold(
      appBar: AppBar(title: Text(memberName ?? '')),
      body: ListView(
        children: [
          AsyncValueView(
            value: ref.watch(memberBalanceProvider(memberId)),
            builder: (balance) => BalanceCard(
              savingsLabel: l10n.savingsLabel,
              loansLabel: l10n.loansOutstandingLabel,
              balance: balance,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('$here/contribute'),
                  icon: const Icon(Icons.savings),
                  label: Text(l10n.recordContributionButton),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('$here/lend'),
                  icon: const Icon(Icons.call_made),
                  label: Text(l10n.issueLoanButton),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('$here/repay'),
                  icon: const Icon(Icons.call_received),
                  label: Text(l10n.recordRepaymentButton),
                ),
                if (ref.watch(showDemoScreensProvider))
                  OutlinedButton.icon(
                    onPressed: () => context.push('$here/compare'),
                    icon: const Icon(Icons.timer),
                    label: Text(l10n.compareButton),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              l10n.historyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          AsyncValueView(
            value: ref.watch(memberHistoryProvider(memberId)),
            builder: (lines) => lines.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.noEntriesYet),
                  )
                : Column(
                    children: [
                      for (final line in lines) EntryTile(line: line),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
