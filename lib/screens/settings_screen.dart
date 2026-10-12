import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../sources/widget_bridge.dart';
import '../ui/components.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _name = TextEditingController(text: AppScope.of(context).profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('Removes every transaction, rule and setting from this phone. '
            'Bank SMS can be scanned again afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AppScope.of(context).clearAll();
      _name.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final accounts = app.knownAccounts.toList()..sort();

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxxl),
                  children: [
                    const SectionHeader('Self transfers', top: Space.lg),
                    Tray(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your name', style: text.titleMedium),
                          const SizedBox(height: Space.xs),
                          Text(
                            'Money sent to this name counts as a self transfer, not spending.',
                            style: text.bodySmall?.copyWith(color: t.muted),
                          ),
                          const SizedBox(height: Space.md),
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(hintText: 'As your bank prints it'),
                            onChanged: app.setName,
                          ),
                          const SizedBox(height: Space.xl),
                          Text('Your accounts', style: text.titleMedium),
                          const SizedBox(height: Space.xs),
                          Text(
                            accounts.isEmpty
                                ? 'Learned from your bank SMS after the first scan.'
                                : 'Learned from your bank SMS. Money between these is a self transfer — tap one that isn\'t yours.',
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
                      ),
                    ),
                    const SectionHeader('Big payments'),
                    Tray(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Every payment counts as an expense. Ask me only about payments above:',
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: Space.md),
                          PillSegmented<int>(
                            options: const {
                              200000: '₹2k',
                              500000: '₹5k',
                              1000000: '₹10k',
                              -1: 'Never',
                            },
                            value: app.profile.reviewAboveMinor ?? -1,
                            onChanged: (v) => app.setReviewAbove(v == -1 ? null : v),
                          ),
                        ],
                      ),
                    ),
                    const SectionHeader('Sources'),
                    if (!app.isAndroid)
                      Tray(
                        child: Text(
                          'Reading SMS and notifications needs Android. This preview uses sample bank SMS.',
                          style: text.bodyMedium?.copyWith(color: t.muted),
                        ),
                      )
                    else
                      SurfaceCard(
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                        child: Column(
                          children: [
                            _PermissionRow(
                              icon: Icons.sms_outlined,
                              title: 'Bank SMS',
                              subtitle: app.lastScan == null
                                  ? 'Reads transaction alerts from banks'
                                  : 'Last read ${friendlyTime(app.lastScan!)}',
                              granted: app.smsGranted,
                              onGrant: app.requestSms,
                            ),
                            Divider(height: 1, color: t.tray),
                            _PermissionRow(
                              icon: Icons.notifications_active_outlined,
                              title: 'Payment notifications',
                              subtitle: 'Picks up UPI app payments instantly',
                              granted: app.notificationsGranted,
                              onGrant: app.requestNotifications,
                            ),
                          ],
                        ),
                      ),
                    if (app.isAndroid) ...[
                      const SectionHeader('Home screen'),
                      SurfaceCard(
                        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                              child: Icon(Icons.widgets_outlined, size: 20, color: t.ink),
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Spending widget', style: text.titleMedium),
                                  Text(
                                    'Today, week or month at a glance',
                                    style: text.bodySmall?.copyWith(color: t.muted),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await WidgetBridge.requestPin();
                                if (!ok) {
                                  messenger.showSnackBar(const SnackBar(
                                    content: Text('Long-press your home screen → Widgets → Auto Spend'),
                                  ));
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SectionHeader('Data'),
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: Column(
                        children: [
                          if (app.isAndroid && app.smsGranted)
                            _ActionRow(
                              icon: Icons.refresh,
                              label: 'Re-read last 90 days of SMS',
                              onTap: () => app.scanSms(full: true),
                            ),
                          _ActionRow(
                            icon: Icons.science_outlined,
                            label: app.hasSampleData ? 'Remove sample data' : 'Add sample data',
                            onTap: app.hasSampleData ? app.removeSamples : app.loadSamples,
                          ),
                          _ActionRow(
                            icon: Icons.delete_outline,
                            label: 'Clear all data',
                            onTap: _clearAll,
                            destructive: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xxl),
                    Text(
                      'Your transactions never leave this phone. The internet is used only to talk to Splitwise, and only when you split.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: t.ink),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(subtitle, style: text.bodySmall?.copyWith(color: t.muted)),
              ],
            ),
          ),
          if (granted)
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Icon(Icons.check_circle, color: t.success),
            )
          else
            FilledButton(
              onPressed: onGrant,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
              child: const Text('Allow'),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = destructive ? Theme.of(context).colorScheme.error : t.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
