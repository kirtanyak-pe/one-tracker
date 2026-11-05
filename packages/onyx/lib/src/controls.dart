import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';

/// An on/off switch. Ink track when on, raised track when off.
class OToggle extends StatelessWidget {
  const OToggle({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = OMotion.of(context, OMotion.base);
    return Semantics(
      toggled: value,
      label: label,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        onHorizontalDragEnd: onChanged == null
            ? null
            : (e) {
                final v = (e.primaryVelocity ?? 0) > 0;
                if (v != value) {
                  HapticFeedback.selectionClick();
                  onChanged!(v);
                }
              },
        child: Opacity(
          opacity: onChanged == null ? 0.4 : 1,
          child: SizedBox(
            width: 52,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: d,
                curve: OMotion.standard,
                width: 46,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: ShapeDecoration(color: value ? c.ink : c.lineStrong, shape: const StadiumBorder()),
                child: AnimatedAlign(
                  duration: d,
                  curve: OMotion.emphasized,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: value ? c.onInk : const Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded square check.
class OCheckbox extends StatelessWidget {
  const OCheckbox({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: value,
      label: label,
      child: OPressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        pressedScale: 0.9,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedContainer(
              duration: OMotion.of(context, OMotion.fast),
              width: 22,
              height: 22,
              decoration: ShapeDecoration(
                color: value ? c.ink : const Color(0x00000000),
                shape: ORadius.smooth(7, side: value ? BorderSide.none : BorderSide(color: c.lineStrong, width: 1.5)),
              ),
              child: value ? Icon(LucideIcons.check, size: 15, color: c.onInk) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a label and a trailing checkbox, the whole row tappable.
class OCheckRow extends StatelessWidget {
  const OCheckRow({super.key, required this.value, required this.onChanged, required this.title, this.subtitle});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => OPressable(
    onTap: onChanged == null ? null : () => onChanged!(!value),
    pressedScale: 0.99,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.type.bodyStrong),
              if (subtitle != null) Text(subtitle!, style: context.type.small),
            ],
          ),
        ),
        IgnorePointer(
          child: OCheckbox(value: value, onChanged: onChanged),
        ),
      ],
    ),
  );
}

/// A pill chip. Selected chips fill with ink.
class OChip extends StatelessWidget {
  const OChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.trailingIcon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onInk : c.ink;
    return Semantics(
      selected: selected,
      child: OPressable(
        onTap: onTap,
        pressedScale: 0.95,
        child: AnimatedContainer(
          duration: OMotion.of(context, OMotion.fast),
          height: dense ? 30 : 36,
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
          decoration: ShapeDecoration(
            color: selected ? c.ink : c.surface,
            shape: StadiumBorder(side: BorderSide(color: selected ? c.ink : c.line)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: dense ? 14 : 16, color: fg), const SizedBox(width: 6)],
              Text(label, style: (dense ? context.type.caption : context.type.smallStrong).tint(fg).medium),
              if (trailingIcon != null) ...[const SizedBox(width: 4), Icon(trailingIcon, size: 14, color: fg)],
            ],
          ),
        ),
      ),
    );
  }
}

/// A segmented control: a raised track with a sliding surface thumb.
class OSegmented<T> extends StatelessWidget {
  const OSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.iconOf,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final i = values.indexOf(selected);
    final n = values.length;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: c.raised, shape: const StadiumBorder()),
      child: Stack(
        children: [
          if (i >= 0)
            AnimatedAlign(
              duration: OMotion.of(context, OMotion.base),
              curve: OMotion.emphasized,
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * i / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.surface,
                    shape: const StadiumBorder(),
                    shadows: OShadow.subtle(context.onyx.brightness),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final v in values)
                Expanded(
                  child: Semantics(
                    selected: v == selected,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (v == selected) return;
                        HapticFeedback.selectionClick();
                        onChanged(v);
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (iconOf?.call(v) case final ic?) ...[
                              Icon(ic, size: 15, color: v == selected ? c.ink : c.inkSoft),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: OMotion.fast,
                                style: context.type.smallStrong.tint(v == selected ? c.ink : c.inkSoft),
                                child: Text(labelOf(v), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
