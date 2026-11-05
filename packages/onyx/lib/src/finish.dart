import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';

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

/// How much a finished thing stands out. Each level is gentler than the one
/// before, so a button never melts into the card it sits on.
enum ODepth {
  /// Solid fills: main buttons, a selected pill or chip.
  strong,

  /// Light or outlined pressables: secondary buttons, a segmented thumb.
  soft,

  /// Things that sit on the canvas: cards, groups, dialogs, the tab bar,
  /// icon tiles. Not pushed in when pressed.
  surface,

  /// Recessed areas: fields, trays, segmented and toggle tracks.
  well,
}

extension OFinishX on OFinish {
  /// Whether cards keep their hairline; the other finishes draw their own edge.
  bool get hairlines => this == OFinish.flat || this == OFinish.raised;
}

/// A [shape] filled with [color], in the app's finish. Pushed in while the
/// nearest [OPressable] is held (buttons only, not surfaces).
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
    final f = finish ?? theme.finish;
    final pushes = depth == ODepth.strong || depth == ODepth.soft;
    return CustomPaint(
      painter: _FinishPainter(
        color: color,
        shape: shape,
        look: (f, depth, theme.isDark),
        recipe: _Recipe.of(f, depth, color, theme.isDark, theme.colors),
        pressed: pushes && OPressable.isPressed(context),
      ),
      child: child,
    );
  }
}

/// What a finish adds over a fill.
class _Recipe {
  const _Recipe({
    this.fill,
    this.fillAlpha = 1,
    this.sheen = const [],
    this.sheenStops,
    this.highlight,
    this.shade,
    this.rim,
    this.shadows = const [],
    this.insets = const [],
    this.pressedShade = const Color(0x40000000),
  });

  /// Replaces the fill (pillow surfaces take the canvas colour).
  final Color? fill;
  final double fillAlpha;
  final List<Color> sheen;
  final List<double>? sheenStops;

  /// 1px light along the top edge, inside.
  final Color? highlight;

  /// 1px along the bottom edge, inside.
  final Color? shade;

  /// 1px line all the way round, inside.
  final Color? rim;
  final List<BoxShadow> shadows;

  /// Shadows cast inward, as if the shape were pressed into the canvas.
  final List<BoxShadow> insets;
  final Color pressedShade;

  static const _clear = Color(0x00FFFFFF);
  static Color _w(double a) => Color.fromRGBO(255, 255, 255, a);
  static Color _b(double a) => Color.fromRGBO(0, 0, 0, a);
  static BoxShadow _s(Color c, double blur, double dy, [double dx = 0]) =>
      BoxShadow(color: c, blurRadius: blur, offset: Offset(dx, dy));

