import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/app/theme.dart';
import 'package:vsla_ledger/app/widgets.dart';
import 'package:vsla_ledger/core/models/entry_line.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/ledger/entry_tile.dart';
import 'package:vsla_ledger/features/members/balance_card.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// One member: their balance, the ways to record money, and their history
/// (grouped by meeting day, newest first).
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
        padding: const EdgeInsets.only(bottom: 24),
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
            child: _ActionGrid(
              actions: [
                _Action(
                  type: EntryType.contribution,
                  label: l10n.recordContributionButton,
                  onTap: () => context.push('$here/contribute'),
                ),
                _Action(
                  type: EntryType.loan,
                  label: l10n.issueLoanButton,
                  onTap: () => context.push('$here/lend'),
                ),
                _Action(
                  type: EntryType.repayment,
                  label: l10n.recordRepaymentButton,
                  onTap: () => context.push('$here/repay'),
                ),
                _Action(
                  type: EntryType.socialFund,
                  label: l10n.recordSocialFundButton,
                  onTap: () => context.push('$here/social-fund'),
                ),
                _Action(
                  type: EntryType.fine,
                  label: l10n.recordFineButton,
                  onTap: () => context.push('$here/fine'),
                ),
                if (ref.watch(showDemoScreensProvider))
                  _Action(
                    type: null,
                    icon: Icons.timer_outlined,
                    label: l10n.compareButton,
                    onTap: () => context.push('$here/compare'),
                  ),
              ],
            ),
          ),
          AsyncValueView(
            value: ref.watch(memberHistoryProvider(memberId)),
            builder: (lines) => lines.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: l10n.noEntriesYet,
                  )
                : _History(lines: lines),
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.type,
    required this.label,
    required this.onTap,
    this.icon,
  });

  /// The kind of record this records, which sets its colour and icon.
  final EntryType? type;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
}

/// The ways to record money: big tappable tiles, three to a row.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        // Fewer, wider tiles with large text, so a word never breaks.
        final perRow = MediaQuery.textScalerOf(context).scale(10) > 13 ? 2 : 3;
        final width = (constraints.maxWidth - (perRow - 1) * gap) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _ActionTile(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = action.type == null
        ? null
        : entryStyleOf(context, action.type!);
    final color = style?.color ?? scheme.primary;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(style?.icon ?? action.icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// History under a heading for each meeting day, like the pages of a paper
/// ledger.
class _History extends StatelessWidget {
  const _History({required this.lines});

  final List<EntryLine> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final days = <DateTime, List<EntryLine>>{};
    for (final line in lines) {
      days.putIfAbsent(line.entry.meetingDay, () => []).add(line);
    }
    final newestFirst = days.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l10n.historyTitle),
        for (final day in newestFirst) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
            child: Text(
              l10n.entryDate(day),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, line) in days[day]!.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  EntryTile(line: line),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
