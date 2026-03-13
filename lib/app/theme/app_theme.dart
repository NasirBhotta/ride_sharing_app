import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Palette ──────────────────────────────────────────────────
  static const Color _brand = Color(0xFF1A6BFF); // electric blue
  static const Color _brandDeep = Color(0xFF0047CC);
  static const Color _brandLight = Color(0xFFEAF0FF);

  static const Color _surfaceLight = Color(0xFFF8F9FC);
  static const Color _surfaceDark = Color(0xFF0F1117);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardDark = Color(0xFF181C26);

  static const Color _textPrimaryLight = Color(0xFF0D1021);
  static const Color _textSecondaryLight = Color(0xFF6B7280);
  static const Color _textPrimaryDark = Color(0xFFF1F3FA);
  static const Color _textSecondaryDark = Color(0xFF8B93A7);

  static const Color _errorColor = Color(0xFFE8344A);
  static const Color _successColor = Color(0xFF15BA78);

  // ── Radius ─────────────────────────────────────────────────────────
  static const double _radiusSm = 8;
  static const double _radiusMd = 14;
  static const double _radiusLg = 20;

  // ── Text Theme ─────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -1.2,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Input Decoration Theme ──────────────────────────────────────────
  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF2D3348) : const Color(0xFFDDE1ED);
    final fillColor =
        isDark ? const Color(0xFF1E2235) : const Color(0xFFF4F6FB);

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: _brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: _errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: _errorColor, width: 2),
      ),
      labelStyle: TextStyle(
        color: isDark ? _textSecondaryDark : _textSecondaryLight,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: _brand,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      errorStyle: const TextStyle(color: _errorColor, fontSize: 12),
    );
  }

  // ── Filled Button ───────────────────────────────────────────────────
  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        elevation: 0,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _brand.withOpacity(0.4);
          }
          if (states.contains(WidgetState.pressed)) return _brandDeep;
          return _brand;
        }),
      ),
    );
  }

  // ── Elevated Button ─────────────────────────────────────────────────
  static ElevatedButtonThemeData _elevatedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: _brand,
        backgroundColor: isDark ? const Color(0xFF1A2040) : _brandLight,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
          side: const BorderSide(color: _brand, width: 1.5),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── Outlined Button ─────────────────────────────────────────────────
  static OutlinedButtonThemeData _outlinedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? _textPrimaryDark : _textPrimaryLight,
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(
          color: isDark ? const Color(0xFF2D3348) : const Color(0xFFDDE1ED),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────
  static TabBarTheme _tabBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return TabBarTheme(
      labelColor: _brand,
      unselectedLabelColor: isDark ? _textSecondaryDark : _textSecondaryLight,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: _brand, width: 2.5),
      ),
      dividerColor: Colors.transparent,
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────
  static AppBarTheme _appBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: isDark ? _surfaceDark : Colors.white,
      foregroundColor: isDark ? _textPrimaryDark : _textPrimaryLight,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: Colors.black.withOpacity(0.06),
      titleTextStyle: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: isDark ? _textPrimaryDark : _textPrimaryLight,
      ),
      iconTheme: IconThemeData(
        color: isDark ? _textPrimaryDark : _textPrimaryLight,
        size: 22,
      ),
    );
  }

  // ── Card ─────────────────────────────────────────────────────────────
  static CardTheme _cardTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return CardTheme(
      color: isDark ? _cardDark : _cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLg),
        side: BorderSide(
          color: isDark ? const Color(0xFF252A3A) : const Color(0xFFECEFF7),
          width: 1,
        ),
      ),
    );
  }

  // ── Snack Bar ────────────────────────────────────────────────────────
  static SnackBarThemeData _snackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1E2E),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    );
  }

  // ── LIGHT THEME ──────────────────────────────────────────────────────
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.light,
        primary: _brand,
        onPrimary: Colors.white,
        secondary: _brandDeep,
        surface: _surfaceLight,
        error: _errorColor,
      ),
      scaffoldBackgroundColor: _surfaceLight,
      textTheme: _buildTextTheme(_textPrimaryLight, _textSecondaryLight),
      inputDecorationTheme: _inputTheme(Brightness.light),
      filledButtonTheme: _filledButtonTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(Brightness.light),
      outlinedButtonTheme: _outlinedButtonTheme(Brightness.light),
      tabBarTheme: _tabBarTheme(Brightness.light),
      appBarTheme: _appBarTheme(Brightness.light),
      cardTheme: _cardTheme(Brightness.light),
      snackBarTheme: _snackBarTheme(),
    );
    return base;
  }

  // ── DARK THEME ───────────────────────────────────────────────────────
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.dark,
        primary: _brand,
        onPrimary: Colors.white,
        secondary: _brandDeep,
        surface: _surfaceDark,
        error: _errorColor,
      ),
      scaffoldBackgroundColor: _surfaceDark,
      textTheme: _buildTextTheme(_textPrimaryDark, _textSecondaryDark),
      inputDecorationTheme: _inputTheme(Brightness.dark),
      filledButtonTheme: _filledButtonTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(Brightness.dark),
      outlinedButtonTheme: _outlinedButtonTheme(Brightness.dark),
      tabBarTheme: _tabBarTheme(Brightness.dark),
      appBarTheme: _appBarTheme(Brightness.dark),
      cardTheme: _cardTheme(Brightness.dark),
      snackBarTheme: _snackBarTheme(),
    );
    return base;
  }

  // ── Semantic helpers (use in widgets) ────────────────────────────────
  static Color brandColor(BuildContext context) => _brand;
  static Color successColor(BuildContext context) => _successColor;
  static Color errorColor(BuildContext context) => _errorColor;
  static Color subtleBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _cardDark
        : _cardLight;
  }
}
