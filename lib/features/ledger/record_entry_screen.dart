import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/app/save_guard.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Records savings, a loan or a repayment for one member.
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
      EntryType.loan => l10n.issueLoanTitle,
      _ => l10n.recordRepaymentTitle,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: type != EntryType.repayment
          ? _AmountForm(groupId: groupId, memberId: memberId, type: type)
          : AsyncValueView(
              value: ref.watch(memberEntriesProvider(memberId)),
              builder: (entries) {
                final openLoans = loanStatuses(
                  entries,
                ).where((status) => !status.isRepaid).toList();
                if (openLoans.isEmpty) {
                  return Center(child: Text(l10n.noOpenLoans));
                }
                return _AmountForm(
                  groupId: groupId,
                  memberId: memberId,
                  type: type,
                  openLoans: openLoans,
                );
              },
            ),
    );
  }
}

class _AmountForm extends ConsumerStatefulWidget {
  const _AmountForm({
    required this.groupId,
    required this.memberId,
    required this.type,
    this.openLoans = const [],
  });

  final String groupId;
  final String memberId;
  final EntryType type;

  /// Only used for repayments.
  final List<LoanStatus> openLoans;

  @override
  ConsumerState<_AmountForm> createState() => _AmountFormState();
}

class _AmountFormState extends ConsumerState<_AmountForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late String? _loanId = widget.openLoans.firstOrNull?.loan.id;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final saved = await saveOrExplain(
      context,
      () => _record(int.parse(_amount.text)),
    );

    if (!mounted) return;
    if (saved) {
      context.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _record(int amountUgx) {
    final ledger = ref.read(ledgerRepositoryProvider);
    final (groupId, memberId) = (widget.groupId, widget.memberId);
    return switch (widget.type) {
      EntryType.contribution => ledger.recordContribution(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amountUgx,
      ),
      EntryType.loan => ledger.issueLoan(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amountUgx,
      ),
      _ => ledger.recordRepayment(
        groupId: groupId,
        memberId: memberId,
        loanId: _loanId!,
        amountUgx: amountUgx,
      ),
    };
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
          TextFormField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.amountLabel),
            validator: _validateAmount,
            onFieldSubmitted: (_) => _save(),
          ),
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
