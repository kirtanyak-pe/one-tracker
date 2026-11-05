import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';

/// Small ‹ October 2026 › pill — shared by Home and Insights. It's both the
/// label for the month on screen and the way to change it.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    return Material(
      color: t.tray,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(icon: Icons.chevron_left, tooltip: 'Previous month', onTap: () => app.shiftMonth(-1)),
          Text(monthLabel(app.month.month), style: Theme.of(context).textTheme.labelLarge),
          _Arrow(
            icon: Icons.chevron_right,
            tooltip: 'Next month',
            onTap: app.isCurrentMonth ? null : () => app.shiftMonth(1),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 36,
          child: Icon(icon, size: 18, color: onTap == null ? t.muted.withValues(alpha: 0.35) : t.ink),
        ),
      ),
    );
  }
}
