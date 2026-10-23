import 'package:flutter/material.dart';
import 'package:vsla_ledger/core/ledger/ledger_rule_broken.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// "How many shares?" as buttons 1 to 5, and what they come to in shillings.
/// Used wherever savings are recorded for a group that saves in shares.
class ShareChooser extends StatelessWidget {
  const ShareChooser({
    required this.selected,
    required this.sharePriceUgx,
    required this.onSelected,
    super.key,
  });

  final int? selected;
  final int sharePriceUgx;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sharesChooseLabel, style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var count = 1; count <= maxSharesPerMeeting; count++)
              ChoiceChip(
                label: Text('$count'),
                selected: selected == count,
                onSelected: (_) => onSelected(count),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.amountUgx(selected! * sharePriceUgx),
            style: text.titleMedium,
          ),
        ],
      ],
    );
  }
}
