import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../model/category.dart';
import '../money.dart';

import 'package:onyx/onyx.dart';

import 'widgets/category_pills.dart';

/// For cash and anything that didn't come with an SMS.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amount = TextEditingController();
  final _payee = TextEditingController();
  Category _category = Category.food;
  DateTime _date = DateTime.now();
  bool _saving = false;

  int? get _amountMinor => parseMinor(_amount.text);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showODatePicker(
      context,
      initial: _date,
      first: now.subtract(const Duration(days: 365)),
      last: now,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppScope.of(context)
        .addManual(amountMinor: _amountMinor!, payee: _payee.text, category: _category, at: _date);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    final amount = _amountMinor;
    final nowDate = DateTime.now();
    final today = _date.year == nowDate.year && _date.month == nowDate.month && _date.day == nowDate.day;

    return OScreen(
      title: 'Add expense',
      bottom: OButton(
        label: amount == null ? 'Add' : 'Add ${formatMoney(amount, appCurrency)}',
        expand: true,
        onPressed: amount == null || _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.lg, OSpace.gutter, OSpace.xl),
        children: [
          Text(
            'Amount',
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹',
                style: text.display.tabular.copyWith(fontSize: 44, color: _amount.text.isEmpty ? t.lineStrong : t.ink),
              ),
              const SizedBox(width: OSpace.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 32, maxWidth: 260),
                child: IntrinsicWidth(
                  child: OField(
                    bare: true,
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: text.display.tabular.copyWith(fontSize: 44),
                    placeholder: '0',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OSpace.md),
          OField(
            controller: _payee,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            placeholder: 'Paid to (optional)',
          ),
          const SizedBox(height: OSpace.md),
          Center(
            child: OChip(
              icon: LucideIcons.calendar,
              label: today ? 'Today' : DateFormat('EEE, d MMM').format(_date),
              onTap: _pickDate,
            ),
          ),
          const OSectionHeader('Category', top: OSpace.xxl),
          CategoryPills(selected: _category, onSelected: (c) => setState(() => _category = c)),
        ],
      ),
    );
  }
}
