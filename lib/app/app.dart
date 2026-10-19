import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/router.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

class VslaApp extends StatefulWidget {
  const VslaApp({super.key});

  @override
  State<VslaApp> createState() => _VslaAppState();
}

class _VslaAppState extends State<VslaApp> {
  // Made once per app, so tests that start a fresh app get a fresh router.
  final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
