import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../ui/motion.dart';

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

  static const _tabs = <OTab>[
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.chartNoAxesColumn, label: 'Insights'),
    (icon: LucideIcons.split, label: 'Split'),
    (icon: LucideIcons.receiptText, label: 'Activity'),
  ];

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // Tabs keep their state but cross-fade with a slight zoom. Only the
      // visible tab (and the one fading out) is laid out and painted.
      Stack(
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
      // A swipe up from the bottom edge is the system's home / app-switch
      // gesture: the strip from the screen edge to a little above the bar
      // swallows drags so the list underneath doesn't scroll with it.
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: MediaQuery.paddingOf(context).bottom + OSpace.md + OTabBar.height + OSpace.lg,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) {},
          onVerticalDragUpdate: (_) {},
          excludeFromSemantics: true,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(OSpace.gutter, 0, OSpace.gutter, OSpace.md),
          child: OTabBar(tabs: _tabs, index: _index, onSelect: _select),
        ),
      ),
    ],
  );
}
