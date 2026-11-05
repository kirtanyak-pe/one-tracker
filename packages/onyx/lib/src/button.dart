import 'package:flutter/widgets.dart';

import 'feedback.dart';
import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';

enum OButtonVariant {
  /// Ink fill: the one main action on a screen.
  primary,

  /// Raised fill: everything else that's a button.
  secondary,

  /// No fill: low-emphasis actions, "Cancel", "View all".
  ghost,

  /// Negative fill: destructive confirmations.
  danger,

  /// Accent fill: rare, for a call to action that must stand apart.
  accent,

  /// For an ink surface: canvas-coloured fill, ink text.
  inverse,

  /// For an ink surface: a translucent fill, light text.
  inverseSoft,
}

enum OButtonSize {
  sm(36, 14, 13, 16),
  md(44, 18, 15, 18),
  lg(52, 20, 16, 22);

  const OButtonSize(this.height, this.padding, this.fontSize, this.icon);
  final double height;
  final double padding;
  final double fontSize;
  final double icon;
}

/// A pill button. Disabled when [onPressed] is null.
class OButton extends StatelessWidget {
  const OButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = OButtonVariant.primary,
    this.size = OButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.loading = false,
  });

  const OButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = OButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.loading = false,
  }) : variant = OButtonVariant.secondary;

  const OButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = OButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.loading = false,
  }) : variant = OButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final OButtonVariant variant;
  final OButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Fill the available width.
  final bool expand;

  /// Shows a spinner in place of the label and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (variant) {
      OButtonVariant.primary => (c.ink, c.onInk),
      OButtonVariant.secondary => (c.raised, c.ink),
      OButtonVariant.ghost => (const Color(0x00000000), c.ink),
      OButtonVariant.danger => (c.negative, const Color(0xFFFFFFFF)),
      OButtonVariant.accent => (c.accent, c.onAccent),
      OButtonVariant.inverse => (c.onInk, c.ink),
      OButtonVariant.inverseSoft => (c.onInk.withValues(alpha: 0.14), c.onInk),
    };
    final enabled = onPressed != null && !loading;
    final style = context.type.label.copyWith(fontSize: size.fontSize, color: fg);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: size.icon, color: fg), const SizedBox(width: OSpace.sm)],
        Flexible(
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: OSpace.xs + 2),
          Icon(trailingIcon, size: size.icon, color: fg),
        ],
      ],
    );
    final body = Container(
      height: size.height,
      padding: EdgeInsets.symmetric(horizontal: variant == OButtonVariant.ghost ? size.padding - 6 : size.padding),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      alignment: Alignment.center,
      child: loading
          ? Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: 0, child: content),
                OSpinner(size: size.icon, color: fg),
              ],
            )
          : content,
    );
    return OPressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      pressedOpacity: variant == OButtonVariant.ghost ? 0.6 : 1,
      child: AnimatedOpacity(opacity: onPressed == null ? 0.38 : 1, duration: OMotion.fast, child: body),
    );
  }
}

/// An icon in a circle. [filled] gives it a surface disc (top bars); without
/// it the icon sits bare with a 44pt hit area.
class OIconButton extends StatelessWidget {
  const OIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.size = 40,
    this.iconSize = 20,
    this.filled = false,
    this.color,
    this.background,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Read by screen readers (and the long-press hint).
  final String label;
  final double size;
  final double iconSize;
  final bool filled;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = background ?? (filled ? c.surface : null);
    return OPressable(
      onTap: onPressed,
      semanticLabel: label,
      pressedScale: 0.9,
      child: Opacity(
        opacity: onPressed == null ? 0.38 : 1,
        child: SizedBox.square(
          dimension: size < 44 && bg == null ? 44 : size,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: bg == null
                  ? null
                  : BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: filled && background == null ? Border.all(color: c.line) : null,
                    ),
              alignment: Alignment.center,
              child: Icon(icon, size: iconSize, color: color ?? c.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline text link: accent-free, ink and semibold, fades when pressed.
class OTextButton extends StatelessWidget {
  const OTextButton({super.key, required this.label, required this.onPressed, this.icon, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.ink;
    return OPressable(
      onTap: onPressed,
      pressedScale: 1,
      pressedOpacity: 0.5,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OSpace.sm, horizontal: OSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.type.smallStrong.tint(fg).semibold),
            if (icon != null) ...[const SizedBox(width: OSpace.xs), Icon(icon, size: 16, color: fg)],
          ],
        ),
      ),
    );
  }
}
