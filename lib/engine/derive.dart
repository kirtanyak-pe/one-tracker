import '../model/automation.dart';
import '../model/transaction.dart';
import 'enrich.dart';
import 'insights.dart';
import 'recurring.dart';
import 'summary.dart';

/// Everything the screens show, derived from stored facts. A pure function
/// so it can run on a background isolate (see AppController._recompute).
class DeriveInput {
  const DeriveInput({
    required this.txns,
    required this.profile,
    required this.rules,
    required this.autoRules,
    required this.month,
    required this.now,
  });

  final List<Txn> txns;
  final Profile profile;
  final Map<String, PayeeRule> rules;
  final List<AutoRule> autoRules;
  final DateTime month;
  final DateTime now;
}

class Derived {
  const Derived({required this.ledger, required this.month, required this.insights, required this.recurring});

  final Ledger ledger;
  final MonthSummary month;
  final Insights insights;
  final List<Recurring> recurring;
}

Derived derive(DeriveInput i) {
  final ledger = enrich(i.txns, profile: i.profile, rules: i.rules, autoRules: i.autoRules);
  return Derived(
    ledger: ledger,
    month: summarize(ledger, i.month),
    insights: buildInsights(ledger, i.month, now: i.now),
    recurring: findRecurring(ledger, now: i.now),
  );
}
