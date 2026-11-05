import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'pressable.dart';
import 'theme.dart';

/// How pressable things look, app-wide (`OApp(finish:)`). Colours stay the
/// same; the finish adds light and depth on top of them.
enum OFinish {
  /// Plain fills.
  flat,

  /// Lemonnade's raised look: a faint sheen, a light top edge and a dark
  /// bottom edge (lit from above), and a small drop shadow.
  raised,

  /// Soft and pillowy: lit from the top left, with a light and a dark
  /// shadow either side, so things rise out of the canvas.
  pillow,

  /// Frosted: a slightly see-through fill, a gloss on the top half, a bright
  /// rim and a wide soft shadow. The tab bar blurs what's behind it.
  glass,

  /// Solid fills cast a glow in their own colour.
  glow,
}

/// How much a finished thing stands out (Lemonnade's raised levels).
enum ODepth {
  /// Solid fills: main buttons, a selected pill or chip.
  strong,

  /// Light or outlined surfaces: secondary buttons, a segmented thumb.
  soft,
}

/// A [shape] filled with [color], in the app's finish. Pushed in while the
/// nearest [OPressable] is held.
class OFinishBox extends StatelessWidget {
  const OFinishBox({
    super.key,
    required this.color,
    this.depth = ODepth.strong,
    this.shape = const StadiumBorder(),
    this.finish,
    this.child,
  });

  final Color color;
  final ODepth depth;

  /// Its side, if any, is drawn as a hairline on top.
  final ShapeBorder shape;

  /// Overrides the app's finish (previews).
  final OFinish? finish;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = context.onyx;
    return CustomPaint(
      painter: _FinishPainter(
        color: color,
        shape: shape,
        look: (finish ?? theme.finish, depth, theme.isDark),
        recipe: _Recipe.of(finish ?? theme.finish, depth, color, theme.isDark, theme.colors.accent),
        pressed: OPressable.isPressed(context),
      ),
      child: child,
    );
  }
}

/// What a finish adds over a fill.
class _Recipe {
  const _Recipe({
    this.fillAlpha = 1,
    this.sheen = const [],
    this.sheenStops,
    this.highlight,
    this.shade,
    this.rim,
    this.shadows = const [],
    this.pressedShade = const Color(0x40000000),
  });

  final double fillAlpha;
  final List<Color> sheen;
  final List<double>? sheenStops;

  /// 1px light along the top edge, inside.
  final Color? highlight;

  /// 1px dark along the bottom edge, inside.
  final Color? shade;

  /// 1px light all the way round, inside.
  final Color? rim;
  final List<BoxShadow> shadows;
  final Color pressedShade;

  static const _clear = Color(0x00FFFFFF);
  static Color _w(double a) => Color.fromRGBO(255, 255, 255, a);
  static Color _b(double a) => Color.fromRGBO(0, 0, 0, a);

