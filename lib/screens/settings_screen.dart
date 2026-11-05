import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../money.dart';

import 'package:onyx/onyx.dart';

import 'budgets_screen.dart';
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
    final text = context.type;
    final a = app.appearance;
    final review = app.profile.reviewAboveMinor;
    final sources = [if (app.smsGranted) 'SMS', if (app.notificationsGranted) 'notifications'];

    return SettingsPage(
      title: 'Settings',
      children: [
        const OSectionHeader('App', top: 0),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: LucideIcons.palette,
              title: 'Appearance',
              subtitle:
                  '${switch (a.mode) {
                    OThemeMode.system => 'System',
                    OThemeMode.light => 'Light',
                    OThemeMode.dark => 'Dark',
                  }}${app.lite ? ', lite' : ''}',
              onTap: () => pushScreen(context, const AppearancePage()),
            ),
            if (app.isAndroid)
              SettingsRow(
                icon: LucideIcons.layoutGrid,
                title: 'Home-screen widget',
                subtitle: 'Today, week or month at a glance',
                onTap: () => pushScreen(context, const WidgetPage()),
              ),
          ],
        ),
        const OSectionHeader('Splitting'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: LucideIcons.split,
              title: 'Splitwise',
              subtitle: [
                app.splitSettings.notify ? 'Notifies after a payment' : 'Notifications off',
                if (app.splitSettings.groupId != null)
                  'group ${app.splitSettings.groupName ?? app.splitSettings.groupId}',
              ].join(', '),
              onTap: () => pushScreen(context, const SplitSettingsPage()),
            ),
          ],
        ),
        const OSectionHeader('Tracking'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: LucideIcons.chartPie,
              title: 'Budgets',
              subtitle: app.budgets.monthlyMinor == null
                  ? 'No monthly budget'
                  : '${formatCompact(app.budgets.monthlyMinor!)} a month',
              onTap: () => pushScreen(context, const BudgetsScreen()),
            ),
            SettingsRow(
              icon: LucideIcons.wandSparkles,
              title: 'Rules',
              subtitle: '${app.autoRules.length} keyword, ${app.rules.length} payee',
              onTap: () => pushScreen(context, const RulesScreen()),
            ),
            SettingsRow(
              icon: LucideIcons.arrowLeftRight,
              title: 'Self transfers',
              subtitle: app.profile.name.isEmpty ? 'Add your name' : app.profile.name,
              onTap: () => pushScreen(context, const SelfTransfersPage()),
            ),
            SettingsRow(
              icon: LucideIcons.circleAlert,
              title: 'Big payments',
              subtitle: review == null ? 'Never ask' : 'Ask above ${formatCompact(review)}',
              onTap: () => pushScreen(context, const BigPaymentsPage()),
            ),
          ],
        ),
        const OSectionHeader('Phone'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: LucideIcons.messageSquareText,
              title: 'Sources',
              subtitle: sources.isEmpty ? 'Nothing allowed yet' : 'Reading ${sources.join(', ')}',
              onTap: () => pushScreen(context, const SourcesPage()),
            ),
            SettingsRow(
              icon: LucideIcons.database,
              title: 'Data',
              subtitle: 'Re-scan, sample data, clear',
              onTap: () => pushScreen(context, const DataPage()),
            ),
          ],
        ),
        const SizedBox(height: OSpace.xxl),
        Text('Your transactions never leave this phone.', textAlign: TextAlign.center, style: text.small),
      ],
    );
  }
}
