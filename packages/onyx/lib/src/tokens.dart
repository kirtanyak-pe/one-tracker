import 'package:flutter/widgets.dart';

/// Onyx colour roles. Monochrome first: ink on canvas, a single accent kept
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
    canvas: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEFEFEC),
    line: Color(0xFFE7E7E3),
    lineStrong: Color(0xFFCFCFCA),
    ink: Color(0xFF0D0D0F),
    inkSoft: Color(0xFF5F5F66),
    inkFaint: Color(0xFF9D9DA4),
    onInk: Color(0xFFFFFFFF),
    accent: Color(0xFF5B5BD6),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF16955A),
    negative: Color(0xFFDC3E42),
    warning: Color(0xFFC77D0A),
    scrim: Color(0x66000000),
  );

  static const dark = OColors(
    canvas: Color(0xFF09090B),
    surface: Color(0xFF151517),
    raised: Color(0xFF1D1D20),
    line: Color(0xFF242428),
    lineStrong: Color(0xFF34343A),
    ink: Color(0xFFF4F4F5),
    inkSoft: Color(0xFFA1A1AA),
    inkFaint: Color(0xFF68686F),
    onInk: Color(0xFF0D0D0F),
    accent: Color(0xFF8587F2),
    onAccent: Color(0xFF0D0D0F),
    positive: Color(0xFF3DD68C),
    negative: Color(0xFFFF6369),
    warning: Color(0xFFF5B544),
    scrim: Color(0x99000000),
  );
}

/// 4-pt spacing scale.
abstract final class OSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;

  /// Horizontal page gutter.
  static const gutter = 20.0;
}

/// Corner radii. Cards and sheets use the smooth (superellipse) shape.
abstract final class ORadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;

  static ShapeBorder smooth(double r, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(r), side: side);
}

/// Durations and curves. Everything eases out; nothing bounces except a
/// released drag.
abstract final class OMotion {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 380);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const emphasized = Cubic(0.05, 0.7, 0.1, 1);
  static const exit = Cubic(0.3, 0, 1, 1);

  /// Zero when the system asks for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// Shadows are rare: borders separate things; only floating layers lift.
abstract final class OShadow {
  static List<BoxShadow> floating(Brightness b) => b == Brightness.light
      ? const [
          BoxShadow(color: Color(0x14000000), blurRadius: 32, offset: Offset(0, 12)),
          BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1)),
        ]
      : const [BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 12))];

  static List<BoxShadow> subtle(Brightness b) => b == Brightness.light
      ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))]
      : const [];
}
