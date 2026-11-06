import 'package:flutter/widgets.dart';

import 'tokens.g.dart';

/// Onyx colour roles. The values live in tokens/onyx.tokens.json (generated into tokens.g.dart). Cool monochrome first: blue-grey ink on a cool canvas, a single accent kept
/// for focus and selection, and three status colours that only ever mean
/// status (never decoration).
@immutable
class OColors {
  const OColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.onInk,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.scrim,
  });

  /// The page behind everything.
  final Color canvas;

  /// Cards, sheets, dialogs: objects that sit on the canvas.
  final Color surface;

  /// Inset areas, fields, inactive tracks; a step darker than the canvas.
  final Color raised;

  /// Hairlines and card borders.
  final Color line;

  /// Borders that must read at a glance (unchecked boxes, outlined chips).
  final Color lineStrong;

  /// Primary text and the primary button.
  final Color ink;

  /// Secondary text: captions, subtitles, metadata.
  final Color inkSoft;

  /// Tertiary text: placeholders, disabled labels.
  final Color inkFaint;

  /// Text and icons on [ink].
  final Color onInk;

  final Color accent;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color warning;

  /// Behind sheets and dialogs.
  final Color scrim;

  /// A wash of [accent] for selected backgrounds.
  Color get accentSoft => accent.withValues(alpha: 0.12);

  /// A wash of any status colour for pills and badges.
  Color soft(Color c) => c.withValues(alpha: 0.12);

  static const light = OColors(
    canvas: OTokenLight.canvas,
    surface: OTokenLight.surface,
    raised: OTokenLight.raised,
    line: OTokenLight.line,
    lineStrong: OTokenLight.lineStrong,
    ink: OTokenLight.ink,
    inkSoft: OTokenLight.inkSoft,
    inkFaint: OTokenLight.inkFaint,
    onInk: OTokenLight.onInk,
    accent: OTokenLight.accent,
    onAccent: OTokenLight.onAccent,
    positive: OTokenLight.positive,
    negative: OTokenLight.negative,
    warning: OTokenLight.warning,
    scrim: OTokenLight.scrim,
  );

  static const dark = OColors(
    canvas: OTokenDark.canvas,
    surface: OTokenDark.surface,
    raised: OTokenDark.raised,
    line: OTokenDark.line,
    lineStrong: OTokenDark.lineStrong,
    ink: OTokenDark.ink,
    inkSoft: OTokenDark.inkSoft,
    inkFaint: OTokenDark.inkFaint,
    onInk: OTokenDark.onInk,
    accent: OTokenDark.accent,
    onAccent: OTokenDark.onAccent,
    positive: OTokenDark.positive,
    negative: OTokenDark.negative,
    warning: OTokenDark.warning,
    scrim: OTokenDark.scrim,
  );
}

/// 4-pt spacing scale.
abstract final class OSpace {
  static const xxs = OTokenSpace.xxs;
  static const xs = OTokenSpace.xs;
  static const sm = OTokenSpace.sm;
  static const md = OTokenSpace.md;
  static const lg = OTokenSpace.lg;
  static const xl = OTokenSpace.xl;
  static const xxl = OTokenSpace.xxl;
  static const xxxl = OTokenSpace.xxxl;
  static const huge = OTokenSpace.huge;

  /// Horizontal page gutter.
  static const gutter = OTokenSpace.gutter;
}

/// Corner radii. Cards and sheets use the smooth (superellipse) shape.
abstract final class ORadius {
  static const xs = OTokenRadius.xs;
  static const sm = OTokenRadius.sm;
  static const md = OTokenRadius.md;
  static const lg = OTokenRadius.lg;
  static const xl = OTokenRadius.xl;
  static const pill = OTokenRadius.pill;

  static ShapeBorder smooth(double r, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(r),
        side: side,
      );
}

/// Durations and curves. Everything eases out; nothing bounces except a
/// released drag.
abstract final class OMotion {
  static const fast = OTokenMotion.fast;
  static const base = OTokenMotion.base;
  static const slow = OTokenMotion.slow;

  static const standard = OTokenMotion.standard;
  static const emphasized = OTokenMotion.emphasized;
  static const exit = OTokenMotion.exit;

  /// Zero when the system asks for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// Shadows are rare: borders separate things; only floating layers lift.
abstract final class OShadow {
  static List<BoxShadow> floating(Brightness b) => b == Brightness.light
      ? OTokenShadow.floatingLight
      : OTokenShadow.floatingDark;

  static List<BoxShadow> subtle(Brightness b) => b == Brightness.light
      ? OTokenShadow.subtleLight
      : OTokenShadow.subtleDark;
}
