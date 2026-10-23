import 'package:flutter/material.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// The big numbers: savings, and loans still to be repaid. Social fund,
/// fines, shares and service charges appear only when there is something
/// to show, so a group that does not use them sees a simple card.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.savingsLabel,
    required this.loansLabel,
    required this.balance,
    super.key,
  });

  final String savingsLabel;
  final String loansLabel;
  final Balance balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final hasExtras = balance.socialFundUgx > 0 || balance.finesUgx > 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Figure(
                    savingsLabel,
                    balance.savingsUgx,
                    note: balance.sharesCount > 0
                        ? l10n.sharesBought(balance.sharesCount)
                        : null,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    loansLabel,
                    balance.loansOutstandingUgx,
                    note: balance.chargesOwedUgx > 0
                        ? l10n.includesCharges(balance.chargesOwedUgx)
                        : null,
                  ),
                ),
              ],
            ),
            if (hasExtras) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Figure(l10n.socialFundLabel, balance.socialFundUgx),
                  ),
                  Expanded(child: _Figure(l10n.finesLabel, balance.finesUgx)),
                ],
              ),
            ],
            // Two phones working offline can cancel a loan while a repayment
            // is recorded against it. Hiding that would hide a real problem,
            // so say it needs a look.
            if (balance.repaymentsWithoutLoanUgx > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.loansNeedChecking,
                  style: small?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.amountUgx, {this.note});

  final String label;
  final int amountUgx;

  /// A small line under the amount, for example "includes UGX 10,000 ...".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelLarge),
        Text(
          AppLocalizations.of(context).amountUgx(amountUgx),
          style: text.headlineSmall,
        ),
        if (note != null) Text(note!, style: text.bodySmall),
      ],
    );
  }
}
