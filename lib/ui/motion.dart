import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../money.dart';

/// Shared timing so every animation in the app feels like one system.
/// All of them collapse to instant when the OS asks to remove animations.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 650);

  static const enter = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutQuart;

  /// Gap between items in a staggered entrance.
  static const stagger = Duration(milliseconds: 45);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Fades and lifts its child in once, the first time it's built. [index]
/// staggers siblings (capped so long lists don't wait forever).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.offset = 16});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: Motion.medium);
  late final _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    final delay = Motion.stagger * widget.index.clamp(0, 8);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - _curve.value)),
            child: child,
          ),
        ),
      );
}

/// Counts from the previous amount to the new one.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(
    this.minor, {
    super.key,
    this.style,
    this.round = false,
    this.compact = false,
    this.textAlign,
  });

  final int minor;
  final TextStyle? style;
  final bool round;
  final bool compact;
  final TextAlign? textAlign;

  String _format(int v) => compact ? formatCompact(v) : formatMoney(v, appCurrency, round: round);

  @override
  Widget build(BuildContext context) => Semantics(
        // Screen readers get the final value, not every frame.
        label: _format(minor),
        excludeSemantics: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: minor.toDouble()),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.emphasized,
          builder: (context, value, _) => Text(
            _format(value.round()),
            style: style?.tabular,
            textAlign: textAlign,
          ),
        ),
      );
}

/// A thin rounded progress bar that fills smoothly to [value].
class AnimatedMeter extends StatelessWidget {
  const AnimatedMeter({
    super.key,
    required this.value,
    required this.color,
    required this.background,
    this.height = 4,
  });

  final double value;
  final Color color;
  final Color background;
  final double height;

  @override
  Widget build(BuildContext context) => OProgressBar(value: value, height: height, color: color, track: background);
}

/// Wraps each child in a [FadeSlideIn] with increasing delay.
List<Widget> staggered(List<Widget> children) => [
      for (final (i, child) in children.indexed) FadeSlideIn(index: i, child: child),
    ];
