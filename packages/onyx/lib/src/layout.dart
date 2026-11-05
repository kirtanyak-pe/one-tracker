import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'button.dart';
import 'pressable.dart';
import 'surface.dart';
import 'theme.dart';
import 'tokens.dart';

/// A pushed screen: canvas, an optional [OTopBar] and the body below it.
class OScreen extends StatelessWidget {
  const OScreen({super.key, this.title, this.trailing, required this.body, this.bottom, this.back = true});

  final String? title;
  final Widget? trailing;
  final Widget body;

  /// Pinned under the body, above the keyboard (say, a Save button).
  final Widget? bottom;
  final bool back;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.canvas,
    child: Column(
      children: [
        if (title != null || back)
          SafeArea(
            bottom: false,
            child: OTopBar(title: title ?? '', trailing: trailing, back: back),
          ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: title != null || back, child: body),
        ),
        if (bottom != null)
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.md),
              child: bottom!,
            ),
          ),
      ],
    ),
  );
}

/// Back · centred title · trailing.
class OTopBar extends StatelessWidget {
  const OTopBar({super.key, required this.title, this.trailing, this.back = true});

  final String title;
  final Widget? trailing;
  final bool back;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: OSpace.sm + 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: back
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: OIconButton(
                      icon: LucideIcons.chevronLeft,
                      iconSize: 24,
                      label: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.title3,
            ),
          ),
          SizedBox(
            width: 52,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    ),
  );
}

/// A top-level tab: a large left-aligned title with actions, fixed above
/// the tab's scroll view. A hairline appears once content scrolls under it,
/// and [scrolledTitle] can take the title's place past [swapAfter].
/// [glow] lays a soft accent light behind the top of the page — for a
/// screen led by one hero number, not for every tab.
class OTabPage extends StatefulWidget {
  const OTabPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.scrolledTitle,
    this.swapAfter = 80,
    this.glow = false,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? scrolledTitle;
  final double swapAfter;
  final bool glow;

  @override
  State<OTabPage> createState() => _OTabPageState();
}

class _OTabPageState extends State<OTabPage> {
  bool _under = false;
  bool _swapped = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final under = n.metrics.pixels > 0;
    final swapped = widget.scrolledTitle != null && n.metrics.pixels > widget.swapAfter;
    if (under != _under || swapped != _swapped) {
      setState(() {
        _under = under;
        _swapped = swapped;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final d = OMotion.of(context, OMotion.base);
    final c = context.colors;
    final bar = Column(
      children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OSpace.gutter),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: d,
                      switchInCurve: OMotion.emphasized,
                      switchOutCurve: OMotion.exit,
                      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: _swapped
                          ? KeyedSubtree(
                              key: const ValueKey('swapped'),
                              child: DefaultTextStyle.merge(style: t.title2, child: widget.scrolledTitle!),
                            )
                          : Semantics(
                              key: const ValueKey('title'),
                              header: true,
                              child: Text(widget.title, style: t.title2, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                    ),
                  ),
                  for (final (i, a) in widget.actions.indexed) ...[if (i > 0) const SizedBox(width: OSpace.sm), a],
                ],
              ),
            ),
          ),
        ),
        AnimatedOpacity(opacity: _under ? 1 : 0, duration: d, child: const ODivider()),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.body),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: c.canvas,
      child: widget.glow
          ? Stack(
              children: [
                Positioned(
                  top: -160,
                  left: -120,
                  right: -120,
                  height: 560,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            c.accent.withValues(alpha: context.onyx.isDark ? 0.26 : 0.12),
                            c.accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bar,
              ],
            )
          : bar,
    );
  }
}

typedef OTab = ({IconData icon, String label});

/// The floating tab bar: a surface capsule; the selected tab becomes an ink
/// pill with its label.
class OTabBar extends StatelessWidget {
  const OTabBar({super.key, required this.tabs, required this.index, required this.onSelect});

  final List<OTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  /// Height of the bar itself (add the bottom inset and margin around it).
  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: StadiumBorder(side: BorderSide(color: c.line)),
        shadows: OShadow.floating(context.onyx.brightness),
      ),
      // One position drives everything: the pill slides from tab to tab while
      // the tab it leaves narrows and the one it reaches widens and shows its
      // label, so the change reads as a single movement.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: index.toDouble()),
        duration: OMotion.of(context, OMotion.slow),
        curve: OMotion.emphasized,
        builder: (context, t, _) => LayoutBuilder(
          builder: (context, box) {
            final n = tabs.length;
            final unit = box.maxWidth / (3 * n + 2);
            // How selected each tab is right now, 0–1; they sum to 1.
            final sel = [for (var i = 0; i < n; i++) (1 - (t - i).abs()).clamp(0.0, 1.0)];
            final widths = [for (final s in sel) unit * (3 + 2 * s)];
            final lefts = [0.0];
            for (var i = 0; i < n - 1; i++) {
              lefts.add(lefts[i] + widths[i]);
            }
            final lo = t.floor().clamp(0, n - 1), hi = t.ceil().clamp(0, n - 1);
            final f = t - lo;
            final pillLeft = lefts[lo] + (lefts[hi] - lefts[lo]) * f;
            final pillWidth = widths[lo] + (widths[hi] - widths[lo]) * f;
            return Stack(
              children: [
                Positioned(
                  left: pillLeft,
                  width: pillWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(color: c.ink, shape: const StadiumBorder()),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, tab) in tabs.indexed)
                      SizedBox(
                        width: widths[i],
                        child: Semantics(
                          selected: i == index,
                          label: tab.label,
                          child: OPressable(
                            onTap: () => onSelect(i),
                            pressedScale: 0.94,
                            semanticLabel: tab.label,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(tab.icon, size: 20, color: Color.lerp(c.inkSoft, c.onInk, sel[i])),
                                if (sel[i] > 0.01)
                                  Flexible(
                                    child: ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: sel[i],
                                        child: Opacity(
                                          opacity: sel[i],
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: OSpace.sm),
                                            child: Text(
                                              tab.label,
                                              maxLines: 1,
                                              softWrap: false,
                                              overflow: TextOverflow.fade,
                                              style: context.type.smallStrong.tint(c.onInk),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
