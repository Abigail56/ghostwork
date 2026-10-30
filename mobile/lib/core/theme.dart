import 'package:flutter/material.dart';

/// GhostWork design tokens (mirrors frontend/src/app/globals.css).
abstract final class Gw {
  static const canvas = Color(0xFF0B0D12);
  static const sidebar = Color(0xFF10131A);
  static const surface = Color(0xFF151923);
  static const elevated = Color(0xFF1B202B);
  static const hover = Color(0xFF212736);
  static const line = Color(0xFF282E3B);
  static const lineSubtle = Color(0xFF1E2330);
  static const fg = Color(0xFFF4F6FB);
  static const fgSecondary = Color(0xFFA0A8B8);
  static const fgMuted = Color(0xFF7D8597);
  static const violet = Color(0xFF8585FF);
  static const cyan = Color(0xFF55C5F2);
  static const success = Color(0xFF3DD68C);
  static const warning = Color(0xFFF5B74F);
  static const danger = Color(0xFFF2616B);
  static const queued = Color(0xFFB4B9FF);

  static const radius = 12.0;
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: Gw.violet,
    onPrimary: Gw.canvas,
    secondary: Gw.cyan,
    onSecondary: Gw.canvas,
    surface: Gw.surface,
    onSurface: Gw.fg,
    error: Gw.danger,
    onError: Gw.canvas,
    outline: Gw.line,
    outlineVariant: Gw.lineSubtle,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Gw.line),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Gw.canvas,
    canvasColor: Gw.canvas,
    dividerColor: Gw.lineSubtle,
    appBarTheme: const AppBarTheme(
      backgroundColor: Gw.canvas,
      foregroundColor: Gw.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Gw.fg),
    ),
    cardTheme: CardThemeData(
      color: Gw.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gw.radius),
        side: const BorderSide(color: Gw.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Gw.canvas,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: Gw.violet, width: 1.5)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: Gw.danger)),
      labelStyle: const TextStyle(color: Gw.fgSecondary),
      hintStyle: const TextStyle(color: Gw.fgMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Gw.violet,
        foregroundColor: Gw.canvas,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Gw.fg,
        side: const BorderSide(color: Gw.line),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Gw.sidebar,
      indicatorColor: Gw.violet.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, color: Gw.fgSecondary)),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? Gw.violet : Gw.fgMuted),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Gw.elevated,
      contentTextStyle: TextStyle(color: Gw.fg),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Gw.fg, letterSpacing: -0.3),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Gw.fg),
      bodyMedium: TextStyle(fontSize: 14, color: Gw.fg),
      bodySmall: TextStyle(fontSize: 12.5, color: Gw.fgMuted),
    ),
  );
}
