import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../model/appearance.dart';
import '../../sources/backup_bridge.dart';
import '../../sources/widget_bridge.dart';
import '../../storage/backup.dart';
import '../../ui/format.dart';

import 'package:onyx/onyx.dart';

import 'settings_page.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = app.appearance;
    final text = context.type;
    final t = context.colors;
    return SettingsPage(
      title: 'Appearance',
      children: [
        const OSectionHeader('Theme', top: 0),
        OSegmented<OThemeMode>(
          values: OThemeMode.values,
          selected: a.mode,
          labelOf: (m) => switch (m) {
            OThemeMode.system => 'System',
            OThemeMode.light => 'Light',
            OThemeMode.dark => 'Dark',
          },
          onChanged: (m) => app.setAppearance(a.copyWith(mode: m)),
        ),
        const SizedBox(height: OSpace.sm),
        Text('System follows your phone\'s light/dark setting.', style: text.small.copyWith(color: t.inkSoft)),
        const OSectionHeader('Animations & effects'),
        OSegmented<Effects>(
          values: Effects.values,
          selected: a.effects,
          labelOf: (e) => switch (e) {
            Effects.auto => 'Auto',
            Effects.reduced => 'Reduced',
            Effects.full => 'Full',
          },
          onChanged: (e) => app.setAppearance(a.copyWith(effects: e)),
        ),
        const SizedBox(height: OSpace.sm),
        Text(switch (a.effects) {
          Effects.auto =>
            app.lowEndDevice
                ? 'This phone looks low on memory, so animations and soft shadows are off to keep it smooth.'
                : 'Full effects on this phone; turned down automatically on low-memory phones.',
          Effects.reduced => 'No animations or soft shadows. Smoothest on slower phones.',
          Effects.full => 'All animations and shadows, on any phone.',
        }, style: text.small.copyWith(color: t.inkSoft)),
        const SizedBox(height: OSpace.xl),
        _Preview(),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    return OInset(
      padding: const EdgeInsets.all(OSpace.xl),
      radius: ORadius.lg,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: text.title3),
                Text('Cards, buttons and the accent', style: text.small.copyWith(color: t.inkSoft)),
                const SizedBox(height: OSpace.md),
                OButton(label: 'Button', size: OButtonSize.sm, onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(width: OSpace.md),
          OIconButton(
            icon: LucideIcons.zap,
            label: 'Accent',
            onPressed: () {},
            size: 44,
            background: t.ink,
            color: t.onInk,
          ),
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
    final t = context.colors;
    final text = context.type;
    final accounts = app.knownAccounts.toList()..sort();
    return SettingsPage(
      title: 'Self transfers',
      intro: "Money moving between your own accounts isn't spending. These help spot it.",
      children: [
        const OSectionHeader('Your name', top: 0),
        Text('Money sent to this name counts as a self transfer.', style: text.small.copyWith(color: t.inkSoft)),
        const SizedBox(height: OSpace.md),
        OField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          placeholder: 'As your bank prints it',
          onChanged: app.setName,
        ),
        const OSectionHeader('Your accounts'),
        Text(
          accounts.isEmpty
              ? 'Learned from your bank SMS after the first scan.'
              : "Learned from your bank SMS. Money between these is a self transfer. Tap one that isn't yours.",
          style: text.small.copyWith(color: t.inkSoft),
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: OSpace.md),
          Wrap(
            spacing: OSpace.sm,
            runSpacing: OSpace.sm,
            children: [
              for (final a in accounts)
                OChip(
                  label: '••$a',
                  selected: !app.profile.ignoredAccounts.contains(a),
                  icon: app.profile.ignoredAccounts.contains(a) ? null : LucideIcons.check,
                  onTap: () => app.toggleAccount(a),
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
        OSegmented<int>(
          values: const [200000, 500000, 1000000, -1],
          labelOf: (v) => const {200000: '₹2k', 500000: '₹5k', 1000000: '₹10k', -1: 'Never'}[v]!,
          selected: app.profile.reviewAboveMinor ?? -1,
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
    final t = context.colors;
    final text = context.type;
    Widget allow(bool granted, VoidCallback onGrant) => granted
        ? Padding(
            padding: const EdgeInsets.all(OSpace.sm),
            child: Icon(LucideIcons.circleCheck, color: t.positive),
          )
        : OButton(label: 'Allow', size: OButtonSize.sm, onPressed: onGrant);
    return SettingsPage(
      title: 'Sources',
      intro: 'Where One Tracker finds your payments. Everything is read on this phone.',
      children: [
        if (!app.isAndroid)
          OInset(
            padding: const EdgeInsets.all(OSpace.xl),
            radius: ORadius.lg,
            child: Text(
              'Reading SMS and notifications needs Android. This preview uses sample bank SMS.',
              style: text.body.copyWith(color: t.inkSoft),
            ),
          )
        else
          SettingsGroup(
            children: [
              SettingsRow(
                icon: LucideIcons.messageSquareText,
                title: 'Bank SMS',
                subtitle: app.lastScan == null
                    ? 'Reads bank alerts, instantly as they arrive'
                    : 'Instant. Last full read ${friendlyTime(app.lastScan!)}',
                trailing: allow(app.smsGranted, app.requestSms),
              ),
              SettingsRow(
                icon: LucideIcons.bellRing,
                title: 'Payment notifications',
                subtitle: 'Also catches UPI app payments',
                trailing: allow(app.notificationsGranted, app.requestNotifications),
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
      OButton(
        label: 'Add to home screen',
        icon: LucideIcons.plus,
        expand: true,
        onPressed: () async {
          final ok = await WidgetBridge.requestPin();
          if (!ok && context.mounted) {
            OToast.show(context, 'Long-press your home screen → Widgets → One Tracker');
          }
        },
      ),
    ],
  );
}

class DataPage extends StatelessWidget {
  const DataPage({super.key});

  Future<void> _clearAll(BuildContext context) async {
    final app = AppScope.of(context);
    final ok = await showOConfirm(
      context,
      title: 'Clear all data?',
      message:
          'Removes every transaction, rule, budget and setting from this phone, and disconnects Splitwise. '
          'Bank SMS can be scanned again afterwards.',
      confirm: 'Clear',
      destructive: true,
    );
    if (ok) await app.clearAll();
  }

  void _say(BuildContext context, String message) => OToast.show(context, message);

  Future<void> _backUp(BuildContext context) async {
    final app = AppScope.of(context);
    try {
      final saved = await app.exportBackup();
      if (saved && context.mounted) _say(context, 'Backup saved');
    } catch (_) {
      if (context.mounted) {
        _say(context, "Couldn't save the backup. Try another location.");
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final app = AppScope.of(context);
    final Backup backup;
    try {
      final raw = await BackupBridge.pick();
      if (raw == null) return;
      backup = Backup.parse(raw);
    } on BackupException catch (e) {
      if (context.mounted) _say(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) _say(context, "Couldn't read that file.");
      return;
    }
    if (!context.mounted) return;
    final when = backup.exportedAt;
    final ok = await showOConfirm(
      context,
      title: 'Restore this backup?',
      message:
          'Replace everything on this phone with the backup'
          '${when == null ? '' : ' from ${when.day} ${_months[when.month - 1]} ${when.year}'}? '
          '${backup.payments} ${backup.payments == 1 ? 'payment' : 'payments'}.',
      confirm: 'Restore',
    );
    if (!ok) return;
    try {
      await app.restoreBackup(backup);
      if (context.mounted) _say(context, 'Backup restored');
    } catch (_) {
      if (context.mounted) _say(context, "Couldn't restore that backup.");
    }
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    return SettingsPage(
      title: 'Data',
      children: [
        SettingsGroup(
          children: [
            if (app.isAndroid && app.smsGranted)
              SettingsRow(
                icon: LucideIcons.refreshCw,
                title: 'Re-read last 90 days of SMS',
                onTap: () => app.scanSms(full: true),
              ),
            if (BackupBridge.isSupported) ...[
              SettingsRow(
                icon: LucideIcons.fileUp,
                title: 'Back up data',
                subtitle: 'Save everything to a file',
                onTap: () => _backUp(context),
              ),
              SettingsRow(
                icon: LucideIcons.archiveRestore,
                title: 'Restore from backup',
                subtitle: 'Replaces what is on this phone',
                onTap: () => _restore(context),
              ),
            ],
            SettingsRow(
              icon: LucideIcons.flaskConical,
              title: app.hasSampleData ? 'Remove sample data' : 'Add sample data',
              onTap: app.hasSampleData ? app.removeSamples : app.loadSamples,
            ),
            SettingsRow(
              icon: LucideIcons.trash2,
              title: 'Clear all data',
              destructive: true,
              onTap: () => _clearAll(context),
            ),
          ],
        ),
        const SizedBox(height: OSpace.xxl),
        Text(
          'Your transactions never leave this phone. The internet is used only to talk to Splitwise, '
          'and only when you split.',
          textAlign: TextAlign.center,
          style: text.small.copyWith(color: t.inkSoft),
        ),
      ],
    );
  }
}
