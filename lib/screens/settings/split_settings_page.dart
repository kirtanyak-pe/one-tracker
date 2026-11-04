import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../split/group_link.dart';
import '../../ui/components.dart';
import '../../ui/tokens.dart';
import 'settings_page.dart';

/// Splitwise: when to offer a split, the default group, and a test.
/// Nothing here goes online: payments are handed to the Splitwise app.
class SplitSettingsPage extends StatelessWidget {
  const SplitSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.splitSettings;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SettingsPage(
      title: 'Splitwise',
      intro: 'After you pay, One Tracker offers to open Splitwise with the payment filled in. '
          'You choose who to split with there.',
      children: [
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Split notifications', style: text.titleMedium),
                        Text('Right after each new payment', style: text.bodySmall?.copyWith(color: t.muted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: s.notify,
                    activeTrackColor: t.ink,
                    onChanged: (v) {
                      app.setSplitSettings(s.copyWith(notify: v));
                      if (v && app.isAndroid && !app.postNotificationsGranted) app.requestPostNotifications();
                    },
                  ),
                ],
              ),
              if (s.notify && app.isAndroid && !app.postNotificationsGranted) ...[
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications are blocked for One Tracker',
                        style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                    FilledButton(
                      onPressed: app.requestPostNotifications,
                      style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                      child: const Text('Allow'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Space.md),
              Text('Only for payments above', style: text.bodySmall?.copyWith(color: t.muted)),
              const SizedBox(height: Space.sm),
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: PillSegmented<int>(
                  options: const {0: 'Any', 10000: '₹100', 50000: '₹500', 100000: '₹1k'},
                  value: s.minMinor,
                  onChanged: (v) => app.setSplitSettings(s.copyWith(minMinor: v)),
                ),
              ),
            ],
          ),
        ),
        const SectionHeader('Default group'),
        SurfaceCard(
          onTap: () => _editGroup(context, app),
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                child: Icon(Icons.groups_outlined, color: t.ink),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.groupId == null ? 'Not set' : (s.groupName ?? 'Group ${s.groupId}'),
                      style: text.titleMedium,
                    ),
                    Text(
                      s.groupId == null
                          ? 'Splitwise asks who to split with each time'
                          : 'New expenses start in this group',
                      style: text.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => _editGroup(context, app),
                style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                child: Text(s.groupId == null ? 'Set' : 'Change'),
              ),
            ],
          ),
        ),
        const SectionHeader('Try it'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.open_in_new,
              title: 'Open Splitwise with ₹1 · Test',
              subtitle: 'Checks the hand-off works on this phone',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await app.tryOpenSplitwise();
                if (!ok) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(app.isAndroid ? 'Splitwise is not installed' : 'Needs Android with Splitwise')),
                  );
                }
              },
            ),
            if (app.isAndroid)
              SettingsRow(
                icon: Icons.notifications_none,
                title: 'Send a test notification',
                subtitle: 'For your latest payment',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await app.sendTestSplitNotification();
                  if (!ok) messenger.showSnackBar(const SnackBar(content: Text('No payment to use yet')));
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _editGroup(BuildContext context, AppController app) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _GroupSheet(app: app),
      );
}

/// Paste the group's link from Splitwise on the web (the number in it is the
/// group id) and optionally name it.
class _GroupSheet extends StatefulWidget {
  const _GroupSheet({required this.app});

  final AppController app;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late final _link = TextEditingController(text: widget.app.splitSettings.groupId?.toString() ?? '');
  late final _name = TextEditingController(text: widget.app.splitSettings.groupName ?? '');

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  int? get _id => parseGroupId(_link.text);

  void _save() {
    final app = widget.app;
    app.setSplitSettings(app.splitSettings.withGroup(_id, _name.text));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final hasText = _link.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            Space.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Default group', style: text.titleLarge),
              const SizedBox(height: Space.xs),
              Text(
                'On splitwise.com open the group and copy its link from the address bar, '
                'like secure.splitwise.com/#/groups/12345678. Paste it here.',
                style: text.bodySmall?.copyWith(color: t.muted),
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _link,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'Group link or number',
                  errorText: hasText && _id == null ? 'No group number found in that' : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Name (optional), e.g. Flatmates'),
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  if (widget.app.splitSettings.groupId != null)
                    TextButton(
                      onPressed: () {
                        widget.app.setSplitSettings(widget.app.splitSettings.withGroup(null));
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  const Spacer(),
                  FilledButton(onPressed: _id == null ? null : _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