  static _Recipe of(OFinish finish, ODepth depth, Color fill, bool dark, Color accent) {
    final strong = depth == ODepth.strong;
    // A white sheen can't show on a white fill: light it from above instead.
    final whiteFill = fill.computeLuminance() > 0.85;
    switch (finish) {
      case OFinish.flat:
        return const _Recipe();
      case OFinish.raised:
        if (strong) {
          return _Recipe(
            sheen: [_w(0.20), _b(0.15)],
            highlight: _w(0.25),
            shade: _b(0.30),
            shadows: [
              BoxShadow(color: _b(0.20), blurRadius: 4, offset: const Offset(0, 1)),
              BoxShadow(color: _b(dark ? 0.30 : 0.10), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          );
        }
        return _Recipe(
          sheen: whiteFill && !dark ? [_b(0), _b(0.05)] : [_w(dark ? 0.05 : 0.10), _clear],
          highlight: _w(dark ? 0.05 : 0.50),
          shade: _b(dark ? 0.20 : 0.05),
          shadows: [BoxShadow(color: _b(dark ? 0.20 : 0.05), blurRadius: 4, offset: const Offset(0, 1))],
        );
      case OFinish.pillow:
        final k = strong ? 1.0 : 0.7;
        return _Recipe(
          sheen: [_w(strong ? 0.16 : (whiteFill ? 0 : 0.10)), _b(strong ? 0.10 : 0.03)],
          shadows: [
            BoxShadow(color: _b((dark ? 0.60 : 0.16) * k), blurRadius: 14 * k, offset: Offset(5 * k, 5 * k)),
            BoxShadow(color: _w(dark ? 0.05 : 0.95), blurRadius: 12 * k, offset: Offset(-5 * k, -5 * k)),
          ],
          pressedShade: _b(dark ? 0.55 : 0.18),
        );
      case OFinish.glass:
        return _Recipe(
          fillAlpha: strong ? 0.92 : 0.62,
          sheen: [_w(strong ? 0.30 : (dark ? 0.10 : 0.45)), _clear],
          sheenStops: const [0, 0.55],
          rim: _w(dark ? (strong ? 0.22 : 0.12) : (strong ? 0.35 : 0.80)),
          shadows: [
            BoxShadow(
              color: _b(dark ? (strong ? 0.40 : 0.22) : (strong ? 0.18 : 0.07)),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case OFinish.glow:
        if (strong) {
          // Ink (black or white) has no colour to glow in: it takes the accent.
          final hsl = HSLColor.fromColor(fill);
          final glow = hsl.saturation > 0.3 && hsl.lightness > 0.15 && hsl.lightness < 0.85 ? fill : accent;
          return _Recipe(
            sheen: [_w(0.16), _clear],
            highlight: _w(0.30),
            shadows: [
              BoxShadow(
                color: glow.withValues(alpha: dark ? 0.45 : 0.40),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
              BoxShadow(color: glow.withValues(alpha: 0.30), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          );
        }
        return _Recipe(
          highlight: _w(dark ? 0.06 : 0.6),
          shadows: [BoxShadow(color: _b(dark ? 0.35 : 0.07), blurRadius: 14, offset: const Offset(0, 4))],
        );
    }
  }
}

class _FinishPainter extends CustomPainter {
  _FinishPainter({
    required this.color,
    required this.shape,
    required this.look,
    required this.recipe,
    required this.pressed,
  });

  final Color color;
  final (OFinish, ODepth, bool) look;
  final ShapeBorder shape;
  final _Recipe recipe;
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    final r = recipe;
    // A see-through fill would show its own shadow through it as a smudge.
    if (!pressed && color.a >= 0.5) {
      for (final s in r.shadows) {
        canvas.drawPath(
          path.shift(s.offset),
          Paint()
            ..color = s.color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma),
        );
      }
    }
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: color.a * r.fillAlpha));
    final edges = r.sheen.isNotEmpty || r.highlight != null || r.shade != null || r.rim != null;
    if (edges || pressed) {
      canvas.save();
      canvas.clipPath(path);
      if (r.sheen.isNotEmpty) {
        canvas.drawRect(
          rect,
          Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, r.sheen, r.sheenStops),
        );
      }
      if (pressed && r.shadows.isNotEmpty) {
        // Pushed in: the bevel turns inward, a soft shade under the top edge.
        final outside = Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(12)),
          path.shift(const Offset(0, 2)),
        );
        canvas.drawPath(
          outside,
          Paint()
            ..color = r.pressedShade
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      } else {
        if (r.highlight case final c?) {
          canvas.drawPath(
            Path.combine(PathOperation.difference, path, path.shift(const Offset(0, 1))),
            Paint()..color = c,
          );
        }
        if (r.shade case final c?) {
          canvas.drawPath(
            Path.combine(PathOperation.difference, path, path.shift(const Offset(0, -1))),
            Paint()..color = c,
          );
        }
      }
      if (r.rim case final c?) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = c,
        );
      }
      canvas.restore();
    }
    shape.paint(canvas, rect);
  }

  @override
  bool shouldRepaint(_FinishPainter old) =>
      old.color != color || old.shape != shape || old.pressed != pressed || old.look != look;
}
