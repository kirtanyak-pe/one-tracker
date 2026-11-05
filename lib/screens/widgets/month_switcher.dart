import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../../app_controller.dart';
import '../../ui/format.dart';

/// Small ‹ October 2026 › pill — shared by Home and Insights. It's both the
/// label for the month on screen and the way to change it.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    return OFinishBox(
      color: t.surface,
      depth: ODepth.soft,
      shape: StadiumBorder(side: context.onyx.finish.hairlines ? BorderSide(color: t.line) : BorderSide.none),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(icon: LucideIcons.chevronLeft, label: 'Previous month', onTap: () => app.shiftMonth(-1)),
          Text(monthLabel(app.month.month), style: context.type.label),
          _Arrow(
            icon: LucideIcons.chevronRight,
            label: 'Next month',
            onTap: app.isCurrentMonth ? null : () => app.shiftMonth(1),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    return OPressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: label,
      child: SizedBox(width: 40, height: 36, child: Icon(icon, size: 18, color: onTap == null ? t.inkFaint : t.ink)),
    );
  }
}
