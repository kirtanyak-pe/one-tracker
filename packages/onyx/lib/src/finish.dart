import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';
import 'tokens.g.dart';

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
  bool get hairlines => OTokenFinish.hairlines.contains(name);
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

  static Color _tint(OTint t, Color accent, Color glow) => switch (t.base) {
    OTintBase.black => Color.fromRGBO(0, 0, 0, t.alpha),
    OTintBase.white => Color.fromRGBO(255, 255, 255, t.alpha),
    OTintBase.accent => accent.withValues(alpha: t.alpha),
    OTintBase.glow => glow.withValues(alpha: t.alpha),
  };

  /// The numbers live in tokens/onyx.tokens.json; this picks them for one fill and resolves the colours.
  static _Recipe of(
    OFinish finish,
    ODepth depth,
    Color fill,
    bool dark,
    OColors c,
  ) {
    // A white sheen can't show on a white fill: light it from above instead.
    final whiteFill = fill.computeLuminance() > 0.85;
    final accent = c.accent;
    final quiet = depth == ODepth.surface || depth == ODepth.well;
    // A wash over a coloured card (white at 14 %) stays a wash.
    if (quiet && fill.a < 0.5) return const _Recipe();
    // Pillow shapes neutral surfaces out of the canvas itself; an ink card stays ink.
    final neutral = fill == c.surface || fill == c.raised || fill == c.canvas;
    // Ink (black or white) has no colour to glow in: it takes the accent.
    final hsl = HSLColor.fromColor(fill);
    final glow =
        hsl.saturation > 0.3 && hsl.lightness > 0.15 && hsl.lightness < 0.85
        ? fill
        : accent;

    final t = OTokenFinish
        .recipes['${finish.name}.${dark ? 'dark' : 'light'}.${depth.name}']!;
    Color tint(OTint x) => _tint(x, accent, glow);
    BoxShadow shadow(OShadowToken s) => BoxShadow(
      color: tint(s.tint),
      blurRadius: s.blur,
      offset: Offset(s.dx, s.dy),
    );
    final sheen = whiteFill ? (t.sheenOnWhite ?? t.sheen) : t.sheen;
    final pressed = t.pressedShade ?? OTokenFinish.pressedShade;
    return _Recipe(
      fill: t.fillCanvas && neutral ? c.canvas : null,
      fillAlpha: t.fillAlpha,
      sheen: [for (final x in sheen) tint(x)],
      sheenStops: t.sheenStops,
      highlight: t.highlight == null ? null : tint(t.highlight!),
      shade: t.shade == null ? null : tint(t.shade!),
      rim: t.rim == null ? null : tint(t.rim!),
      shadows: [for (final s in t.shadows) shadow(s)],
      insets: [for (final s in t.insets) shadow(s)],
      pressedShade: tint(pressed),
    );
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
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(rect.inflate(80)),
            path,
          ),
        );
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
    canvas.drawPath(
      path,
      Paint()..color = fill.withValues(alpha: fill.a * r.fillAlpha),
    );
    final edges =
        r.sheen.isNotEmpty ||
        r.highlight != null ||
        r.shade != null ||
        r.rim != null ||
        r.insets.isNotEmpty;
    if (edges || pressed) {
      canvas.save();
      canvas.clipPath(path);
      if (r.sheen.isNotEmpty) {
        canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              rect.topCenter,
              rect.bottomCenter,
              r.sheen,
              r.sheenStops,
            ),
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
            Path.combine(
              PathOperation.difference,
              path,
              path.shift(const Offset(0, 1)),
            ),
            Paint()..color = c,
          );
        }
        if (r.shade case final c?) {
          canvas.drawPath(
            Path.combine(
              PathOperation.difference,
              path,
              path.shift(const Offset(0, -1)),
            ),
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
  static void _inset(
    Canvas canvas,
    Rect rect,
    Path path,
    Offset d,
    Color color,
    double sigma,
  ) {
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(16)),
      path.shift(d),
    );
    canvas.drawPath(
      outside,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_FinishPainter old) =>
      old.color != color ||
      old.shape != shape ||
      old.pressed != pressed ||
      old.look != look;
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
          : CustomPaint(
              painter: _BackgroundPainter(t.finish, t.isDark, t.colors.accent),
              child: child,
            ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.finish, this.dark, this.accent);

  final OFinish finish;
  final bool dark;
  final Color accent;

  void _wash(
    Canvas canvas,
    Size size,
    Offset centre,
    double radius,
    Color color,
  ) => canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.radial(centre, radius, [
        color,
        color.withValues(alpha: 0),
      ]),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Glass: two colour washes to frost over; glow: a light falling from the top (tokens › finish.background).
    for (final k
        in OTokenFinish.washes['${finish.name}.${dark ? 'dark' : 'light'}'] ??
            const <OWashToken>[]) {
      _wash(
        canvas,
        size,
        Offset(w * k.x, (k.yOfWidth ? w : size.height) * k.y),
        w * k.radius,
        (k.color ?? accent).withValues(alpha: k.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.finish != finish || old.dark != dark || old.accent != accent;
}
