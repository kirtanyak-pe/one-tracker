import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';

/// A thin rotating arc.
class OSpinner extends StatefulWidget {
  const OSpinner({super.key, this.size = 20, this.color, this.stroke = 2});

  final double size;
  final Color? color;
  final double stroke;

  @override
  State<OSpinner> createState() => _OSpinnerState();
}

class _OSpinnerState extends State<OSpinner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: SizedBox.square(
      dimension: widget.size,
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(painter: _ArcPainter(widget.color ?? context.colors.ink, widget.stroke)),
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color, this.stroke);
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r.deflate(stroke / 2), 0, math.pi * 2, false, p..color = color.withValues(alpha: 0.15));
    canvas.drawArc(r.deflate(stroke / 2), 0, math.pi * 0.6, false, p..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color || old.stroke != stroke;
}

/// A rounded track. [value] null shows a sliding indeterminate bar.
class OProgressBar extends StatefulWidget {
  const OProgressBar({super.key, this.value, this.height = 6, this.color, this.track});

  final double? value;
  final double height;
  final Color? color;
  final Color? track;

  @override
  State<OProgressBar> createState() => _OProgressBarState();
}

class _OProgressBarState extends State<OProgressBar> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OProgressBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.value == null && _c == null) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    } else if (widget.value != null && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = widget.color ?? c.ink;
    final h = widget.height;
    return ClipRRect(
      borderRadius: BorderRadius.circular(h),
      child: SizedBox(
        height: h,
        child: ColoredBox(
          color: widget.track ?? c.raised,
          child: widget.value != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: widget.value!.clamp(0.0, 1.0)),
                    duration: OMotion.of(context, OMotion.slow),
                    curve: OMotion.standard,
                    builder: (_, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(h)),
                      ),
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: _c!,
                  builder: (_, _) => FractionalTranslation(
                    translation: Offset(-1 + _c!.value * 2.5, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(h)),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A small coloured capsule: a status, a count, a delta.
class OBadge extends StatelessWidget {
  const OBadge({super.key, required this.label, this.color, this.icon, this.solid = false});

  final String label;

  /// Tints the badge; defaults to neutral.
  final Color? color;
  final IconData? icon;

  /// Solid fill instead of a soft wash.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = color ?? c.inkSoft;
    final bg = solid ? tone : (color == null ? c.raised : c.soft(tone));
    final fg = solid ? const Color(0xFFFFFFFF) : tone;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 8 : 6, 3, 8, 3),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 3)],
          Text(label, style: context.type.caption.tint(fg).semibold.tabular),
        ],
      ),
    );
  }
}

/// Toasts: a dark capsule that rises from the bottom, replacing SnackBar.
/// Shown in the nearest root [Overlay].
abstract final class OToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final theme = OTheme.of(context);
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    final key = GlobalKey<_ToastState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => OTheme(
        data: theme,
        child: _Toast(
          key: key,
          message: message,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  hide();
                  onAction();
                },
          onGone: () {
            if (_entry == entry) _entry = null;
            entry.remove();
          },
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(actionLabel != null && duration.inSeconds < 5 ? const Duration(seconds: 5) : duration, () {
      key.currentState?.dismiss();
    });
  }

  static void hide() {
    _timer?.cancel();
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.message, required this.onGone, this.icon, this.actionLabel, this.onAction});

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onGone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: OMotion.base, reverseDuration: OMotion.fast)..forward();

  void dismiss() => _c.reverse().whenComplete(() {
    if (mounted) widget.onGone();
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always dark, in both themes: it floats over anything.
    const bg = Color(0xFF1C1C1F);
    const fg = Color(0xFFF4F4F5);
    final type = context.type;
    final pad = MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom;
    final a = CurvedAnimation(parent: _c, curve: OMotion.emphasized, reverseCurve: OMotion.exit);
    return Positioned(
      left: OSpace.lg,
      right: OSpace.lg,
      bottom: pad + 96,
      child: FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
          child: Center(
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 0) dismiss();
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, minHeight: 48),
                padding: EdgeInsets.fromLTRB(
                  OSpace.lg,
                  OSpace.sm,
                  widget.actionLabel == null ? OSpace.lg : 6,
                  OSpace.sm,
                ),
                decoration: ShapeDecoration(
                  color: bg,
                  shape: ORadius.smooth(ORadius.md),
                  shadows: OShadow.floating(Brightness.light),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: fg),
                      const SizedBox(width: OSpace.sm + 2),
                    ],
                    Flexible(child: Text(widget.message, style: type.smallStrong.tint(fg))),
                    if (widget.actionLabel != null) ...[
                      const SizedBox(width: OSpace.sm),
                      OPressable(
                        onTap: widget.onAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: ShapeDecoration(color: fg.withValues(alpha: 0.12), shape: const StadiumBorder()),
                          child: Text(widget.actionLabel!, style: type.smallStrong.tint(fg).semibold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
