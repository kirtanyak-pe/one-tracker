import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../../ui/motion.dart';

/// Shell for an L2 settings page: back + title, then content.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children, this.intro});

  final String title;
  final String? intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = context.type;
    return OScreen(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.xxxl),
        children: staggered([
          if (intro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: OSpace.lg),
              child: Text(intro!, style: text.body.copyWith(color: context.colors.inkSoft)),
            ),
          ...children,
        ]),
      ),
    );
  }
}

/// Icon + title + subtitle + trailing, inside a card group.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ORow(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing,
    chevron: trailing == null && onTap != null,
    onTap: onTap,
    destructive: destructive,
  );
}

/// Card holding [SettingsRow]s with hairline dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => OGroup(dividerIndent: OSpace.lg + 20 + OSpace.md + 2, children: children);
}
