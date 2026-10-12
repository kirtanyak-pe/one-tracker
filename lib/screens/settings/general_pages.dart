import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../model/appearance.dart';
import '../../sources/widget_bridge.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/tokens.dart';
import 'settings_page.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = app.appearance;
    final text = Theme.of(context).textTheme;
    final t = context.tokens;
    return SettingsPage(
      title: 'Appearance',
      children: [
        const SectionHeader('Theme', top: 0),
        PillSegmented<ThemeMode>(
          options: const {ThemeMode.system: 'System', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'},
          value: a.mode,
          onChanged: (m) => app.setAppearance(a.copyWith(mode: m)),
        ),
        const SizedBox(height: Space.sm),
        Text('System follows your phone\'s light/dark setting.', style: text.bodySmall?.copyWith(color: t.muted)),
        const SectionHeader('Colours'),
        PillSegmented<bool>(
          options: const {true: 'Wallpaper', false: 'Auto Spend'},
          value: a.wallpaperColors,
          onChanged: (w) => app.setAppearance(a.copyWith(wallpaperColors: w)),
        ),
        const SizedBox(height: Space.sm),
        Text(
          a.wallpaperColors
              ? (app.wallpaper == null
                  ? "Your phone doesn't share wallpaper colours, so Auto Spend's orange is used."
                  : 'Colours come from your wallpaper (Material You).')
              : "Auto Spend's own warm grey and orange.",
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
        const SectionHeader('Animations & effects'),
        PillSegmented<Effects>(
          options: const {Effects.auto: 'Auto', Effects.reduced: 'Reduced', Effects.full: 'Full'},
          value: a.effects,
          onChanged: (e) => app.setAppearance(a.copyWith(effects: e)),
        ),
        const SizedBox(height: Space.sm),
        Text(
          switch (a.effects) {
            Effects.auto => app.lowEndDevice
                ? 'This phone looks low on memory, so animations and soft shadows are off to keep it smooth.'
                : 'Full effects on this phone; turned down automatically on low-memory phones.',
            Effects.reduced => 'No animations or soft shadows. Smoothest on slower phones.',
            Effects.full => 'All animations and shadows, on any phone.',
          },
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
        const SizedBox(height: Space.xl),
        _Preview(),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Tray(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: text.titleMedium),
                Text('Cards, buttons and the accent', style: text.bodySmall?.copyWith(color: t.muted)),
                const SizedBox(height: Space.md),
                FilledButton(onPressed: () {}, child: const Text('Button')),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          AccentOrb(icon: Icons.bolt, onPressed: () {}, tooltip: 'Accent'),
        ],
      ),
    );
  }
}

class SelfTransfersPage extends StatefulWidget {
  const SelfTransfersPage({super.key});

  @override
  State<SelfTransfersPage> createState() => _SelfTransfersPageState();
}

class _SelfTransfersPageState extends State<SelfTransfersPage> {
  late final _name = TextEditingController(text: AppScope.of(context).profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final accounts = app.knownAccounts.toList()..sort();
    return SettingsPage(
      title: 'Self transfers',
      intro: "Money moving between your own accounts isn't spending. These help spot it.",
      children: [
        const SectionHeader('Your name', top: 0),
        Text(
          'Money sent to this name counts as a self transfer.',
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'As your bank prints it'),
          onChanged: app.setName,
        ),
        const SectionHeader('Your accounts'),
        Text(
          accounts.isEmpty
              ? 'Learned from your bank SMS after the first scan.'
              : "Learned from your bank SMS. Money between these is a self transfer. Tap one that isn't yours.",
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final a in accounts)
                FilterChip(
                  label: Text('••$a'),
                  selected: !app.profile.ignoredAccounts.contains(a),
                  showCheckmark: true,
                  checkmarkColor: t.onInk,
                  selectedColor: t.ink,
                  backgroundColor: t.card,
                  labelStyle: text.labelLarge?.copyWith(
                    color: app.profile.ignoredAccounts.contains(a) ? t.muted : t.onInk,
                  ),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onSelected: (_) => app.toggleAccount(a),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class BigPaymentsPage extends StatelessWidget {
  const BigPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SettingsPage(
      title: 'Big payments',
      intro: 'Every payment counts as an expense. Ask me only about payments above:',
      children: [
        PillSegmented<int>(
          options: const {200000: '₹2k', 500000: '₹5k', 1000000: '₹10k', -1: 'Never'},
          value: app.profile.reviewAboveMinor ?? -1,
          onChanged: (v) => app.setReviewAbove(v == -1 ? null : v),
        ),
      ],
    );
  }
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget allow(bool granted, VoidCallback onGrant) => granted
        ? Padding(padding: const EdgeInsets.all(Space.sm), child: Icon(Icons.check_circle, color: t.success))
        : FilledButton(
            onPressed: onGrant,
            style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
            child: const Text('Allow'),
          );
    return SettingsPage(
      title: 'Sources',
      intro: 'Where Auto Spend finds your payments. Everything is read on this phone.',
      children: [
        if (!app.isAndroid)
          Tray(
            child: Text(
              'Reading SMS and notifications needs Android. This preview uses sample bank SMS.',
              style: text.bodyMedium?.copyWith(color: t.muted),
            ),
          )
        else
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.sms_outlined,
                title: 'Bank SMS',
                subtitle: app.lastScan == null
                    ? 'Reads bank alerts, instantly as they arrive'
                    : 'Instant. Last full read ${friendlyTime(app.lastScan!)}',
                trailing: allow(app.smsGranted, app.requestSms),
              ),
              SettingsRow(
                icon: Icons.notifications_active_outlined,
                title: 'Payment notifications',
                subtitle: 'Also catches UPI app payments',
                trailing: allow(app.notificationsGranted, app.requestNotifications),
              ),
              SettingsRow(
                icon: Icons.picture_in_picture_alt_outlined,
                title: 'Float over other apps',
                subtitle: 'For the split pop-up after you pay',
                trailing: allow(app.overlayGranted, app.requestOverlay),
              ),
            ],
          ),
      ],
    );
  }
}

class WidgetPage extends StatelessWidget {
  const WidgetPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'Home-screen widget',
        intro: "Today, this week or this month's spending at a glance, with a toggle on the widget itself.",
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await WidgetBridge.requestPin();
                if (!ok) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Long-press your home screen → Widgets → Auto Spend')),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add to home screen'),
            ),
          ),
        ],
      );
}

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  Future<void> _clearAll(BuildContext context) async {
    final app = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'Removes every transaction, rule, budget and setting from this phone, and disconnects Splitwise. '
          'Bank SMS can be scanned again afterwards.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await app.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SettingsPage(
      title: 'Data',
      children: [
        SettingsGroup(
          children: [
            if (app.isAndroid && app.smsGranted)
              SettingsRow(
                icon: Icons.refresh,
                title: 'Re-read last 90 days of SMS',
                onTap: () => app.scanSms(full: true),
              ),
            SettingsRow(
              icon: Icons.science_outlined,
              title: app.hasSampleData ? 'Remove sample data' : 'Add sample data',
              onTap: app.hasSampleData ? app.removeSamples : app.loadSamples,
            ),
            SettingsRow(
              icon: Icons.delete_outline,
              title: 'Clear all data',
              destructive: true,
              onTap: () => _clearAll(context),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        Text(
          'Your transactions never leave this phone. The internet is used only to talk to Splitwise, '
          'and only when you split.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: t.muted),
        ),
      ],
    );
  }
}
