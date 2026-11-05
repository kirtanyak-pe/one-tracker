import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../../model/category.dart';

/// Wrap of selectable category pills (hairline → ink when selected).
class CategoryPills extends StatelessWidget {
  const CategoryPills({super.key, required this.selected, required this.onSelected, this.categories});

  final Category? selected;
  final ValueChanged<Category> onSelected;
  final List<Category>? categories;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OSpace.sm,
      runSpacing: OSpace.sm,
      children: [
        for (final c in categories ?? Category.spending)
          OChip(label: c.label, icon: c.icon, selected: c == selected, onTap: () => onSelected(c)),
      ],
    );
  }
}
