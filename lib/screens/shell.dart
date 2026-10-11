import 'package:flutter/material.dart';

import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'activity_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';

/// Space a scrolling tab leaves at the bottom so the floating bar never
/// covers its last item.
const navClearance = 112.0;

/// Three tabs under the floating dark pill from the design reference.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Lets a tab jump to another ("See all" → Activity).
  static void switchTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_AppShellState>()?._select(index);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.insights_outlined, label: 'Insights'),
    (icon: Icons.receipt_long_outlined, label: 'Activity'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        // Tabs stay alive (like IndexedStack) but cross-fade with a slight
        // zoom when switching.
        body: Stack(
          children: [
            for (final (i, tab) in const [HomeTab(), InsightsTab(), ActivityTab()].indexed)
              IgnorePointer(
                ignoring: i != _index,
                child: ExcludeSemantics(
                  excluding: i != _index,
                  child: AnimatedOpacity(
                    opacity: i == _index ? 1 : 0,
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.enter,
                    child: AnimatedScale(
                      scale: i == _index ? 1 : 0.985,
                      duration: Motion.of(context, Motion.medium),
                      curve: Motion.enter,
                      // Pause hidden tabs' own animations — but inside the
                      // fade, or the fade-out itself would freeze half-way.
                      child: TickerMode(enabled: i == _index, child: tab),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
          child: _NavPill(index: _index, onSelect: _select),
        ),
      );
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.pill),
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF2A2A2A), Color(0xFF3A3A3A)]
              : const [Color(0xFF5E5E5E), Color(0xFF8A8A8A)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tab) in _AppShellState._tabs.indexed)
            Expanded(
              flex: i == index ? 5 : 3,
              child: Semantics(
                selected: i == index,
                button: true,
                label: tab.label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.medium),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tab.icon, size: 22, color: i == index ? const Color(0xFF111111) : Colors.white),
                        if (i == index) ...[
                          const SizedBox(width: Space.sm),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tab.label,
                                maxLines: 1,
                                style: text.labelLarge?.copyWith(color: const Color(0xFF111111)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
