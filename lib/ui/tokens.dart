import 'package:flutter/material.dart';

import 'perf.dart';

/// Colour tokens from docs/DESIGN_STYLE.md. Read with `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.canvasTop,
    required this.tray,
    required this.trayDeep,
    required this.card,
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.success,
  });

  final Color canvas;

  /// Top of the canvas gradient.
  final Color canvasTop;
  final Color tray;
  final Color trayDeep;
  final Color card;
  final Color ink;
  final Color onInk;
  final Color muted;
  final Color accent;

  /// Orange for surfaces that carry text (white on it passes AA, 4.8:1).
  final Color accentDeep;
  final Color onAccent;
  final Color success;

  static const light = AppTokens(
    canvas: Color(0xFFEDEDED),
    canvasTop: Color(0xFFE6E6E6),
    tray: Color(0xFFE2E2E2),
    trayDeep: Color(0xFFD9D9D9),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF111111),
    onInk: Color(0xFFFFFFFF),
    muted: Color(0xFF616161),
    accent: Color(0xFFDE6645),
    accentDeep: Color(0xFFC24C2C),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF2F9E6B),
  );

  static const dark = AppTokens(
    canvas: Color(0xFF121212),
    canvasTop: Color(0xFF181818),
    tray: Color(0xFF1C1C1C),
    trayDeep: Color(0xFF262626),
    card: Color(0xFF222222),
    ink: Color(0xFFF2F2F2),
    onInk: Color(0xFF111111),
    muted: Color(0xFF9A9A9A),
    accent: Color(0xFFDE6645),
    accentDeep: Color(0xFFC24C2C),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF4CC38A),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      canvas: c(canvas, other.canvas),
      canvasTop: c(canvasTop, other.canvasTop),
      tray: c(tray, other.tray),
      trayDeep: c(trayDeep, other.trayDeep),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      onInk: c(onInk, other.onInk),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      accentDeep: c(accentDeep, other.accentDeep),
      onAccent: c(onAccent, other.onAccent),
      success: c(success, other.success),
    );
  }
}

abstract final class Radii {
  static const card = 28.0;
  static const tile = 24.0;
  static const input = 20.0;
  static const pill = 999.0;
}

abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page gutter.
  static const gutter = 20.0;
}

abstract final class Shadows {
  // Blurred shadows are costly on weak GPUs; lite mode drops them.
  static List<BoxShadow> card(Brightness b) => b == Brightness.light && !Perf.lite
      ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8))]
      : const [];

  static List<BoxShadow> glow(Color accent) => Perf.lite
      ? const []
      : [
        BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
      ];

  /// The orange hero cards (big payment, split): a soft coloured lift.
  static List<BoxShadow> lifted(Color color) => Perf.lite
      ? const []
      : [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 28, offset: const Offset(0, 12))];

  /// Things that float over scrolling content, like the tab bar.
  static List<BoxShadow> get floating => Perf.lite
      ? const []
      : const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))];
}

extension TokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
