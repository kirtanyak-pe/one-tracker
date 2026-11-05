import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../split/group_link.dart';

import 'package:onyx/onyx.dart';

import 'settings_page.dart';

/// Splitwise: when to offer a split, the default group, and a test.
/// Nothing here goes online: payments are handed to the Splitwise app.
class SplitSettingsPage extends StatelessWidget {
  const SplitSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.splitSettings;
    final t = context.colors;
    final text = context.type;
    return SettingsPage(
      title: 'Splitwise',
      intro:
          'After you pay, One Tracker offers to open Splitwise with the payment filled in. '
          'You choose who to split with there.',
      children: [
        OCard(
          padding: const EdgeInsets.all(OSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Split notifications', style: text.bodyStrong),
                        Text('Right after each new payment', style: text.small),
                      ],
                    ),
                  ),
                  OToggle(
                    value: s.notify,
                    label: 'Split notifications',
                    onChanged: (v) {
                      app.setSplitSettings(s.copyWith(notify: v));
                      if (v && app.isAndroid && !app.postNotificationsGranted) app.requestPostNotifications();
                    },
                  ),
                ],
              ),
              if (s.notify && app.isAndroid && !app.postNotificationsGranted) ...[
                const SizedBox(height: OSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications are blocked for One Tracker',
                        style: text.small.copyWith(color: t.negative),
                      ),
                    ),
                    const SizedBox(width: OSpace.md),
                    OButton(label: 'Allow', size: OButtonSize.sm, onPressed: app.requestPostNotifications),
                  ],
                ),
              ],
              const SizedBox(height: OSpace.lg),
              Text('Only for payments above', style: text.small),
              const SizedBox(height: OSpace.sm),
              OSegmented<int>(
                values: const [0, 10000, 50000, 100000],
                labelOf: (v) => const {0: 'Any', 10000: '₹100', 50000: '₹500', 100000: '₹1k'}[v]!,
                selected: s.minMinor,
                onChanged: (v) => app.setSplitSettings(s.copyWith(minMinor: v)),
              ),
            ],
          ),
        ),
        const OSectionHeader('Default group'),
        OGroup(
          children: [
            ORow(
              onTap: () => _editGroup(context, app),
              leading: const Icon(LucideIcons.users),
              title: Text(s.groupId == null ? 'Not set' : (s.groupName ?? 'Group ${s.groupId}')),
              subtitle: Text(
                s.groupId == null ? 'Splitwise asks who to split with each time' : 'New expenses start in this group',
              ),
              trailing: OButton.secondary(
                label: s.groupId == null ? 'Set' : 'Change',
                size: OButtonSize.sm,
                onPressed: () => _editGroup(context, app),
              ),
            ),
          ],
        ),
        const OSectionHeader('Try it'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: LucideIcons.externalLink,
              title: 'Open Splitwise with ₹1 · Test',
              subtitle: 'Checks the hand-off works on this phone',
              onTap: () async {
                final ok = await app.tryOpenSplitwise();
                if (!ok && context.mounted) {
                  OToast.show(context, app.isAndroid ? 'Splitwise is not installed' : 'Needs Android with Splitwise');
                }
              },
            ),
            if (app.isAndroid)
              SettingsRow(
                icon: LucideIcons.bell,
                title: 'Send a test notification',
                subtitle: 'For your latest payment',
                onTap: () async {
                  final ok = await app.sendTestSplitNotification();
                  if (!ok && context.mounted) OToast.show(context, 'No payment to use yet');
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _editGroup(BuildContext context, AppController app) =>
      showOSheet<void>(context, builder: (_) => _GroupSheet(app: app));
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
    final hasText = _link.text.trim().isNotEmpty;
    return OSheetBody(
      title: 'Default group',
      subtitle:
          'On splitwise.com open the group and copy its link from the address bar, '
          'like secure.splitwise.com/#/groups/12345678. Paste it here.',
      actions: [
        OButton(label: 'Save', expand: true, onPressed: _id == null ? null : _save),
        if (widget.app.splitSettings.groupId != null)
          OButton.ghost(
            label: 'Clear',
            expand: true,
            onPressed: () {
              widget.app.setSplitSettings(widget.app.splitSettings.withGroup(null));
              Navigator.pop(context);
            },
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OField(
            controller: _link,
            autocorrect: false,
            keyboardType: TextInputType.url,
            placeholder: 'Group link or number',
            error: hasText && _id == null ? 'No group number found in that' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: OSpace.md),
          OField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            placeholder: 'Name (optional), e.g. Flatmates',
          ),
        ],
      ),
    );
  }
}
