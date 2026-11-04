import 'package:flutter/material.dart';

import '../ui/motion.dart';
import '../ui/tokens.dart';
import 'activity_screen.dart';
import 'home_screen.dart';
import 'widgets/split_prompt_card.dart';
import 'insights_screen.dart';
import 'split_tab.dart';
import '../app_controller.dart';

/// Space a scrolling tab leaves at the bottom so the floating bar never
/// covers its last item.
const navClearance = 112.0;

/// Three tabs under the floating dark pill from the design reference.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const activity = 3;

  /// Lets a tab jump to another ("See all" → Activity).
  static void switchTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_AppShellState>()?._select(index);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A payment came in while the app is open: offer the split here.
    AppScope.of(context).onSplitSuggestion = (payment) {
      if (mounted) showSplitPromptSheet(context, payment);
    };
  }

  /// Tabs are built the first time they're opened, not all at start-up.
  final _visited = <int>{0};

  /// The tab fading out; other hidden tabs are fully offstage (no layout or
  /// paint), which matters on slower phones.
  int? _leaving;

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _leaving = _index;
      _index = i;
      _visited.add(i);
    });
  }

  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.insights_outlined, label: 'Insights'),
    (icon: Icons.call_split, label: 'Split'),
    (icon: Icons.receipt_long_outlined, label: 'Activity'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    // Tabs keep their state but cross-fade with a slight zoom. Only the
    // visible tab (and the one fading out) is laid out and painted.
    body: Stack(
      children: [
        for (final (i, tab) in const [HomeTab(), InsightsTab(), SplitTab(), ActivityTab()].indexed)
          Offstage(
            key: ValueKey('tab-$i'),
            offstage: i != _index && i != _leaving,
            child: IgnorePointer(
              ignoring: i != _index,
              child: ExcludeSemantics(
                excluding: i != _index,
                child: AnimatedOpacity(
                  opacity: i == _index ? 1 : 0,
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.enter,
                  onEnd: () {
                    if (i == _leaving && mounted) setState(() => _leaving = null);
                  },
                  child: AnimatedScale(
                    scale: i == _index ? 1 : 0.985,
                    duration: Motion.of(context, Motion.medium),
                    curve: Motion.enter,
                    // Pause hidden tabs' own animations — but inside the
                    // fade, or the fade-out itself would freeze half-way.
                    child: TickerMode(
                      enabled: i == _index,
                      child: _visited.contains(i) ? tab : const SizedBox.shrink(),
                    ),
                  ),
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
          colors: dark ? const [Color(0xFF2A2A2A), Color(0xFF3A3A3A)] : const [Color(0xFF5E5E5E), Color(0xFF8A8A8A)],
        ),
        boxShadow: Shadows.floating,
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
