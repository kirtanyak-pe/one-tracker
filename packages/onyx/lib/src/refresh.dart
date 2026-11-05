import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'feedback.dart';
import 'tokens.dart';

/// Pull-to-refresh for a bouncing scroll view: pull past [threshold] and let
/// go to run [onRefresh]; a spinner shows in the overscroll gap.
class ORefresh extends StatefulWidget {
  const ORefresh({super.key, required this.onRefresh, required this.child, this.threshold = 80});

  final Future<void> Function() onRefresh;
  final Widget child;
  final double threshold;

  @override
  State<ORefresh> createState() => _ORefreshState();
}

class _ORefreshState extends State<ORefresh> {
  double _pull = 0;
  bool _armed = false;
  bool _busy = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final pull = (n.metrics.minScrollExtent - n.metrics.pixels).clamp(0.0, double.infinity);
    final dragging = switch (n) {
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (dragging && !_busy) {
      final armed = pull >= widget.threshold;
      if (armed && !_armed) HapticFeedback.mediumImpact();
      _armed = armed;
    }
    if (!dragging && _armed && !_busy) {
      _armed = false;
      _run();
    }
    if (pull != _pull) setState(() => _pull = pull);
    return false;
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_pull / widget.threshold).clamp(0.0, 1.0);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _busy ? 1 : progress,
              duration: _busy ? OMotion.fast : Duration.zero,
              child: SizedBox(
                height: _busy ? 48 : (_pull).clamp(0.0, 64.0),
                child: Center(
                  child: Transform.rotate(angle: _busy ? 0 : progress * 3.14, child: const OSpinner(size: 20)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
