import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'budgets_screen.dart';
import 'home_screen.dart' show push;
import 'rules_screen.dart';
import 'settings/general_pages.dart';
import 'settings/settings_page.dart';
import 'settings/split_settings_page.dart';

/// Every setting, grouped; each row opens its own page.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final a = app.appearance;
    final review = app.profile.reviewAboveMinor;
    final sources = [
      if (app.smsGranted) 'SMS',
      if (app.notificationsGranted) 'notifications',
      if (app.overlayGranted) 'pop-up',
    ];

    return SettingsPage(
      title: 'Settings',
      children: [
        const SectionHeader('App', top: 0),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: '${switch (a.mode) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              }}, ${a.wallpaperColors ? 'wallpaper colours' : 'Auto Spend colours'}',
              onTap: () => push(context, const AppearancePage()),
            ),
            if (app.isAndroid)
              SettingsRow(
                icon: Icons.widgets_outlined,
                title: 'Home-screen widget',
                subtitle: 'Today, week or month at a glance',
                onTap: () => push(context, const WidgetPage()),
              ),
          ],
        ),
        const SectionHeader('Splitting'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.call_split,
              title: 'Splitwise',
              subtitle: [
                app.swConnected ? 'Connected' : 'Not connected',
                if (app.splitTarget != null) 'default ${app.splitTarget!.label}',
              ].join(', '),
              onTap: () => push(context, const SplitSettingsPage()),
            ),
          ],
        ),
        const SectionHeader('Tracking'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.donut_large_outlined,
              title: 'Budgets',
              subtitle: app.budgets.monthlyMinor == null
                  ? 'No monthly budget'
                  : '${formatCompact(app.budgets.monthlyMinor!)} a month',
              onTap: () => push(context, const BudgetsScreen()),
            ),
            SettingsRow(
              icon: Icons.auto_fix_high_outlined,
              title: 'Rules',
              subtitle: '${app.autoRules.length} keyword, ${app.rules.length} payee',
              onTap: () => push(context, const RulesScreen()),
            ),
            SettingsRow(
              icon: Icons.swap_horiz,
              title: 'Self transfers',
              subtitle: app.profile.name.isEmpty ? 'Add your name' : app.profile.name,
              onTap: () => push(context, const SelfTransfersPage()),
            ),
            SettingsRow(
              icon: Icons.priority_high,
              title: 'Big payments',
              subtitle: review == null ? 'Never ask' : 'Ask above ${formatCompact(review)}',
              onTap: () => push(context, const BigPaymentsPage()),
            ),
          ],
        ),
        const SectionHeader('Phone'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.sms_outlined,
              title: 'Sources',
              subtitle: sources.isEmpty ? 'Nothing allowed yet' : 'Reading ${sources.join(', ')}',
              onTap: () => push(context, const SourcesPage()),
            ),
            SettingsRow(
              icon: Icons.storage_outlined,
              title: 'Data',
              subtitle: 'Re-scan, sample data, clear',
              onTap: () => push(context, const DataPage()),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        Text(
          'Your transactions never leave this phone.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
      ],
    );
  }
}
