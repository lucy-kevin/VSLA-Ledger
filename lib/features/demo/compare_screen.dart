import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vsla_ledger/core/clock.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/core/models/ledger_entry.dart';
import 'package:vsla_ledger/core/models/outbox_item.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// TALK DEMO ONLY. Built only with `--dart-define=DEMO=true`.
///
/// Saves the same contribution two ways, side by side, and times each:
/// - our way: save on the phone, sync later;
/// - the "online-only" way: send to the server, and only show it as saved
///   when the server answers.
///
/// The second way breaks the app's first rule (screens never talk to the
/// network) ON PURPOSE, to show why the rule exists. Do not copy it into
/// any other screen. See CLAUDE.md §3, rule 1.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({
    required this.groupId,
    required this.memberId,
    required this.slowNetworkDelay,
    super.key,
  });

  final String groupId;
  final String memberId;

  /// The demo delay, shown on screen so nobody thinks it is hidden.
  final Duration slowNetworkDelay;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

const _demoAmountUgx = 1000;

class _CompareScreenState extends ConsumerState<CompareScreen> {
  _Outcome _local = const _Idle();
  _Outcome _online = const _Idle();

  Future<void> _saveOnPhone() async {
    setState(() => _local = const _Waiting());
    final stopwatch = Stopwatch()..start();

    _Outcome outcome;
    try {
      // Needs a group that saves amounts. A group that saves in shares
      // refuses a plain amount, and the demo then shows "not saved".
      await ref
          .read(ledgerRepositoryProvider)
          .recordContribution(
            groupId: widget.groupId,
            memberId: widget.memberId,
            amountUgx: _demoAmountUgx,
          );
      outcome = _Saved(stopwatch.elapsed);
    } on Exception {
      outcome = _Failed(stopwatch.elapsed);
    }

    if (mounted) setState(() => _local = outcome);
  }

  // The old way, on purpose: the screen waits for the network.
  Future<void> _waitForServer() async {
    setState(() => _online = const _Waiting());
    final stopwatch = Stopwatch()..start();
    final entry = LedgerEntry(
      id: const Uuid().v4(),
      groupId: widget.groupId,
      memberId: widget.memberId,
      type: EntryType.contribution,
      amountUgx: _demoAmountUgx,
      createdAt: nowUtc(),
      deviceId: ref.read(deviceIdProvider),
    );

    _Outcome outcome;
    try {
      final accepted = await ref.read(ledgerRemoteProvider).push([
        OutboxItem(
          id: 0,
          entityType: OutboxEntityType.ledgerEntry,
          entityId: entry.id,
          payloadJson: jsonEncode(entry.toJson()),
          createdAt: entry.createdAt,
        ),
      ]);
      if (accepted.isEmpty) {
        outcome = _Failed(stopwatch.elapsed);
      } else {
        // Only now, after the server said yes, does it appear on the phone.
        await ref.read(appDatabaseProvider).ledgerDao.insertEntry(entry);
        outcome = _Saved(stopwatch.elapsed);
      }
    } on Exception {
      outcome = _Failed(stopwatch.elapsed);
    }

    if (mounted) setState(() => _online = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final delay = widget.slowNetworkDelay;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.compareTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.compareIntro),
          if (delay > Duration.zero) ...[
            const SizedBox(height: 8),
            Text(
              l10n.compareDelay(_seconds(delay)),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          const SizedBox(height: 24),
          _Lane(
            button: FilledButton.icon(
              onPressed: _local is _Waiting ? null : _saveOnPhone,
              icon: const Icon(Icons.phone_android),
              label: Text(l10n.compareLocalButton),
            ),
            caption: l10n.compareLocalCaption,
            outcome: _local,
          ),
          const SizedBox(height: 24),
          _Lane(
            button: FilledButton.tonalIcon(
              onPressed: _online is _Waiting ? null : _waitForServer,
              icon: const Icon(Icons.cloud_upload),
              label: Text(l10n.compareOnlineButton),
            ),
            caption: l10n.compareOnlineCaption,
            outcome: _online,
          ),
        ],
      ),
    );
  }
}

String _seconds(Duration duration) =>
    (duration.inMilliseconds / 1000).toStringAsFixed(2);

/// One way of saving: its button, what it does, and how it went.
class _Lane extends StatelessWidget {
  const _Lane({
    required this.button,
    required this.caption,
    required this.outcome,
  });

  final Widget button;
  final String caption;
  final _Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button,
        const SizedBox(height: 4),
        Text(caption, style: text.bodySmall),
        const SizedBox(height: 8),
        switch (outcome) {
          _Idle() => const SizedBox(height: 24),
          _Waiting() => Row(
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(l10n.compareWaiting),
            ],
          ),
          _Saved(:final took) => Text(
            l10n.compareSaved(_seconds(took)),
            style: text.titleMedium,
          ),
          _Failed(:final took) => Text(
            l10n.compareFailed(_seconds(took)),
            style: text.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        },
      ],
    );
  }
}

sealed class _Outcome {
  const _Outcome();
}

class _Idle extends _Outcome {
  const _Idle();
}

class _Waiting extends _Outcome {
  const _Waiting();
}

class _Saved extends _Outcome {
  const _Saved(this.took);

  final Duration took;
}

class _Failed extends _Outcome {
  const _Failed(this.took);

  final Duration took;
}
