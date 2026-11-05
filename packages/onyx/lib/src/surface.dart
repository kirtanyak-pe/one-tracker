import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'finish.dart';
import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';

/// A surface object on the canvas: smooth corners, a hairline border, no
/// shadow. [selected] swaps the hairline for an ink outline.
class OCard extends StatelessWidget {
  const OCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OSpace.xl),
    this.radius = ORadius.lg,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.color,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = selected
        ? BorderSide(color: c.ink, width: 1.5)
        : border && context.onyx.finish.hairlines
        ? BorderSide(color: c.line)
        : BorderSide.none;
    final card = OFinishBox(
      color: color ?? c.surface,
      depth: ODepth.surface,
      shape: ORadius.smooth(radius, side: side),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null && onLongPress == null) return card;
    return OPressable(onTap: onTap, onLongPress: onLongPress, pressedScale: 0.98, child: card);
  }
}

/// A recessed area: fields, trays, grouped controls.
class OInset extends StatelessWidget {
  const OInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OSpace.lg),
    this.radius = ORadius.md,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => OFinishBox(
    color: color ?? context.colors.raised,
    depth: ODepth.well,
    shape: ORadius.smooth(radius),
    child: Padding(padding: padding, child: child),
  );
}

/// A hairline.
class ODivider extends StatelessWidget {
  const ODivider({super.key, this.indent = 0, this.endIndent = 0, this.vertical = false, this.space = 1});

  final double indent;
  final double endIndent;
  final bool vertical;

  /// Total extent along the cross axis (the line itself is 1px).
  final double space;

  @override
  Widget build(BuildContext context) {
    final line = ColoredBox(color: context.colors.line);
    return vertical
        ? SizedBox(
            width: space,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: indent, bottom: endIndent),
                child: SizedBox(width: 1, child: line),
              ),
            ),
          )
        : SizedBox(
            height: space,
            child: Center(
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
                child: SizedBox(height: 1, width: double.infinity, child: line),
              ),
            ),
          );
  }
}

/// A section's heading row: a title, and an optional trailing action.
class OSectionHeader extends StatelessWidget {
  const OSectionHeader(this.title, {super.key, this.trailing, this.top = OSpace.xxl, this.bottom = OSpace.md});

  final String title;
  final Widget? trailing;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: context.type.title3)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A list row: leading · title/subtitle · trailing. 56pt minimum.
class ORow extends StatelessWidget {
  const ORow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron = false,
    this.padding = const EdgeInsets.symmetric(horizontal: OSpace.lg, vertical: OSpace.md),
    this.destructive = false,
    this.enabled = true,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Adds a › after [trailing] for rows that open a screen.
  final bool chevron;
  final EdgeInsetsGeometry padding;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: destructive ? c.negative : c.ink, size: 20),
                child: leading!,
              ),
              const SizedBox(width: OSpace.md + 2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(style: t.bodyStrong.tint(destructive ? c.negative : c.ink), child: title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(style: t.small, child: subtitle!),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: OSpace.md),
              DefaultTextStyle.merge(
                style: t.small,
                child: IconTheme.merge(
                  data: IconThemeData(color: c.inkSoft, size: 20),
                  child: trailing!,
                ),
              ),
            ],
            if (chevron) ...[
              const SizedBox(width: OSpace.xs),
              Icon(LucideIcons.chevronRight, size: 18, color: c.inkFaint),
            ],
          ],
        ),
      ),
    );
    final body = Opacity(opacity: enabled ? 1 : 0.4, child: row);
    if (!enabled || (onTap == null && onLongPress == null)) return body;
    return OPressable(onTap: onTap, onLongPress: onLongPress, pressedScale: 0.985, child: body);
  }
}

/// Groups rows in one card, hairlines between them.
class OGroup extends StatelessWidget {
  const OGroup({super.key, required this.children, this.dividerIndent = OSpace.lg});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => OCard(
    padding: EdgeInsets.zero,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) ODivider(indent: dividerIndent), children[i]],
      ],
    ),
  );
}
