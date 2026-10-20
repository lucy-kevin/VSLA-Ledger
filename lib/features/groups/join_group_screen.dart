import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/core/groups/group_repository.dart';
import 'package:vsla_ledger/core/groups/join_group.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Joins a group made on another phone, using its join code.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _problem;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _joining = true;
      _problem = null;
    });

    final result = await ref.read(groupJoinerProvider).join(_code.text);
    if (!mounted) return;

    switch (result) {
      case Joined(:final group):
        // Replace this form with the group, so "back" goes to the list.
        context.pushReplacement('/groups/${group.id}');
      case InvalidJoinCode():
        setState(() => _problem = l10n.joinCodeInvalid);
      case GroupNotFound():
        setState(() => _problem = l10n.joinGroupNotFound);
      case JoinNeedsConnection():
        setState(() => _problem = l10n.joinGroupNeedsConnection);
    }
    if (result is! Joined) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinGroupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.joinGroupHelp),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            // Room for a space or dash, which are ignored.
            maxLength: joinCodeLength + 2,
            decoration: InputDecoration(
              labelText: l10n.joinCodeLabel,
              errorText: _problem,
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _joining ? null : _join,
            child: Text(l10n.joinButton),
          ),
        ],
      ),
    );
  }
}
