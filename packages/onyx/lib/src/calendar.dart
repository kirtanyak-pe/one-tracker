import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'button.dart';
import 'overlays.dart';
import 'pressable.dart';
import 'theme.dart';
import 'tokens.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Picks a day in a sheet. Weeks start on Monday.
Future<DateTime?> showODatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Pick a date',
}) => showOSheet<DateTime>(
  context,
  builder: (context) => _DatePicker(initial: initial, first: first, last: last, title: title),
);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class _DatePicker extends StatefulWidget {
  const _DatePicker({required this.initial, required this.first, required this.last, required this.title});

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<_DatePicker> {
  late DateTime _picked = _day(widget.initial);
  late DateTime _month = DateTime(_picked.year, _picked.month);

  bool get _canBack => _month.isAfter(DateTime(widget.first.year, widget.first.month));
  bool get _canForward => _month.isBefore(DateTime(widget.last.year, widget.last.month));

  void _shift(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final today = _day(DateTime.now());
    final first = _day(widget.first);
    final last = _day(widget.last);
    final lead = (_month.weekday + 6) % 7; // Monday = 0
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = [
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= days; d++) DateTime(_month.year, _month.month, d),
    ];

    return OSheetBody(
      title: widget.title,
      actions: [OButton(label: 'Done', expand: true, onPressed: () => Navigator.pop(context, _picked))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${_months[_month.month - 1]} ${_month.year}', style: t.title3)),
              OIconButton(
                icon: LucideIcons.chevronLeft,
                label: 'Previous month',
                onPressed: _canBack ? () => _shift(-1) : null,
              ),
              OIconButton(
                icon: LucideIcons.chevronRight,
                label: 'Next month',
                onPressed: _canForward ? () => _shift(1) : null,
              ),
            ],
          ),
          const SizedBox(height: OSpace.md),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(d, style: t.caption.tint(c.inkFaint))),
                ),
            ],
          ),
          const SizedBox(height: OSpace.sm),
          GestureDetector(
            onHorizontalDragEnd: (e) {
              final v = e.primaryVelocity ?? 0;
              if (v > 200 && _canBack) _shift(-1);
              if (v < -200 && _canForward) _shift(1);
            },
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final d in cells)
                  if (d == null)
                    const SizedBox.shrink()
                  else
                    _Day(
                      day: d,
                      selected: d == _picked,
                      today: d == today,
                      enabled: !d.isBefore(first) && !d.isAfter(last),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _picked = d);
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onInk : (enabled ? c.ink : c.inkFaint.withValues(alpha: 0.5));
    return OPressable(
      onTap: enabled ? onTap : null,
      haptic: false,
      pressedScale: 0.9,
      semanticLabel: '${day.day} ${_months[day.month - 1]}',
      child: Center(
        child: AnimatedContainer(
          duration: OMotion.fast,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? c.ink : null,
            shape: BoxShape.circle,
            border: today && !selected ? Border.all(color: c.lineStrong) : null,
          ),
          alignment: Alignment.center,
          child: Text('${day.day}', style: context.type.bodyStrong.tint(fg).tabular),
        ),
      ),
    );
  }
}
