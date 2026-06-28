import 'package:flutter/material.dart';

/// Finman dark design system.
///
/// One source of truth for colour, type, spacing, radius and elevation. Screens import these
/// tokens instead of hard-coding `Color(0x..)`, `EdgeInsets.all(16)` or `fontSize: 26`. The
/// donut/bar palette ([AppColors.series]) is shared with fl_chart via `colorAt(i)`.
class AppColors {
  AppColors._();

  // ── Background & surfaces (raised on a near-black canvas) ──────────────────
  static const Color background = Color(0xFF0E1116); // app canvas
  static const Color surface = Color(0xFF161A21); // cards, sheets
  static const Color surfaceHigh = Color(0xFF1E232C); // pressed / nested cards
  static const Color surfaceLow = Color(0xFF11151B); // recessed (chart wells)
  static const Color border = Color(0xFF262C36); // hairline dividers / outlines
  static const Color borderStrong = Color(0xFF333B47);

  // ── Brand & semantics ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF63C7FF); // sky — savings / brand / CTA
  static const Color onPrimary = Color(0xFF04222F);
  static const Color positive = Color(0xFF49D6A0); // income / credit
  static const Color negative = Color(0xFFFF6B85); // expense / debit
  static const Color warning = Color(0xFFFFC861); // needs-attention amber
  static const Color neutral = Color(0xFF8A93A3); // transfers / muted

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFFAEB6C4);
  static const Color textTertiary = Color(0xFF727B8A); // hints, captions
  static const Color textInverse = Color(0xFF0E1116); // on bright fills

  // ── Categorical series (colour-blind-friendly; index keeps a bucket's colour) ─
  static const List<Color> series = <Color>[
    Color(0xFF7C9EFF), // indigo
    Color(0xFFFF8FA3), // rose
    Color(0xFF5BD1B7), // teal
    Color(0xFFFFC861), // amber
    Color(0xFFB28DFF), // violet
    Color(0xFF7ED957), // green
    Color(0xFFFF9F68), // orange
    Color(0xFF63C7FF), // sky
  ];

  /// Stable colour for the i-th slice/account/bar segment.
  static Color seriesAt(int i) => series[i % series.length];
}

/// 4-pt spacing scale.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Corner radii.
class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius chipR = BorderRadius.all(Radius.circular(pill));
}

/// Soft, low-contrast shadows (dark UI relies on tone, not heavy drop shadows).
class AppElevation {
  AppElevation._();
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(color: Color(0x55000000), blurRadius: 28, offset: Offset(0, -8)),
  ];
}

/// Type scale (tabular figures for money are applied at the widget level).
class AppType {
  AppType._();
  static const String? family = null; // stock platform font

  static const TextStyle display = TextStyle(
      fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.textPrimary);
  static const TextStyle moneyLg = TextStyle(
      fontSize: 28, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.textPrimary);
  static const TextStyle title = TextStyle(
      fontSize: 18, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.textPrimary);
  static const TextStyle sectionLabel = TextStyle(
      fontSize: 12, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textTertiary);
  static const TextStyle body = TextStyle(fontSize: 15, height: 1.35, color: AppColors.textPrimary);
  static const TextStyle bodyMuted = TextStyle(fontSize: 15, height: 1.35, color: AppColors.textSecondary);
  static const TextStyle caption = TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.textTertiary);
  static const TextStyle moneyRow = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.positive,
      onSecondary: AppColors.textInverse,
      error: AppColors.negative,
      onError: AppColors.textInverse,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: AppType.display,
        titleLarge: AppType.title,
        titleMedium: AppType.title.copyWith(fontSize: 16),
        bodyLarge: AppType.body,
        bodyMedium: AppType.bodyMuted,
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodySmall: AppType.caption,
      ).apply(displayColor: AppColors.textPrimary, bodyColor: AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppType.title,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.xl))),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0xCC05070A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipR),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.md))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.md))),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}
