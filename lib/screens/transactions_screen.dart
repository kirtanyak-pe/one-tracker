import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../model/category.dart';
import '../model/transaction.dart';
import '../money.dart';
import '../ui/format.dart';

import 'package:onyx/onyx.dart';

import 'widgets/txn_list.dart';

/// One slice of the selected month: a category, excluded, or income.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen.category(Category this.category, {super.key}) : _mode = _Mode.category;
  const TransactionsScreen.excluded({super.key}) : category = null, _mode = _Mode.excluded;
  const TransactionsScreen.income({super.key}) : category = null, _mode = _Mode.income;

  final Category? category;
  final _Mode _mode;

  bool _matches(Enriched e) => switch (_mode) {
    _Mode.category => e.countsAsSpend && e.category == category,
    _Mode.excluded => e.kind.excluded,
    _Mode.income => e.kind == TxnKind.income,
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final items = app.month.items.where(_matches).toList();
    final total = items.fold(0, (sum, e) => sum + e.txn.amountMinor);
    final title = switch (_mode) {
      _Mode.category => category!.label,
      _Mode.excluded => 'Excluded',
      _Mode.income => 'Income',
    };
    final note = switch (_mode) {
      _Mode.category => '${items.length} payment${items.length == 1 ? '' : 's'}',
      _Mode.excluded => 'Self transfers and things you marked — not counted as spending',
      _Mode.income => 'Money in, excluding transfers between your accounts',
    };

    return OScreen(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.lg, OSpace.gutter, OSpace.xxxl),
        children: [
          Text(formatMoney(total, appCurrency), textAlign: TextAlign.center, style: text.display.tabular),
          const SizedBox(height: OSpace.xs),
          Text(
            '${monthLabel(app.month.month)} · $note',
            textAlign: TextAlign.center,
            style: text.small.copyWith(color: t.inkSoft),
          ),
          const SizedBox(height: OSpace.lg),
          if (items.isEmpty)
            OInset(
              child: Text(
                'Nothing here this month.',
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: t.inkSoft),
              ),
            )
          else
            TxnDayList(items: items, currency: appCurrency),
        ],
      ),
    );
  }
}

enum _Mode { category, excluded, income }
