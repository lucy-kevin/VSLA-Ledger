import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/save_guard.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Makes a group. Besides its name, two rules are fixed now and cannot be
/// changed later: the monthly loan charge, and the price of a share.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

/// Many VSLAs charge 10% a month on loans, so that is the starting value.
const _usualMonthlyChargePercent = 10;

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _charge = TextEditingController(text: '$_usualMonthlyChargePercent');
  final _sharePrice = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _charge.dispose();
    _sharePrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repository = ref.read(groupRepositoryProvider);
    late final String groupId;
    final saved = await saveOrExplain(context, () async {
      final group = await repository.createGroup(
        _name.text,
        monthlyChargePercent: int.parse(_charge.text),
        sharePriceUgx: int.tryParse(_sharePrice.text),
      );
      groupId = group.id;
    });

    if (!mounted) return;
    if (saved) {
      // Replace this form with the new group, so "back" goes to the group list.
      context.pushReplacement('/groups/$groupId');
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createGroupTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.groupNameLabel),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.groupNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _charge,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.monthlyChargeLabel,
                helperText: l10n.monthlyChargeHelp,
                helperMaxLines: 3,
              ),
              validator: (value) {
                final percent = int.tryParse(value ?? '');
                return (percent == null || percent > 100)
                    ? l10n.monthlyChargeInvalid
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sharePrice,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.sharePriceLabel,
                helperText: l10n.sharePriceHelp,
                helperMaxLines: 2,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final price = int.tryParse(value);
                return (price == null || price < 1)
                    ? l10n.sharePriceInvalid
                    : null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}
