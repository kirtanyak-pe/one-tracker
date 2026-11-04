import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';

/// ‹ October 2026 › — shared by Home and Insights.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.tray,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => app.shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          SizedBox(
            width: 132,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                monthLabel(app.month.month),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: app.isCurrentMonth ? null : () => app.shiftMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
