import 'package:flutter/material.dart';

import '../../model/category.dart';
import '../../ui/tokens.dart';

/// Wrap of selectable category pills (tray → ink when selected).
class CategoryPills extends StatelessWidget {
  const CategoryPills({
    super.key,
    required this.selected,
    required this.onSelected,
    this.categories,
  });

  final Category? selected;
  final ValueChanged<Category> onSelected;
  final List<Category>? categories;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final c in categories ?? Category.spending)
          Semantics(
            selected: c == selected,
            button: true,
            child: Material(
              color: c == selected ? t.ink : t.tray,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(c),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c.icon,
                          size: 18,
                          color: c == selected ? t.onInk : t.ink,
                        ),
                        const SizedBox(width: Space.sm),
                        Text(
                          c.label,
                          style: text.labelLarge?.copyWith(
                            color: c == selected ? t.onInk : t.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
