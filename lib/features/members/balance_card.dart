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
    final scheme = Theme.of(context).colorScheme;
    final hasExtras = balance.socialFundUgx > 0 || balance.finesUgx > 0;
    final onCard = scheme.onPrimaryContainer;
    // With large text two columns no longer fit side by side.
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;

    Widget pair(Widget first, Widget second) => largeText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [first, const SizedBox(height: 12), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          );

    return Card(
      color: scheme.primaryContainer,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: onCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pair(
                _Figure(
                  savingsLabel,
                  balance.savingsUgx,
                  note: balance.sharesCount > 0
                      ? l10n.sharesBought(balance.sharesCount)
                      : null,
                  big: true,
                ),
                _Figure(
                  loansLabel,
                  balance.loansOutstandingUgx,
                  note: balance.chargesOwedUgx > 0
                      ? l10n.includesCharges(balance.chargesOwedUgx)
                      : null,
                  big: true,
                ),
              ),
              if (hasExtras) ...[
                Divider(height: 28, color: onCard.withValues(alpha: 0.2)),
                pair(
                  _Figure(l10n.socialFundLabel, balance.socialFundUgx),
                  _Figure(l10n.finesLabel, balance.finesUgx),
                ),
              ],
              // Two phones working offline can cancel a loan while a
              // repayment is recorded against it. Hiding that would hide a
              // real problem, so say it needs a look.
              if (balance.repaymentsWithoutLoanUgx > 0)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: scheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.loansNeedChecking,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.amountUgx, {this.note, this.big = false});

  final String label;
  final int amountUgx;
  final bool big;

  /// A small line under the amount, for example "includes UGX 10,000 ...".
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelLarge),
        const SizedBox(height: 2),
        // Long amounts shrink instead of overflowing on a narrow phone or
        // with large text.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context).amountUgx(amountUgx),
            style: (big ? text.headlineSmall : text.titleLarge)?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (note != null) Text(note!, style: text.bodySmall),
      ],
    );
  }
}
