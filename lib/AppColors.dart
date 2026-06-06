import 'package:flutter/material.dart';

/// ============================================================
/// AppColors — GPS Workforce Monitor
/// Theme aligned with Navbar gradient:
///
///   ① Teal Light (navbar gradient start)  →  #3DAF93
///   ② Teal Dark  (navbar gradient end)    →  #1A6E59
///   ③ Green Dot  (sync indicator)         →  #4ADE80
///
///  Usage rule:
///   • Gradients & AppBar/headers  → tealLight (#3DAF93) ➜ tealDark (#1A6E59)
///   • Primary actions/FAB         → tealLight (#3DAF93)
///   • Success / active / online   → greenDot (#4ADE80)
///   • Deep anchors / dark text    → tealDark (#1A6E59)
///   • Surfaces / backgrounds      → very light teal wash
/// ============================================================
class AppColors {
  AppColors._();

  // ── ① Teal Light  (Navbar gradient start — primary brand color) ───────────
  static const Color tealLight   = Color(0xFF3DAF93); // navbar gradient start
  static const Color tealMid     = Color(0xFF2E9E82); // mid teal
  static const Color tealLighter = Color(0xFF5DC4A8); // lighter teal highlight
  static const Color tealSurface = Color(0xFFE0F5F1); // very light teal surface
  static const Color tealTint    = Color(0xFFB2E8DC); // mid tint for chips/badges

  // ── ② Teal Dark  (Navbar gradient end — deep anchor color) ───────────────
  static const Color tealDark    = Color(0xFF1A6E59); // navbar gradient end
  static const Color tealDarker  = Color(0xFF124D3E); // darkest shade for text
  static const Color tealDarkLt  = Color(0xFFD0EEE8); // light surface from dark teal

  // ── ③ Green Dot  (Sync/online indicator) ──────────────────────────────────
  static const Color greenDot    = Color(0xFF4ADE80); // active/online indicator
  static const Color greenDotDk  = Color(0xFF22C55E); // deeper green for text
  static const Color greenDotLt  = Color(0xFFDCFCE7); // light green surface

  // ── Gradients ─────────────────────────────────────────────────────────────

  /// 🎨 MAIN brand gradient — matches Navbar exactly (tealLight → tealDark)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [tealLight, tealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Header / AppBar gradient — same as Navbar
  static const LinearGradient headerGradient = LinearGradient(
    colors: [tealLight, tealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle page-bg gradient (very soft teal wash)
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFEAF8F4), Color(0xFFE0F5F1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Teal Light → Teal Mid  (button/FAB gradient)
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [tealLight, tealMid],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// GreenDot → TealLight  (success states, clock-in buttons)
  static const LinearGradient successGradient = LinearGradient(
    colors: [greenDotDk, greenDot, tealLighter],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Surface / Background ──────────────────────────────────────────────────
  static const Color surface   = Color(0xFFEFF9F6); // very light teal-white
  static const Color cardBg    = Color(0xFFFFFFFF);
  static const Color divider   = Color(0xFFB2E8DC); // teal-tinted divider

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0D2B23); // very dark teal-navy
  static const Color textSecondary = Color(0xFF4A7A6E); // muted teal-grey
  static const Color textOnDark    = Color(0xFFFFFFFF);
  static const Color textTeal      = Color(0xFF1A6E59); // tealDark for labels

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF4ADE80); // greenDot (online/sync)
  static const Color warning  = Color(0xFFFFA726);
  static const Color error    = Color(0xFFE53935);
  static const Color info     = Color(0xFF3DAF93); // tealLight as info

  // ── Icon-background tints  (chips, quick-action tiles) ───────────────────
  static const Color iconBgTeal      = Color(0xFFB2E8DC); // teal tint
  static const Color iconBgGreen     = Color(0xFFDCFCE7); // greenDot tint
  static const Color iconBgDarkTeal  = Color(0xFFD0EEE8); // dark teal tint
  static const Color iconBgNeutral   = Color(0xFFD0EAE6); // neutral teal

  // Back-compat aliases (so existing screens don't break)
  static const Color cyan            = tealLight;
  static const Color cyanBright      = tealLighter;
  static const Color cyanLight       = tealSurface;
  static const Color cyanMid         = tealTint;
  static const Color greenTeal       = tealLight;
  static const Color greenTealDk     = tealMid;
  static const Color greenTealLt     = tealSurface;
  static const Color skyBlue         = tealLighter;
  static const Color skyBlueDk       = tealDark;
  static const Color skyBlueLt       = tealSurface;
  static const Color primary         = tealLight;
  static const Color primaryDark     = tealDark;
  static const Color primaryMid      = tealMid;
  static const Color iconBgCyan      = iconBgTeal;
  static const Color iconBgGreenTeal = iconBgGreen;
  static const Color iconBgSky       = iconBgDarkTeal;
  static const Color iconBgNavy      = iconBgNeutral;
  static const Color iconBgBlue      = iconBgNeutral;

  // ── Decoration helpers ─────────────────────────────────────────────────────

  /// Card shadow with teal base
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: tealLight.withOpacity(0.14),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Glow for FABs, primary buttons — teal glow
  static List<BoxShadow> get cyanGlow => [
    BoxShadow(
      color: tealLight.withOpacity(0.40),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// Glow for success/clock-in buttons — green glow
  static List<BoxShadow> get greenGlow => [
    BoxShadow(
      color: greenDot.withOpacity(0.40),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  // Back-compat aliases
  static List<BoxShadow> get primaryGlow => cyanGlow;
  static const LinearGradient primaryGradient = headerGradient;
  static const LinearGradient cyanSkyGradient = primaryButtonGradient;

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tealLight,
      primary: tealLight,
      secondary: greenDot,
      tertiary: tealLighter,
      surface: surface,
      error: error,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: tealDark,
      foregroundColor: textOnDark,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tealLight,
        foregroundColor: textOnDark,
        elevation: 4,
        shadowColor: tealLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      prefixIconColor: tealLight,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: divider, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: divider, width: 1.2),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: tealLight, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: error, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: error, width: 2),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) return tealLight;
        return Colors.transparent;
      }),
      side: BorderSide(color: tealLight.withOpacity(0.5), width: 1.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: tealLight),
    dividerColor: divider,
    fontFamily: 'Poppins',
  );
}