  static _Recipe of(OFinish finish, ODepth depth, Color fill, bool dark, OColors c) {
    // A white sheen can't show on a white fill: light it from above instead.
    final whiteFill = fill.computeLuminance() > 0.85;
    final accent = c.accent;
    final quiet = depth == ODepth.surface || depth == ODepth.well;
    // A wash over a coloured card (white at 14 %) stays a wash.
    if (quiet && fill.a < 0.5) return const _Recipe();
    // Pillow shapes neutral surfaces out of the canvas itself; an ink card stays ink.
    final neutral = fill == c.surface || fill == c.raised || fill == c.canvas;
    switch (finish) {
      case OFinish.flat:
        return const _Recipe();
      case OFinish.raised:
        return switch ((depth, dark)) {
          (ODepth.strong, true) => _Recipe(
            sheen: [_w(0.20), _b(0.15)],
            highlight: _w(0.25),
            shade: _b(0.30),
            shadows: [_s(_b(0.20), 4, 1), _s(_b(0.30), 6, 2)],
          ),
          // On a light canvas a dark drop reads as dirt: shorter, crisper.
          (ODepth.strong, false) => _Recipe(
            sheen: [_w(0.14), _b(0.10)],
            highlight: _w(0.22),
            shade: _b(0.35),
            shadows: [_s(_b(0.16), 3, 1), _s(_b(0.10), 10, 4)],
          ),
          (ODepth.soft, true) => _Recipe(
            sheen: [_w(0.05), _clear],
            highlight: _w(0.05),
            shade: _b(0.20),
            shadows: [_s(_b(0.20), 4, 1)],
          ),
          (ODepth.soft, false) => _Recipe(
            sheen: whiteFill ? [_b(0), _b(0.04)] : [_w(0.10), _clear],
            highlight: _w(1),
            shade: _b(0.10),
            shadows: [_s(_b(0.08), 3, 1), _s(_b(0.05), 8, 3)],
          ),
          (ODepth.surface, true) => _Recipe(highlight: _w(0.04), shadows: [_s(_b(0.30), 8, 2)]),
          (ODepth.surface, false) => _Recipe(shade: _b(0.04), shadows: [_s(_b(0.04), 2, 1), _s(_b(0.03), 12, 4)]),
          (ODepth.well, _) => _Recipe(shade: _w(dark ? 0.04 : 0.7), insets: [_s(_b(dark ? 0.35 : 0.06), 3, 1)]),
        };
      case OFinish.pillow:
        // Lit from the top left: a dark shadow bottom right, a light one top left.
        final (dk, lt) = (dark ? 0.60 : 0.16, dark ? 0.05 : 0.95);
        switch (depth) {
          case ODepth.strong || ODepth.soft:
            final k = depth == ODepth.strong ? 1.0 : 0.7;
            final strong = k == 1.0;
            return _Recipe(
              sheen: [_w(strong ? 0.16 : (whiteFill ? 0 : 0.10)), _b(strong ? 0.10 : 0.03)],
              shadows: [_s(_b(dk * k), 14 * k, 5 * k, 5 * k), _s(_w(lt), 12 * k, -5 * k, -5 * k)],
              pressedShade: _b(dark ? 0.55 : 0.18),
            );
          case ODepth.surface:
            // True soft UI: the same colour as the canvas, shaped only by light.
            return _Recipe(
              fill: neutral ? c.canvas : null,
              shadows: [_s(_b(dark ? 0.45 : 0.08), 16, 4, 4), _s(_w(dark ? 0.03 : 1), 16, -4, -4)],
            );
          case ODepth.well:
            return _Recipe(
              fill: neutral ? c.canvas : null,
              insets: [_s(_b(dark ? 0.50 : 0.10), 4, 2, 2), _s(_w(dark ? 0.04 : 0.9), 4, -2, -2)],
            );
        }
      case OFinish.glass:
        return switch (depth) {
          ODepth.strong || ODepth.soft => () {
            final strong = depth == ODepth.strong;
            return _Recipe(
              fillAlpha: strong ? 0.92 : 0.62,
              sheen: [_w(strong ? 0.30 : (dark ? 0.10 : 0.45)), _clear],
              sheenStops: const [0, 0.55],
              rim: _w(dark ? (strong ? 0.22 : 0.12) : (strong ? 0.35 : 0.80)),
              shadows: [_s(_b(dark ? (strong ? 0.40 : 0.22) : (strong ? 0.18 : 0.07)), 18, 6)],
            );
          }(),
          ODepth.surface => _Recipe(
            fillAlpha: dark ? 0.55 : 0.6,
            sheen: [_w(dark ? 0.06 : 0.5), _clear],
            sheenStops: const [0, 0.5],
            rim: _w(dark ? 0.08 : 0.9),
            shadows: [_s(_b(dark ? 0.30 : 0.05), 24, 8)],
          ),
          ODepth.well => _Recipe(
            fillAlpha: 0.5,
            rim: _w(dark ? 0.05 : 0.6),
            insets: [_s(_b(dark ? 0.30 : 0.05), 3, 1)],
          ),
        };
      case OFinish.glow:
        // Ink (black or white) has no colour to glow in: it takes the accent.
        final hsl = HSLColor.fromColor(fill);
        final glow = hsl.saturation > 0.3 && hsl.lightness > 0.15 && hsl.lightness < 0.85 ? fill : accent;
        return switch (depth) {
          ODepth.strong when dark => _Recipe(
            sheen: [_w(0.16), _clear],
            highlight: _w(0.30),
            shadows: [_s(glow.withValues(alpha: 0.45), 22, 6), _s(glow.withValues(alpha: 0.30), 4, 1)],
          ),
          // Light canvas: a tighter, paler halo plus a crisp contact shadow,
          // so it reads as lit rather than smudged.
          ODepth.strong => _Recipe(
            sheen: [_w(0.16), _clear],
            highlight: _w(0.30),
            shadows: [_s(glow.withValues(alpha: 0.30), 16, 6), _s(_b(0.12), 2, 1)],
          ),
          ODepth.soft => _Recipe(
            highlight: _w(dark ? 0.06 : 0.6),
            rim: accent.withValues(alpha: dark ? 0.22 : 0.18),
            shadows: [_s(accent.withValues(alpha: dark ? 0.20 : 0.10), 14, 4)],
          ),
          ODepth.surface => _Recipe(
            rim: accent.withValues(alpha: dark ? 0.16 : 0.12),
            shadows: [_s(accent.withValues(alpha: dark ? 0.12 : 0.08), 26, 8)],
          ),
          ODepth.well => _Recipe(rim: accent.withValues(alpha: 0.10), insets: [_s(_b(dark ? 0.35 : 0.05), 3, 1)]),
        };
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
    if (!pressed && color.a >= 0.5 && r.shadows.isNotEmpty) {
      // Frosted fills: keep the shadow outside the shape.
      final clip = r.fillAlpha < 1;
      if (clip) {
        canvas.save();
        canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(80)), path));
      }
      for (final s in r.shadows) {
        canvas.drawPath(
          path.shift(s.offset),
          Paint()
            ..color = s.color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma),
        );
      }
      if (clip) canvas.restore();
    }
    final fill = r.fill ?? color;
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: fill.a * r.fillAlpha));
    final edges = r.sheen.isNotEmpty || r.highlight != null || r.shade != null || r.rim != null || r.insets.isNotEmpty;
    if (edges || pressed) {
      canvas.save();
      canvas.clipPath(path);
      if (r.sheen.isNotEmpty) {
        canvas.drawRect(
          rect,
          Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, r.sheen, r.sheenStops),
        );
      }
      for (final s in r.insets) {
        _inset(canvas, rect, path, s.offset, s.color, s.blurSigma);
      }
      if (pressed && r.shadows.isNotEmpty) {
        // Pushed in: the bevel turns inward, a soft shade under the top edge.
        _inset(canvas, rect, path, const Offset(0, 2), r.pressedShade, 2.5);
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

  /// A shadow cast inside [path], from an edge offset by [d].
  static void _inset(Canvas canvas, Rect rect, Path path, Offset d, Color color, double sigma) {
    final outside = Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(16)), path.shift(d));
    canvas.drawPath(
      outside,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_FinishPainter old) =>
      old.color != color || old.shape != shape || old.pressed != pressed || old.look != look;
}

