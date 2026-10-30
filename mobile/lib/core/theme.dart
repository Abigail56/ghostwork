import 'package:flutter/material.dart';

/// GhostWork design tokens — the same values as frontend/src/app/globals.css.
abstract final class Gw {
  // Surfaces
  static const canvas = Color(0xFF0B0D12);
  static const sidebar = Color(0xFF10131A);
  static const surface = Color(0xFF151923);
  static const elevated = Color(0xFF1B202B);
  static const hover = Color(0xFF212736);
  static const pressed = Color(0xFF272E3F);

  // Borders
  static const line = Color(0xFF282E3B);
  static const lineSubtle = Color(0xFF1E2330);
  static const lineStrong = Color(0xFF363D4D);
  static const focus = Color(0xFFA3A3FF);

  // Text
  static const fg = Color(0xFFF4F6FB);
  static const fgSecondary = Color(0xFFA0A8B8);
  static const fgMuted = Color(0xFF7D8597);
  static const fgDisabled = Color(0xFF555C6C);

  // Accents
  static const violet = Color(0xFF8585FF);
  static const violetHover = Color(0xFF9B9BFF);
  static const cyan = Color(0xFF55C5F2);
  static const violetSoft = Color(0x1F8585FF); // 12%
  static const cyanSoft = Color(0x1F55C5F2);

  // Status
  static const success = Color(0xFF3DD68C);
  static const successSoft = Color(0x1F3DD68C);
  static const warning = Color(0xFFF5B74F);
  static const warningSoft = Color(0x1FF5B74F);
  static const danger = Color(0xFFF2616B);
  static const dangerSoft = Color(0x1FF2616B);
  static const queued = Color(0xFFB4B9FF);
  static const dangerText = Color(0xFFFFB3B8);
  static const warningText = Color(0xFFFFD99A);
  static const infoText = Color(0xFFC9C9FF);
  static const successText = Color(0xFFA6F0CB);

  // Radii (rem → px at 16px): xs 4, sm 6, md 8, lg 12, xl 16
  static const rSm = 6.0;
  static const rMd = 8.0;
  static const rLg = 12.0;
  static const rXl = 16.0;

  static const fontSans = 'Geist';
  static const fontMono = 'GeistMono';
}

/// Type scale (frontend --text-* tokens).
abstract final class GwText {
  static const display = TextStyle(fontFamily: Gw.fontSans, fontSize: 40, height: 1.05, letterSpacing: -1.4, fontWeight: FontWeight.w600, color: Gw.fg);
  static const headline = TextStyle(fontFamily: Gw.fontSans, fontSize: 28, height: 1.12, letterSpacing: -0.6, fontWeight: FontWeight.w600, color: Gw.fg);
  static const title = TextStyle(fontFamily: Gw.fontSans, fontSize: 22, height: 1.25, letterSpacing: -0.33, fontWeight: FontWeight.w600, color: Gw.fg);
  static const section = TextStyle(fontFamily: Gw.fontSans, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: Gw.fg);
  static const body = TextStyle(fontFamily: Gw.fontSans, fontSize: 14, height: 1.5, color: Gw.fg);
  static const bodyMedium = TextStyle(fontFamily: Gw.fontSans, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: Gw.fg);
  static const meta = TextStyle(fontFamily: Gw.fontSans, fontSize: 13, height: 1.45, color: Gw.fgMuted);
  static const micro = TextStyle(fontFamily: Gw.fontSans, fontSize: 11, height: 1.3, color: Gw.fgMuted);
  static const eyebrow = TextStyle(fontFamily: Gw.fontSans, fontSize: 11, height: 1.3, letterSpacing: 0.88, fontWeight: FontWeight.w600, color: Gw.fgMuted);
  static const mono = TextStyle(fontFamily: Gw.fontMono, fontSize: 12, height: 1.5, color: Gw.fgSecondary);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
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
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Gw.fontSans,
    scaffoldBackgroundColor: Gw.canvas,
    canvasColor: Gw.canvas,
    dividerColor: Gw.lineSubtle,
    dividerTheme: const DividerThemeData(color: Gw.lineSubtle, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Gw.hover,
    hoverColor: Gw.hover,
    focusColor: Gw.violetSoft,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Gw.violet, selectionColor: Color(0x598585FF)),
    textTheme: const TextTheme(
      headlineSmall: GwText.title,
      titleMedium: GwText.section,
      bodyLarge: GwText.body,
      bodyMedium: GwText.body,
      bodySmall: GwText.meta,
      labelLarge: TextStyle(fontFamily: Gw.fontSans, fontSize: 14, fontWeight: FontWeight.w500),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Gw.sidebar, shape: RoundedRectangleBorder(), width: 272),
    dialogTheme: DialogThemeData(
      backgroundColor: Gw.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gw.rXl), side: const BorderSide(color: Gw.line)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Gw.elevated,
      surfaceTintColor: Colors.transparent,
      textStyle: GwText.body.copyWith(color: Gw.fgSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gw.rLg), side: const BorderSide(color: Gw.line)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Gw.elevated,
      contentTextStyle: GwText.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gw.rLg), side: const BorderSide(color: Gw.line)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Gw.surface, surfaceTintColor: Colors.transparent),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Gw.violet : Colors.transparent),
      checkColor: WidgetStateProperty.all(Gw.canvas),
      side: const BorderSide(color: Gw.lineStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Gw.violet),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStateProperty.all(const Color(0xFF2C3342)), thickness: WidgetStateProperty.all(4)),
  );
}
