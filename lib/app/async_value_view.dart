import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Shows a spinner while data loads, a message if it fails, and [builder]
/// once the data is there. Every screen uses this, so they all behave the
/// same way.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({required this.value, required this.builder, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text(AppLocalizations.of(context).loadError)),
    );
  }
}