/// The canvas behind every screen, in the app's finish. Glass gets two soft
/// colour washes to frost over; glow a light falling from the top.
class OBackground extends StatelessWidget {
  const OBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.onyx;
    final plain = t.finish != OFinish.glass && t.finish != OFinish.glow;
    return ColoredBox(
      color: t.colors.canvas,
      child: plain
          ? child
          : CustomPaint(painter: _BackgroundPainter(t.finish, t.isDark, t.colors.accent), child: child),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.finish, this.dark, this.accent);

  final OFinish finish;
  final bool dark;
  final Color accent;

  static const _violet = Color(0xFF8B5CF6);

  void _wash(Canvas canvas, Size size, Offset centre, double radius, Color color) => canvas.drawRect(
    Offset.zero & size,
    Paint()..shader = ui.Gradient.radial(centre, radius, [color, color.withValues(alpha: 0)]),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (finish == OFinish.glass) {
      _wash(canvas, size, Offset(w * 0.1, size.height * 0.1), w * 0.8, accent.withValues(alpha: dark ? 0.22 : 0.16));
      _wash(
        canvas,
        size,
        Offset(w * 0.95, size.height * 0.55),
        w * 0.85,
        _violet.withValues(alpha: dark ? 0.18 : 0.12),
      );
    } else {
      _wash(canvas, size, Offset(w / 2, -w * 0.15), w * 1.1, accent.withValues(alpha: dark ? 0.20 : 0.10));
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.finish != finish || old.dark != dark || old.accent != accent;
}
