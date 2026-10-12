import 'package:flutter/material.dart';

import '../../ui/components.dart';
import '../../ui/motion.dart';
import '../../ui/tokens.dart';

/// Shell for an L2 settings page: back + title, then content.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children, this.intro});

  final String title;
  final String? intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: title),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxxl),
                  children: staggered([
                    if (intro != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.lg),
                        child: Text(intro!, style: text.bodyMedium?.copyWith(color: t.muted)),
                      ),
                    ...children,
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + title + subtitle + trailing, inside a white card group.
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = destructive ? Theme.of(context).colorScheme.error : t.ink;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium?.copyWith(color: color)),
                    if (subtitle != null)
                      Text(subtitle!, style: text.bodySmall?.copyWith(color: t.muted)),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null) Icon(Icons.chevron_right, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// White card holding [SettingsRow]s with hairline dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 68, color: t.tray),
            c,
          ],
        ],
      ),
    );
  }
}
