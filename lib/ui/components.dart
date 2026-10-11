import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Soft vertical canvas gradient behind every screen.
class CanvasBackground extends StatelessWidget {
  const CanvasBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.canvasTop, t.canvas],
        ),
      ),
      child: child,
    );
  }
}

/// Back button · centred title · optional trailing, for pushed screens.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.sm),
        child: Row(
          children: [
            CircleIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(width: 48, child: trailing),
          ],
        ),
      );
}

/// Darker inset area that holds white things.
class Tray extends StatelessWidget {
  const Tray({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.radius = Radii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: context.tokens.tray,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}

/// White object resting on the canvas or a tray.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.radius = Radii.tile,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Draws an ink outline — used for single/multi-select cards.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: selected ? t.ink : Colors.transparent, width: 2),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: ShapeDecoration(
        color: t.card,
        shape: shape,
        shadows: Shadows.card(Theme.of(context).brightness),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// White (card-coloured) circle with an icon. 48×48 touch target.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.card,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: 22, color: t.ink),
          ),
        ),
      ),
    );
  }
}

/// Grey tile with a white circle icon and a label underneath.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Orange dot on the icon, for "needs attention".
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.tray,
      borderRadius: BorderRadius.circular(Radii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.lg),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: t.card, shape: BoxShape.circle),
                    child: Icon(icon, color: t.ink, size: 22),
                  ),
                  if (highlight)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              // Scales down rather than truncating at large system font sizes.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one orange "tap me" button, with soft halo rings.
class AccentOrb extends StatelessWidget {
  const AccentOrb({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 52,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.accent.withValues(alpha: 0.12),
        ),
        child: Material(
          color: t.accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: Shadows.glow(t.accent)),
              child: SizedBox.square(
                dimension: size,
                child: Icon(icon, color: t.onAccent, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin progress ring: grey track, ink (or accent) arc.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    this.size = 44,
    this.stroke = 4,
    this.accent = false,
  });

  final double value;
  final double size;
  final double stroke;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1),
          stroke: stroke,
          track: t.trayDeep,
          arc: accent ? t.accent : t.ink,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.stroke, required this.track, required this.arc});

  final double value;
  final double stroke;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, paint..color = arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.arc != arc || old.track != track;
}

/// Label above a big value, optional caption and trailing visual.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.trailing,
  });

  final String label;
  final String value;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: text.headlineMedium?.copyWith(fontSize: 24)),
                ),
                if (caption != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(caption!, style: text.bodySmall?.copyWith(color: t.muted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.top = Space.xxxl});

  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: Space.md),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            ?trailing,
          ],
        ),
      );
}

/// Grey tray with a white pill on the selected option.
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.xs + 2),
      decoration: BoxDecoration(
        color: t.tray,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: Semantics(
                selected: entry.key == value,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == value ? t.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      boxShadow: entry.key == value
                          ? Shadows.card(Theme.of(context).brightness)
                          : const [],
                    ),
                    child: Text(
                      entry.value,
                      style: text.labelLarge?.copyWith(
                        color: entry.key == value ? t.ink : t.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Initials in a grey circle.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40, this.ring});

  final String name;
  final double size;

  /// Border colour, for overlapping stacks.
  final Color? ring;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    // Two letters don't fit small circles.
    if (parts.length == 1 || size < 32) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.tray,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
      ),
    );
  }
}

/// Overlapping avatars, "+n" after [max].
class AvatarStack extends StatelessWidget {
  const AvatarStack(this.names, {super.key, this.size = 28, this.max = 4});

  final List<String> names;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final step = size * 0.7;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      height: size,
      width: count == 0 ? 0 : step * (count - 1) + size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(left: step * i, child: Avatar(shown[i], size: size, ring: t.card)),
          if (extra > 0)
            Positioned(
              left: step * shown.length,
              child: Avatar('+ $extra', size: size, ring: t.card),
            ),
        ],
      ),
    );
  }
}

/// Buttons that sit on an orange surface. Fixed white/ink in both themes —
/// the orange doesn't change with dark mode, so neither do these.
abstract final class OnAccentButtonStyle {
  static const _ink = Color(0xFF111111);
  static const _padding = EdgeInsets.symmetric(horizontal: Space.md);

  static ButtonStyle solid(AppTokens t) => FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
        disabledForegroundColor: _ink.withValues(alpha: 0.5),
        minimumSize: const Size(64, 52),
        padding: _padding,
        shape: const StadiumBorder(),
      );

  static ButtonStyle ghost(AppTokens t) => FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: t.onAccent,
        minimumSize: const Size(64, 52),
        padding: _padding,
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.45))),
      );
}

/// Button label that shrinks instead of wrapping at large system font sizes.
class OneLineLabel extends StatelessWidget {
  const OneLineLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
}

/// Concentric arcs in a corner, as on the reference tip card.
class ConcentricArcs extends StatelessWidget {
  const ConcentricArcs({super.key, this.size = 140});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox.square(dimension: size, child: CustomPaint(painter: _ArcsPainter())),
      );
}

class _ArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.16);
    final centre = Offset(size.width, 0);
    for (var r = size.width * 0.35; r <= size.width; r += size.width * 0.16) {
      canvas.drawCircle(centre, r, paint);
    }
  }

  @override
  bool shouldRepaint(_ArcsPainter old) => false;
}
