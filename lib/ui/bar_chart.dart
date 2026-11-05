import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../money.dart';
import 'motion.dart';
import 'package:onyx/onyx.dart';

/// Single-series column chart (see dataviz rules): ink bars ≤ 24px with 4px
/// rounded tops, square at a hairline baseline; one highlighted bar in the
/// accent; optional solid hairline average. Tap a bar to read its value.
class BarChart extends StatefulWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labelFor,
    required this.semanticLabel,
    this.highlight,
    this.average,
    this.axisLabels = const {},
    this.height = 160,
  });

  final List<int> values;

  /// Tooltip text for a bar, e.g. "6 Oct · ₹1,240".
  final String Function(int index) labelFor;
  final String semanticLabel;

  /// Index drawn in the accent (today / this month).
  final int? highlight;
  final int? average;

  /// Sparse x-axis labels by index.
  final Map<int, String> axisLabels;
  final double height;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> with SingleTickerProviderStateMixin {
  int? _selected;

  // Bars grow up from the baseline on first show and when the data changes.
  late final _grow = AnimationController(vsync: this, duration: Motion.slow);
  late final _growCurve = CurvedAnimation(parent: _grow, curve: Motion.emphasized);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _grow.value = 1;
    } else if (!_grow.isAnimating && _grow.value == 0) {
      _grow.forward();
    }
  }

  @override
  void didUpdateWidget(BarChart old) {
    super.didUpdateWidget(old);
    final changed =
        old.values.length != widget.values.length ||
        Iterable.generate(widget.values.length).any((i) => old.values[i] != widget.values[i]);
    if (changed) {
      _selected = null;
      if (!Motion.reduced(context)) _grow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  int _indexAt(double dx, double width) =>
      (dx / width * widget.values.length).floor().clamp(0, widget.values.length - 1);

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    final selected = _selected ?? widget.highlight;
    final maxValue = math.max(widget.values.fold(0, math.max), widget.average ?? 0);

    return Semantics(
      label: widget.semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 20,
            child: selected == null
                ? null
                : Text(widget.labelFor(selected), style: text.small.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: OSpace.sm),
          LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => setState(() => _selected = _indexAt(d.localPosition.dx, box.maxWidth)),
              onHorizontalDragUpdate: (d) => setState(() => _selected = _indexAt(d.localPosition.dx, box.maxWidth)),
              child: SizedBox(
                height: widget.height,
                width: box.maxWidth,
                // Own layer: the growing bars don't repaint the whole page.
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BarsPainter(
                      progress: _growCurve,
                      values: widget.values,
                      max: maxValue == 0 ? 1 : maxValue,
                      selected: selected,
                      average: widget.average,
                      bar: t.ink,
                      accent: t.accent,
                      faint: t.lineStrong,
                      axis: t.raised,
                      muted: t.inkSoft,
                      averageLabel: widget.average == null ? null : 'avg ${formatCompact(widget.average!)}',
                      labelStyle: text.small.copyWith(fontSize: 11, color: t.inkSoft),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.axisLabels.isNotEmpty) ...[
            const SizedBox(height: OSpace.sm),
            LayoutBuilder(
              builder: (context, box) {
                final slot = box.maxWidth / widget.values.length;
                return SizedBox(
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final MapEntry(:key, :value) in widget.axisLabels.entries)
                        Positioned(
                          left: (slot * key + slot / 2 - 24).clamp(0, box.maxWidth - 48),
                          width: 48,
                          child: Text(
                            value,
                            textAlign: TextAlign.center,
                            style: text.small.copyWith(fontSize: 11, color: t.inkSoft),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.progress,
    required this.values,
    required this.max,
    required this.selected,
    required this.average,
    required this.bar,
    required this.accent,
    required this.faint,
    required this.axis,
    required this.muted,
    required this.averageLabel,
    required this.labelStyle,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<int> values;
  final int max;
  final int? selected;
  final int? average;
  final Color bar, accent, faint, axis, muted;
  final String? averageLabel;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / values.length;
    // ≤ 24px, and always a 2px+ gap between neighbours.
    final width = math.min(24.0, math.max(2.0, slot - 2));
    final baseline = size.height - 1;
    final usable = size.height - 8;

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final left = slot * i + (slot - width) / 2;
      if (v == 0) continue;
      final h = math.max(3.0, v / max * usable) * progress.value;
      if (h < 0.5) continue;
      final radius = Radius.circular(math.min(4, width / 2));
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, baseline - h, width, h),
        topLeft: radius,
        topRight: radius,
      );
      final isSelected = i == selected;
      canvas.drawRRect(
        rect,
        Paint()..color = isSelected ? accent : (selected == null ? bar : bar.withValues(alpha: 0.75)),
      );
    }

    // Hairline baseline.
    canvas.drawLine(
      Offset(0, baseline + 0.5),
      Offset(size.width, baseline + 0.5),
      Paint()
        ..color = faint
        ..strokeWidth = 1,
    );

    if (average != null && average! > 0) {
      final y = baseline - average! / max * usable;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = muted.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(text: averageLabel, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelY = (y - tp.height - 2).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(size.width - tp.width, labelY));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values || old.selected != selected || old.average != average || old.bar != bar;
}
