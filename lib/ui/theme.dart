import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.light ? AppTokens.light : AppTokens.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: brightness,
  ).copyWith(
    primary: t.ink,
    onPrimary: t.onInk,
    secondary: t.accent,
    onSecondary: t.onAccent,
    surface: t.canvas,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    surfaceContainerLowest: t.card,
    surfaceContainerLow: t.card,
    surfaceContainer: t.tray,
    surfaceContainerHigh: t.tray,
    surfaceContainerHighest: t.trayDeep,
    outline: t.trayDeep,
    outlineVariant: t.trayDeep,
  );

  // Bundled (assets/fonts) — the app has no internet permission.
  final base = ThemeData(brightness: brightness).textTheme.apply(fontFamily: 'PlusJakartaSans');
  final TextTheme text = base
      .copyWith(
        displaySmall: base.displaySmall?.copyWith(
            fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
        bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        bodySmall: base.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      )
      .apply(bodyColor: t.ink, displayColor: t.ink);

  const pill = StadiumBorder();
  const buttonSize = Size(64, 52);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: t.canvas,
    extensions: [t],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleMedium,
      foregroundColor: t.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.onInk,
        disabledBackgroundColor: t.trayDeep,
        disabledForegroundColor: t.muted,
        minimumSize: buttonSize,
        shape: pill,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink,
        minimumSize: const Size(48, 48),
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: 18),
      hintStyle: text.bodyLarge?.copyWith(color: t.muted),
      labelStyle: text.bodyLarge?.copyWith(color: t.muted),
      floatingLabelStyle: text.bodySmall?.copyWith(color: t.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: t.ink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: t.trayDeep, width: 2),
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.ink : Colors.transparent),
      checkColor: WidgetStatePropertyAll(t.onInk),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: t.onInk),
      shape: pill,
      insetPadding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.ink),
  );
}
