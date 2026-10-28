import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/router.dart';
import 'package:vsla_ledger/app/theme.dart';
import 'package:vsla_ledger/core/providers.dart';
import 'package:vsla_ledger/l10n/app_localizations.dart';

class VslaApp extends ConsumerStatefulWidget {
  const VslaApp({super.key});

  @override
  ConsumerState<VslaApp> createState() => _VslaAppState();
}

class _VslaAppState extends ConsumerState<VslaApp> {
  // Made once per app, so tests that start a fresh app get a fresh router.
  late final GoRouter _router = createRouter(
    withDemoScreens: ref.read(showDemoScreensProvider),
  );

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  // The background sync uses its own connection to the database, so the
  // screens are not told when it changes something. Coming back to the
  // app, every screen reads the database again, and a sync starts.
  void _onResume() {
    final db = ref.read(appDatabaseProvider);
    db.markTablesUpdated(db.allTables);
    ref.read(syncTriggerProvider).appResumed();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching the trigger starts it and keeps it running while the app is
    // open: it syncs after each write and whenever the phone comes online.
    ref.watch(syncTriggerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      builder: (context, child) => _TestModeBanner(
        show: ref.watch(usesFakeBackendProvider),
        child: child!,
      ),
    );
  }
}

/// A strip across the top of every screen when the fake server is in use, so
/// nobody mistakes a test build for one that really syncs.
class _TestModeBanner extends StatelessWidget {
  const _TestModeBanner({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: colors.tertiaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                AppLocalizations.of(context).testModeBanner,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          // The banner already covers the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
