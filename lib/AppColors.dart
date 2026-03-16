import 'package:flutter/material.dart';

/// ============================================================
/// AppColors — GPS Workforce Monitor
/// Exact colors sampled from the GPS Workforce Logo:
///
///   ① Cyan-Teal orbit ring   →  #00BCD4 / #26C6DA
///   ② Green-Teal gradient    →  #4CAF82 / #43C89B
///   ③ Sky-Blue sphere        →  #4FC3F7
///   ④ Deep blue pin body     →  #1565C0 / #0D3B6E
///
///  Usage rule:
///   • Gradients & headers  → cyan (#00BCD4) ➜ greenTeal (#43C89B)
///   • Primary actions/FAB  → cyan (#00BCD4)
///   • Secondary/info chips → skyBlue (#4FC3F7)
///   • Success / location   → greenTeal (#4CAF82)
///   • Deep anchors/text    → navy (#0D3B6E)
/// ============================================================
class AppColors {
  AppColors._();

  // ── ① Cyan-Teal  (orbit ring — most prominent logo color) ─────────────────
  static const Color cyan        = Color(0xFF00BCD4); // exact logo cyan
  static const Color cyanBright  = Color(0xFF26C6DA); // lighter cyan highlight
  static const Color cyanLight   = Color(0xFFE0F7FA); // very light cyan surface
  static const Color cyanMid     = Color(0xFFB2EBF2); // mid tint for chips/badges

  // ── ② Green-Teal  (logo gradient base / location pin fill) ───────────────
  static const Color greenTeal   = Color(0xFF43C89B); // logo gradient end
  static const Color greenTealDk = Color(0xFF4CAF82); // slightly deeper green
  static const Color greenTealLt = Color(0xFFE0F4EE); // light green surface

  // ── ③ Sky-Blue  (sphere accent) ───────────────────────────────────────────
  static const Color skyBlue     = Color(0xFF4FC3F7); // exact sphere blue
  static const Color skyBlueDk   = Color(0xFF0288D1); // deeper sky for text
  static const Color skyBlueLt   = Color(0xFFE1F5FE); // lightest sky tint

  // ── ④ Deep Blue / Navy  (pin body outline, text anchors) ─────────────────
  static const Color primary     = Color(0xFF1565C0); // deep blue body
  static const Color primaryDark = Color(0xFF0D3B6E); // darkest navy outline
  static const Color primaryMid  = Color(0xFF1976D2); // mid blue

  // ── Gradients ─────────────────────────────────────────────────────────────

  /// 🎨 MAIN brand gradient — cyan → greenTeal (mirrors logo orbit sweep)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [cyan, cyanBright, greenTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Header / AppBar gradient — deep navy → cyan
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryDark, primary, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle page-bg gradient (very soft teal wash)
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFE8F8FB), Color(0xFFEAFAF4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Cyan → Sky button/FAB gradient
  static const LinearGradient cyanSkyGradient = LinearGradient(
    colors: [cyan, skyBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// GreenTeal → Cyan  (success states, clock-in buttons)
  static const LinearGradient successGradient = LinearGradient(
    colors: [greenTealDk, greenTeal, cyanBright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Surface / Background ──────────────────────────────────────────────────
  static const Color surface   = Color(0xFFEFF9FB); // very light cyan-white
  static const Color cardBg    = Color(0xFFFFFFFF);
  static const Color divider   = Color(0xFFB2EBF2); // cyan-tinted divider

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0A2540); // very dark navy
  static const Color textSecondary = Color(0xFF4A7A8A); // muted cyan-grey
  static const Color textOnDark    = Color(0xFFFFFFFF);
  static const Color textCyan      = Color(0xFF006064); // dark cyan for labels

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF43C89B); // greenTeal (matches logo!)
  static const Color warning  = Color(0xFFFFA726);
  static const Color error    = Color(0xFFE53935);
  static const Color info     = Color(0xFF4FC3F7); // skyBlue info

  // ── Icon-background tints  (chips, quick-action tiles) ───────────────────
  static const Color iconBgCyan      = Color(0xFFB2EBF2); // cyan tint
  static const Color iconBgGreenTeal = Color(0xFFC8F0E2); // greenTeal tint
  static const Color iconBgSky       = Color(0xFFB3E5FC); // sky tint
  static const Color iconBgNavy      = Color(0xFFD0E4F7); // navy tint

  // Back-compat aliases
  static const Color iconBgBlue = iconBgNavy;

  // ── Decoration helpers ─────────────────────────────────────────────────────

  /// Card shadow with cyan base
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: cyan.withOpacity(0.14),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Glow for FABs, primary buttons — cyan glow
  static List<BoxShadow> get cyanGlow => [
    BoxShadow(
      color: cyan.withOpacity(0.40),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// Glow for success/clock-in buttons — greenTeal glow
  static List<BoxShadow> get greenGlow => [
    BoxShadow(
      color: greenTeal.withOpacity(0.40),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  // Back-compat aliases so existing screens compile unchanged
  static List<BoxShadow> get primaryGlow => cyanGlow;
  static const LinearGradient primaryGradient = headerGradient;

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: cyan,
      primary: cyan,
      secondary: greenTeal,
      tertiary: skyBlue,
      surface: surface,
      error: error,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: textOnDark,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cyan,
        foregroundColor: textOnDark,
        elevation: 4,
        shadowColor: cyan,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      prefixIconColor: cyan,
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
        borderSide: BorderSide(color: cyan, width: 2),
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
        if (states.contains(WidgetState.selected)) return cyan;
        return Colors.transparent;
      }),
      side: BorderSide(color: cyan.withOpacity(0.5), width: 1.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: cyan),
    dividerColor: divider,
    fontFamily: 'Poppins',
  );
}