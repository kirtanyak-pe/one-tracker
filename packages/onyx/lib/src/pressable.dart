import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The one tap primitive: scales to [pressedScale] while held, gives a light
/// haptic on tap and reports itself as a button. No ripples.
class OPressable extends StatefulWidget {
  const OPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.pressedOpacity = 1,
    this.haptic = true,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  /// Below 1 also fades while held (used by text-only buttons).
  final double pressedOpacity;
  final bool haptic;
  final String? semanticLabel;
  final HitTestBehavior behavior;

  @override
  State<OPressable> createState() => _OPressableState();
}

class _OPressableState extends State<OPressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final d = OMotion.of(context, OMotion.fast);
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapUp: _enabled ? (_) => _set(false) : null,
        onTapCancel: _enabled ? () => _set(false) : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _set(false);
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: d,
          curve: OMotion.standard,
          child: AnimatedOpacity(opacity: _down ? widget.pressedOpacity : 1, duration: d, child: widget.child),
        ),
      ),
    );
  }
}
