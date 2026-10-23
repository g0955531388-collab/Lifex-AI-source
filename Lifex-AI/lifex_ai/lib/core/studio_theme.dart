/// =============================================================
/// Lifex-AI — مظهر استوديو الشبكة
/// الألوان من واجهة google-studio: أردوازي، فيروزي، نيلي.
/// لا يحمل أسماء ولا قراءات افتراضية.
/// =============================================================
library lifex_ai.core.studio_theme;

import 'package:flutter/material.dart';

enum StudioAppearance { dark, light, contrast }

class StudioTheme {
  const StudioTheme._();

  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);
  static const teal = Color(0xFF0D9488);
  static const tealBright = Color(0xFF14B8A6);
  static const indigo = Color(0xFF4F46E5);
  static const rose = Color(0xFFE11D48);
  static const purple = Color(0xFF9333EA);
  static const purpleSoft = Color(0xFFD8B4FE);
  static const amber = Color(0xFFFBBF24);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: slate50,
        surface: Colors.white,
        onSurface: slate900,
        primary: teal,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: slate950,
        surface: slate900,
        onSurface: slate100,
        primary: tealBright,
      );

  static ThemeData contrast() => _build(
        brightness: Brightness.dark,
        background: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        primary: const Color(0xFFFFFF00),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color primary,
  }) {
    final onPrimary =
        primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final border = brightness == Brightness.dark ? slate800 : slate200;
    final field = brightness == Brightness.dark ? slate800 : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: indigo,
      onSecondary: Colors.white,
      error: rose,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      outline: border,
    );
    final radius = BorderRadius.circular(16);
    final outline = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: border),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: outline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: border)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        shape: outline,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark ? slate800 : slate900,
        contentTextStyle: TextStyle(
            color: brightness == Brightness.dark ? slate100 : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: outline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: primary, width: 2)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: onSurface,
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: primary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      chipTheme: ChipThemeData(
        backgroundColor: field,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.45);
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return onSurface;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
