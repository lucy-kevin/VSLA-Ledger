import 'package:flutter/material.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';

/// The app's green. Everything else in the colour scheme comes from it.
const brandColor = Color(0xFF2E7D32);

/// One theme for light and dark, so every screen looks like the same app.
///
/// Touch targets are large on purpose: the treasurer often works outdoors,
/// with one hand, in bright light.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: scheme);
  final text = base.textTheme;
  const roundedLarge = BorderRadius.all(Radius.circular(20));
  const roundedMedium = BorderRadius.all(Radius.circular(14));

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: roundedLarge),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: const RoundedRectangleBorder(borderRadius: roundedMedium),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const RoundedRectangleBorder(borderRadius: roundedMedium),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: const OutlineInputBorder(
        borderRadius: roundedMedium,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: roundedMedium,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: roundedMedium,
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: roundedMedium),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: roundedMedium),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: roundedLarge),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(borderRadius: roundedMedium),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: text.titleMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
    ),
  );
}

/// How each kind of money event looks: the same icon and colour on every
/// screen, so a treasurer learns them once. The words always stay beside
/// them, because colour alone is not enough for everyone.
class EntryStyle {
  const EntryStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// The look of [type]: see [EntryStyle].
EntryStyle entryStyleOf(BuildContext context, EntryType type) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (type) {
    EntryType.contribution => EntryStyle(
      icon: Icons.savings_outlined,
      color: dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
    ),
    EntryType.loan => EntryStyle(
      icon: Icons.north_east,
      color: dark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
    ),
    EntryType.repayment => EntryStyle(
      icon: Icons.south_west,
      color: dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
    ),
    EntryType.socialFund => EntryStyle(
      icon: Icons.volunteer_activism_outlined,
      color: dark ? const Color(0xFFBA68C8) : const Color(0xFF6A1B9A),
    ),
    EntryType.fine => EntryStyle(
      icon: Icons.gavel,
      color: dark ? const Color(0xFFE57373) : const Color(0xFFC62828),
    ),
    EntryType.correction => EntryStyle(
      icon: Icons.undo,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  };
}
