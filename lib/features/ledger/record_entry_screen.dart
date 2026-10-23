import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/app/save_guard.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/ledger/share_chooser.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Records savings, social fund, a fine, a loan or a repayment for one
/// member, for a chosen meeting day (today unless changed).
class RecordEntryScreen extends ConsumerWidget {
  const RecordEntryScreen({
    required this.groupId,
    required this.memberId,
    required this.type,
    super.key,
  }) : assert(type != EntryType.correction, 'Use cancelEntry instead');

  final String groupId;
  final String memberId;
  final EntryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final title = switch (type) {
      EntryType.contribution => l10n.recordContributionTitle,
      EntryType.socialFund => l10n.recordSocialFundTitle,
      EntryType.fine => l10n.recordFineTitle,
      EntryType.loan => l10n.issueLoanTitle,
      _ => l10n.recordRepaymentTitle,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncValueView(
        value: ref.watch(groupProvider(groupId)),
        builder: (group) {
          if (type != EntryType.repayment) {
            return _EntryForm(
              groupId: groupId,
              memberId: memberId,
              type: type,
              group: group,
            );
          }
          return AsyncValueView(
            value: ref.watch(memberEntriesProvider(memberId)),
            builder: (entries) {
              final openLoans = loanStatuses(
                entries,
              ).where((status) => !status.isRepaid).toList();
              if (openLoans.isEmpty) {
                return Center(child: Text(l10n.noOpenLoans));
              }
              return _EntryForm(
                groupId: groupId,
                memberId: memberId,
                type: type,
                group: group,
                openLoans: openLoans,
              );
            },
          );
        },
      ),
    );
  }
}

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm({
    required this.groupId,
    required this.memberId,
    required this.type,
    required this.group,
    this.openLoans = const [],
  });

  final String groupId;
  final String memberId;
  final EntryType type;

  /// Null only if the group is not on this phone (should not happen).
  final Group? group;

  /// Only used for repayments.
  final List<LoanStatus> openLoans;

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String? _loanId = widget.openLoans.firstOrNull?.loan.id;
  late DateTime _meetingDate = _today;
  int? _shares;
  bool _saving = false;

  /// A group with a share price saves in shares, not in free amounts.
  bool get _buysShares =>
      widget.type == EntryType.contribution &&
      (widget.group?.sharePriceUgx ?? 0) > 0;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _typedAmount => int.tryParse(_amount.text);

  Future<void> _save() async {
    if (!_buysShares && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final saved = await saveOrExplain(context, _record);

    if (!mounted) return;
    if (saved) {
      context.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _record() {
    final ledger = ref.read(ledgerRepositoryProvider);
    final (groupId, memberId) = (widget.groupId, widget.memberId);
    final day = _meetingDate;
    return switch (widget.type) {
      EntryType.contribution => ledger.recordContribution(
        groupId: groupId,
        memberId: memberId,
        amountUgx: _buysShares ? null : _typedAmount,
        shares: _buysShares ? _shares : null,
        meetingDate: day,
      ),
      EntryType.socialFund => ledger.recordSocialFund(
        groupId: groupId,
        memberId: memberId,
        amountUgx: _typedAmount ?? 0,
        meetingDate: day,
      ),
      EntryType.fine => ledger.recordFine(
        groupId: groupId,
        memberId: memberId,
        amountUgx: _typedAmount ?? 0,
        meetingDate: day,
      ),
      EntryType.loan => ledger.issueLoan(
        groupId: groupId,
        memberId: memberId,
        amountUgx: _typedAmount ?? 0,
        meetingDate: day,
      ),
      _ => ledger.recordRepayment(
        groupId: groupId,
        memberId: memberId,
        loanId: _loanId!,
        amountUgx: _typedAmount ?? 0,
        meetingDate: day,
      ),
    };
  }

  Future<void> _pickDate() async {
    final created = widget.group?.createdAt.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      // Not before the group was made, and not in the future: the same
      // rules the ledger enforces.
      firstDate: created == null
          ? DateTime(2020)
          : DateTime(created.year, created.month, created.day),
      lastDate: _today,
    );
    if (picked != null) setState(() => _meetingDate = picked);
  }

  // Only checks that a whole number was typed. Every money rule (above
  // zero, not too large, not more than is owed) lives in the repository,
  // so there is exactly one place that decides.
  String? _validateAmount(String? text) {
    final l10n = AppLocalizations.of(context);
    if (text == null || text.isEmpty) return l10n.amountRequired;
    if (int.tryParse(text) == null) return l10n.ruleAmountTooLarge;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final group = widget.group;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.type == EntryType.repayment) ...[
            DropdownButtonFormField<String>(
              initialValue: _loanId,
              decoration: InputDecoration(labelText: l10n.whichLoanLabel),
              items: [
                for (final status in widget.openLoans)
                  DropdownMenuItem(
                    value: status.loan.id,
                    child: Text(
                      l10n.loanOption(status.loan.amountUgx, status.owedUgx),
                    ),
                  ),
              ],
              onChanged: (loanId) => setState(() => _loanId = loanId),
            ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.meetingDateLabel),
            subtitle: Text(
              l10n.entryDate(
                DateTime.utc(
                  _meetingDate.year,
                  _meetingDate.month,
                  _meetingDate.day,
                ),
              ),
            ),
            trailing: TextButton(
              onPressed: _pickDate,
              child: Text(l10n.changeDateButton),
            ),
          ),
          const SizedBox(height: 8),
          if (_buysShares)
            ShareChooser(
              selected: _shares,
              sharePriceUgx: group!.sharePriceUgx!,
              onSelected: (count) => setState(() => _shares = count),
            )
          else
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.amountLabel,
                // The amount in full, with separators, so an extra zero
                // shows.
                helperText: _typedAmount == null
                    ? null
                    : l10n.amountUgx(_typedAmount!),
                helperStyle: Theme.of(context).textTheme.titleMedium,
              ),
              onChanged: (_) => setState(() {}),
              validator: _validateAmount,
              onFieldSubmitted: (_) => _save(),
            ),
          if (widget.type == EntryType.loan &&
              (group?.monthlyChargePercent ?? 0) > 0) ...[
            const SizedBox(height: 16),
            Text(l10n.chargeInfo(group!.monthlyChargePercent)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}
