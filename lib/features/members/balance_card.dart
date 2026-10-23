import 'package:flutter/material.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Two big numbers: savings, and loans still to be repaid.
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _Figure(savingsLabel, balance.savingsUgx)),
                Expanded(
                  child: _Figure(loansLabel, balance.loansOutstandingUgx),
                ),
              ],
            ),
            // Two phones working offline can cancel a loan while a repayment
            // is recorded against it. Showing a negative number quietly
            // would hide that, so say it needs a look.
            if (balance.repaymentsWithoutLoanUgx > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  AppLocalizations.of(context).loansNeedChecking,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.amountUgx);

  final String label;
  final int amountUgx;

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
      ],
    );
  }
}
