import 'package:flutter/material.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

/// Shown instead of the app when it cannot start, for example when the
/// chosen backend is not set up. Better a clear reason on screen than a
/// blank launch screen that never goes away.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.startupErrorTitle)),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.startupErrorHelp),
                const SizedBox(height: 16),
                SelectableText(error.toString()),
              ],
            ),
          );
        },
      ),
    );
  }
}
