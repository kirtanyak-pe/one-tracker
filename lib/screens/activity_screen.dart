import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../model/transaction.dart';
import '../money.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'shell.dart';
import 'widgets/txn_list.dart';

enum _Filter {
  all('All'),
  spent('Spent'),
  big('Big'),
  excluded('Excluded'),
  income('Income');

  const _Filter(this.label);

  final String label;
}

/// Every transaction, all months, searchable.
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  final _search = TextEditingController();
  var _filter = _Filter.all;

  /// Built lazily, so this is only a sanity cap.
  static const _cap = 2000;

  bool _matches(Enriched e, String q, int? bigAbove) {
    final ok = switch (_filter) {
      _Filter.all => true,
      _Filter.spent => e.countsAsSpend,
      _Filter.big => e.countsAsSpend && e.txn.amountMinor > (bigAbove ?? 500000),
      _Filter.excluded => e.kind.excluded,
      _Filter.income => e.kind == TxnKind.income,
    };
    if (!ok) return false;
    if (q.isEmpty) return true;
    final amount = (e.txn.amountMinor / 100).toStringAsFixed(0);
    return e.payee.toLowerCase().contains(q) ||
        e.category.label.toLowerCase().contains(q) ||
        e.tags.any((tag) => tag.toLowerCase().contains(q)) ||
        amount.contains(q) ||
        (e.txn.raw?.toLowerCase().contains(q) ?? false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final q = _search.text.trim().toLowerCase().replaceAll('#', '');
    final results = app.ledger.items.where((e) => _matches(e, q, app.profile.reviewAboveMinor)).toList();
    final shown = results.take(_cap).toList();
    final total = results.fold(0, (sum, e) => sum + e.txn.amountMinor);
    final days = groupByDay(shown);

    return CanvasBackground(
      child: SafeArea(
        bottom: false,
        // Header widgets, then day cards built lazily as you scroll (a year
        // of payments would otherwise build hundreds of rows up front).
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
              sliver: SliverList.list(
                children: [
                  Text('Activity', style: text.headlineMedium),
                  const SizedBox(height: Space.lg),
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search payee, #tag or amount',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Space.md),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: _Filter.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (_, i) {
                        final f = _Filter.values[i];
                        final on = f == _filter;
                        return Semantics(
                          selected: on,
                          button: true,
                          child: Material(
                            color: on ? t.ink : t.tray,
                            shape: const StadiumBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => setState(() => _filter = f),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                                child: Center(
                                  child: Text(
                                    f == _Filter.big && app.profile.reviewAboveMinor != null
                                        ? 'Over ${formatCompact(app.profile.reviewAboveMinor!)}'
                                        : f.label,
                                    style: text.labelLarge?.copyWith(color: on ? t.onInk : t.ink),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    results.isEmpty
                        ? 'Nothing matches'
                        : [
                            '${results.length} transaction${results.length == 1 ? '' : 's'}',
                            // A total across spending, income and transfers means nothing.
                            if (_filter != _Filter.all) formatMoney(total, appCurrency, round: true),
                            if (results.length > _cap) 'showing latest $_cap',
                          ].join(' · '),
                    style: text.bodySmall?.copyWith(color: t.muted),
                  ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.lg),
                      child: Tray(
                        child: Text(
                          q.isEmpty ? 'No transactions here yet.' : 'Try a payee name, #tag or an amount like 450.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: t.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, navClearance),
              sliver: SliverList.builder(
                itemCount: days.length,
                itemBuilder: (context, i) =>
                    TxnDayCard(label: days[i].label, items: days[i].items, currency: appCurrency, index: i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
