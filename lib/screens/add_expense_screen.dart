import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../model/category.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppScope.of(context).addManual(
      amountMinor: _amountMinor!,
      payee: _payee.text,
      category: _category,
      at: _date,
    );
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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final amount = _amountMinor;
    const noBorder = OutlineInputBorder(borderSide: BorderSide.none);
    final today = DateUtils.isSameDay(_date, DateTime.now());

    return Scaffold(
      body: CanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Add expense'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xl),
                  children: [
                    Text('Amount', textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: t.muted)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹',
                          style: text.displaySmall?.copyWith(
                            fontSize: 44,
                            color: _amount.text.isEmpty ? t.trayDeep : t.ink,
                          ),
                        ),
                        const SizedBox(width: Space.xs),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 32, maxWidth: 260),
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _amount,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: text.displaySmall?.copyWith(fontSize: 44),
                              decoration: InputDecoration(
                                filled: false,
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
                                hintText: '0',
                                hintStyle: text.displaySmall?.copyWith(fontSize: 44, color: t.trayDeep),
                                border: noBorder,
                                enabledBorder: noBorder,
                                focusedBorder: noBorder,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _payee,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Paid to (optional)'),
                    ),
                    const SizedBox(height: Space.md),
                    Center(
                      child: ActionChip(
                        avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(today ? 'Today' : DateFormat('EEE, d MMM').format(_date)),
                        backgroundColor: t.tray,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SectionHeader('Category', top: Space.xxl),
                    CategoryPills(
                      selected: _category,
                      onSelected: (c) => setState(() => _category = c),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: amount == null || _saving ? null : _save,
                    child: Text(amount == null ? 'Add' : 'Add ${formatMoney(amount, appCurrency)}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
