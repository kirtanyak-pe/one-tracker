import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_controller.dart';
import '../engine/enrich.dart';
import '../model/transaction.dart';
import '../money.dart';
import '../ui/format.dart';

import 'package:onyx/onyx.dart';

import 'home_screen.dart' show push;
import 'shell.dart';
import 'transactions_screen.dart';
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

  static final _searchRequests = ValueNotifier<int>(0);

  /// Puts the cursor in the search box (Home's Search shortcut).
  static void focusSearch() => _searchRequests.value++;

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  var _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    ActivityTab._searchRequests.addListener(_focus);
    // Opened via Search before this tab was ever built.
    if (ActivityTab._searchRequests.value > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _focus());
  }

  void _focus() {
    if (mounted) _searchFocus.requestFocus();
  }

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
        e.originalPayee.toLowerCase().contains(q) ||
        e.category.label.toLowerCase().contains(q) ||
        e.tags.any((tag) => tag.toLowerCase().contains(q)) ||
        amount.contains(q) ||
        (e.txn.raw?.toLowerCase().contains(q) ?? false);
  }

  @override
  void dispose() {
    ActivityTab._searchRequests.removeListener(_focus);
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;
    final q = _search.text.trim().toLowerCase().replaceAll('#', '');
    final results = app.ledger.items.where((e) => _matches(e, q, app.profile.reviewAboveMinor)).toList();
    final shown = results.take(_cap).toList();
    final total = results.fold(0, (sum, e) => sum + e.txn.amountMinor);
    final days = groupByDay(shown);

    return OTabPage(
      title: 'Activity',
      // Header widgets, then day cards built lazily as you scroll (a year
      // of payments would otherwise build hundreds of rows up front).
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.md, OSpace.gutter, 0),
            sliver: SliverList.list(
              children: [
                if (app.month.incomeMinor > 0 || app.month.excludedMinor > 0) ...[
                  _MonthStats(app: app),
                  const SizedBox(height: OSpace.lg),
                ],
                OField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  placeholder: 'Search payee, #tag or amount',
                  prefixIcon: LucideIcons.search,
                  suffix: _search.text.isEmpty
                      ? null
                      : OIconButton(
                          label: 'Clear',
                          icon: LucideIcons.x,
                          size: 32,
                          iconSize: 18,
                          onPressed: () => setState(_search.clear),
                        ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: OSpace.md),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: _Filter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: OSpace.sm),
                    itemBuilder: (_, i) {
                      final f = _Filter.values[i];
                      final on = f == _filter;
                      return Center(
                        child: OChip(
                          selected: on,
                          label: f == _Filter.big && app.profile.reviewAboveMinor != null
                              ? 'Over ${formatCompact(app.profile.reviewAboveMinor!)}'
                              : f.label,
                          onTap: () => setState(() => _filter = f),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: OSpace.md),
                Text(
                  results.isEmpty
                      ? 'Nothing matches'
                      : [
                          '${results.length} transaction${results.length == 1 ? '' : 's'}',
                          // A total across spending, income and transfers means nothing.
                          if (_filter != _Filter.all) formatMoney(total, appCurrency, round: true),
                          if (results.length > _cap) 'showing latest $_cap',
                        ].join(' · '),
                  style: text.small.copyWith(color: t.inkSoft),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: OSpace.lg),
                    child: OInset(
                      padding: const EdgeInsets.all(OSpace.xl),
                      radius: ORadius.lg,
                      child: Text(
                        q.isEmpty ? 'No transactions here yet.' : 'Try a payee name, #tag or an amount like 450.',
                        textAlign: TextAlign.center,
                        style: text.body.copyWith(color: t.inkSoft),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(OSpace.gutter, 0, OSpace.gutter, navClearance),
            sliver: SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, i) =>
                  TxnDayCard(label: days[i].label, items: days[i].items, currency: appCurrency, index: i),
            ),
          ),
        ],
      ),
    );
  }
}

/// Income and money that isn't spending (transfers, card bills) in the month
/// open on Home, kept here so Home shows only what was spent.
class _MonthStats extends StatelessWidget {
  const _MonthStats({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final m = app.month;
    final month = monthName(m.month);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              label: 'Income · $month',
              value: m.incomeMinor,
              onTap: () => push(context, const TransactionsScreen.income()),
            ),
          ),
          const SizedBox(width: OSpace.md),
          Expanded(
            child: _Stat(
              label: 'Not counted · $month',
              value: m.excludedMinor,
              onTap: () => push(context, const TransactionsScreen.excluded()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap});

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    return OCard(
      onTap: value == 0 ? null : onTap,
      padding: const EdgeInsets.fromLTRB(OSpace.lg, OSpace.md, OSpace.sm, OSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(color: t.inkSoft),
                ),
                const SizedBox(height: 2),
                Text(formatMoney(value, appCurrency, round: true), maxLines: 1, style: text.title3),
              ],
            ),
          ),
          if (value > 0) Icon(LucideIcons.chevronRight, size: 20, color: t.inkSoft),
        ],
      ),
    );
  }
}
