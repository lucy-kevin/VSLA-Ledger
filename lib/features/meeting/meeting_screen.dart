import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/app/async_value_view.dart';
import 'package:vsla_ledger/app/save_guard.dart';
import 'package:vsla_ledger/core/ledger/balance_calculator.dart';
import 'package:vsla_ledger/core/ledger/loan_status.dart';
import 'package:vsla_ledger/core/models/balance.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/group.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/member.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/features/ledger/share_chooser.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Running a meeting: every member in one list, and a quick way to record
/// their savings, social fund and fines without leaving the screen.
///
/// What is shown is only what belongs to the chosen meeting day (today unless
/// changed), so a treasurer can also catch up on a meeting from last week.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  late DateTime _day = _today;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDay(Group group) async {
    final created = group.createdAt.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(created.year, created.month, created.day),
      lastDate: _today,
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AsyncValueView(
      value: ref.watch(groupProvider(widget.groupId)),
      builder: (group) => Scaffold(
        appBar: AppBar(title: Text(l10n.meetingTitle)),
        body: group == null
            ? Center(child: Text(l10n.loadError))
            : AsyncValueView(
                value: ref.watch(membersProvider(widget.groupId)),
                builder: (members) => AsyncValueView(
                  value: ref.watch(groupEntriesProvider(widget.groupId)),
                  builder: (entries) => _body(group, members, entries),
                ),
              ),
      ),
    );
  }

  Widget _body(Group group, List<Member> members, List<LedgerEntry> entries) {
    final l10n = AppLocalizations.of(context);
    final day = DateTime.utc(_day.year, _day.month, _day.day);

    // Cancelled entries are dropped first, whatever day the cancelling was
    // typed on, then only this meeting's are kept.
    final thisMeeting = [
      for (final entry in entriesThatCount(entries))
        if (entry.meetingDay == day) entry,
    ];
    final totals = computeBalance(thisMeeting);
    final savedMembers = {
      for (final entry in thisMeeting)
        if (entry.type == EntryType.contribution) entry.memberId,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          leading: const Icon(Icons.event),
          title: Text(l10n.meetingDateLabel),
          subtitle: Text(l10n.entryDate(day)),
          trailing: TextButton(
            onPressed: () => _pickDay(group),
            child: Text(l10n.changeDateButton),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.meetingSavedCount(savedMembers.length, members.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(_summary(totals) ?? l10n.meetingNothingYet),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.noMembersYet),
          ),
        for (final member in members)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(member.name),
            subtitle: Text(
              _summary(
                    computeBalance([
                      for (final e in thisMeeting)
                        if (e.memberId == member.id) e,
                    ]),
                  ) ??
                  l10n.meetingNothingYet,
            ),
            trailing: FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(l10n.meetingRecordButton),
              onPressed: () => _record(group, member, day),
            ),
          ),
      ],
    );
  }

  /// "Savings UGX 6,000 · Fines UGX 500", or null if nothing was recorded.
  String? _summary(Balance totals) {
    final l10n = AppLocalizations.of(context);
    final shares = totals.sharesCount > 0
        ? ' (${l10n.sharesBought(totals.sharesCount)})'
        : '';
    final parts = [
      if (totals.savingsUgx > 0)
        '${l10n.savingsLabel} ${l10n.amountUgx(totals.savingsUgx)}$shares',
      if (totals.socialFundUgx > 0)
        '${l10n.socialFundLabel} ${l10n.amountUgx(totals.socialFundUgx)}',
      if (totals.finesUgx > 0)
        '${l10n.finesLabel} ${l10n.amountUgx(totals.finesUgx)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _record(Group group, Member member, DateTime day) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
          // Keep the form above the keyboard.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _QuickEntrySheet(group: group, member: member, day: day),
        ),
      );
}

/// The small form for one member at the meeting. Stays open for the next
/// record only if the treasurer chooses; it closes after each save.
class _QuickEntrySheet extends ConsumerStatefulWidget {
  const _QuickEntrySheet({
    required this.group,
    required this.member,
    required this.day,
  });

  final Group group;
  final Member member;

  /// The meeting day, as UTC midnight.
  final DateTime day;

  @override
  ConsumerState<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<_QuickEntrySheet> {
  final _amount = TextEditingController();
  EntryType _type = EntryType.contribution;
  int? _shares;
  String? _problem;
  bool _saving = false;

  bool get _buysShares =>
      _type == EntryType.contribution && (widget.group.sharePriceUgx ?? 0) > 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _problem = null;
    });

    final problem = await saveOrMessage(context, _record);

    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _problem = problem;
      });
    }
  }

  Future<void> _record() {
    final ledger = ref.read(ledgerRepositoryProvider);
    final amount = int.tryParse(_amount.text) ?? 0;
    final (groupId, memberId) = (widget.group.id, widget.member.id);
    // The meeting day as a plain date, which is what the ledger wants.
    final day = DateTime(widget.day.year, widget.day.month, widget.day.day);

    return switch (_type) {
      EntryType.contribution when _buysShares => ledger.recordContribution(
        groupId: groupId,
        memberId: memberId,
        shares: _shares,
        meetingDate: day,
      ),
      EntryType.contribution => ledger.recordContribution(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amount,
        meetingDate: day,
      ),
      EntryType.socialFund => ledger.recordSocialFund(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amount,
        meetingDate: day,
      ),
      _ => ledger.recordFine(
        groupId: groupId,
        memberId: memberId,
        amountUgx: amount,
        meetingDate: day,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typedAmount = int.tryParse(_amount.text);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.quickEntryTitle(widget.member.name),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<EntryType>(
              segments: [
                ButtonSegment(
                  value: EntryType.contribution,
                  label: Text(l10n.recordContributionButton),
                ),
                ButtonSegment(
                  value: EntryType.socialFund,
                  label: Text(l10n.recordSocialFundButton),
                ),
                ButtonSegment(
                  value: EntryType.fine,
                  label: Text(l10n.recordFineButton),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (chosen) => setState(() {
                _type = chosen.single;
                _problem = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_buysShares)
              ShareChooser(
                selected: _shares,
                sharePriceUgx: widget.group.sharePriceUgx!,
                onSelected: (count) => setState(() => _shares = count),
              )
            else
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.amountLabel,
                  helperText: typedAmount == null
                      ? null
                      : l10n.amountUgx(typedAmount),
                  helperStyle: Theme.of(context).textTheme.titleMedium,
                ),
                onChanged: (_) => setState(() => _problem = null),
                onSubmitted: (_) => _save(),
              ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _problem!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
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
