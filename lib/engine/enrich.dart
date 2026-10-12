import '../model/automation.dart';
import '../model/category.dart';
import '../model/transaction.dart';
import 'classify.dart';
import 'parser.dart';

/// A transaction with everything the app shows about it worked out.
class Enriched {
  const Enriched({
    required this.txn,
    required this.payee,
    required this.category,
    required this.kind,
    required this.counterpartyKind,
    required this.tags,
    required this.needsReview,
    this.reason,
  });

  final Txn txn;

  /// Merchant or receiver/sender name for display and tagging.
  final String payee;
  final Category category;
  final TxnKind kind;

  /// Why [kind] was set automatically (null if it's the plain default or
  /// the user chose it).
  final String? reason;
  final CounterpartyKind counterpartyKind;
  final List<String> tags;

  /// A big payment the user hasn't confirmed yet.
  final bool needsReview;

  bool get countsAsSpend => kind == TxnKind.expense && txn.direction == Direction.debit;
}

class Ledger {
  const Ledger({required this.items, required this.ownAccounts});

  /// Newest first.
  final List<Enriched> items;

  /// Your accounts/cards, learned from the bank SMS you receive.
  final Set<String> ownAccounts;

  static const empty = Ledger(items: [], ownAccounts: {});
}

final _ccBill = RegExp(
  r'credit ?card (?:bill|payment)|card bill|cc (?:bill|payment)|payment (?:received )?(?:towards|on|for) your (?:\w+ )?credit card|'
  r'received (?:a )?payment of .* (?:on|towards) your .*card',
  caseSensitive: false,
);
// CRED is used to pay card bills ("ICICI Bank Cred", "cred.club@axisb").
final _ccPayee = RegExp(r'\bcred\b|cred\.club|credit ?card|cc ?bill', caseSensitive: false);
final _selfWords = RegExp(
  r'\b(self[ -]?transfer|to self|own account|between your accounts|to your own)\b',
  caseSensitive: false,
);
final _atm = RegExp(r'\batm\b|cash withdrawal', caseSensitive: false);

/// Derives category, kind and tags for every transaction from the stored
/// facts, the user's rules and profile. Pure — call it after any change.
///
/// Precedence: this payment's override > payee rule > keyword rule > detectors.
Ledger enrich(
  List<Txn> txns, {
  Profile profile = const Profile(),
  Map<String, PayeeRule> rules = const {},
  List<AutoRule> autoRules = const [],
}) {
  final own = {
    for (final t in txns)
      if ((t.source == Source.sms || t.source == Source.sample) && t.account != null) t.account!,
  }.difference(profile.ignoredAccounts);

  final pairs = _selfTransferPairs(txns, own, profile.name);

  final items = <Enriched>[];
  for (final t in txns) {
    final raw = t.raw ?? '';
    final rule = rules[payeeKey(t)];
    final haystack = '${t.counterparty ?? ''} ${t.vpa ?? ''} $raw';
    final auto = autoRules.where((r) => r.matches(haystack)).toList();
    final autoCategoryRule = auto.where((r) => r.category != null).firstOrNull;
    final autoKindRule = auto.where((r) => r.kind != null).firstOrNull;
    final kindOfPayee = counterpartyKind(t);
    final atm = _atm.hasMatch(raw);

    final category = t.categoryOverride ??
        rule?.category ??
        autoCategoryRule?.category ??
        autoCategory(t, atm: atm);

    TxnKind kind;
    String? reason;
    if (t.kindOverride != null) {
      kind = t.kindOverride!;
    } else if (rule?.kind != null) {
      kind = rule!.kind!;
      reason = 'You set this for all ${rule.label} payments';
    } else if (autoKindRule != null) {
      kind = autoKindRule.kind!;
      reason = 'Your rule for "${autoKindRule.contains}"';
    } else if ((reason = _selfReason(t, raw, own, profile.name, pairs)) != null) {
      kind = TxnKind.selfTransfer;
    } else if (_ccBill.hasMatch(raw) || _ccPayee.hasMatch('${t.counterparty ?? ''} ${t.vpa ?? ''}')) {
      kind = TxnKind.notExpense;
      reason = 'Credit card bill — the card spends are counted already';
    } else {
      kind = t.direction == Direction.credit ? TxnKind.income : TxnKind.expense;
    }

    final payee = t.counterparty ??
        (t.vpa != null ? nameFromVpa(t.vpa!) : null) ??
        (t.otherAccount != null
            ? '${t.direction == Direction.debit ? 'To' : 'From'} A/c ••${t.otherAccount}'
            : null) ??
        (atm ? 'ATM' : t.direction == Direction.credit ? 'Money received' : 'Payment');

    items.add(Enriched(
      txn: t,
      payee: payee,
      category: kind == TxnKind.income && t.categoryOverride == null ? Category.income : category,
      kind: kind,
      reason: reason,
      counterpartyKind: kindOfPayee,
      tags: {
        payee,
        ...t.userTags,
        for (final r in auto)
          if (r.tag != null && r.tag!.isNotEmpty) r.tag!,
      }.toList(),
      // Every payment counts as an expense by default; only big ones get
      // a check, and only until the user has touched them or the payee.
      needsReview: profile.reviewAboveMinor != null &&
          t.amountMinor > profile.reviewAboveMinor! &&
          t.direction == Direction.debit &&
          kind == TxnKind.expense &&
          !t.reviewed &&
          t.kindOverride == null &&
          t.categoryOverride == null &&
          rule == null &&
          auto.isEmpty,
    ));
  }

  items.sort((a, b) => b.txn.at.compareTo(a.txn.at));
  return Ledger(items: items, ownAccounts: own);
}

String? _selfReason(
  Txn t,
  String raw,
  Set<String> own,
  String profileName,
  Map<String, String> pairs,
) {
  if (_selfWords.hasMatch(raw)) return 'Your bank marked it as a self transfer';
  if (t.otherAccount != null && own.contains(t.otherAccount) && t.otherAccount != t.account) {
    return t.direction == Direction.debit
        ? 'Sent to your account ••${t.otherAccount}'
        : 'From your account ••${t.otherAccount}';
  }
  if (nameMatches(profileName, t.counterparty)) {
    return t.direction == Direction.debit ? 'Sent to your own name' : 'Received from your own name';
  }
  return pairs[t.id];
}

/// Debit on one of your accounts + same-amount credit on another of your
/// accounts within 30 minutes = money moved between your own accounts.
Map<String, String> _selfTransferPairs(List<Txn> txns, Set<String> own, String profileName) {
  final sorted = [...txns]..sort((a, b) => a.at.compareTo(b.at));
  final used = <String>{};
  final result = <String, String>{};

  // Credits grouped by amount: each debit only looks at same-amount ones.
  final credits = <int, List<Txn>>{};
  for (final t in sorted) {
    if (t.direction == Direction.credit && t.kindOverride == null) {
      credits.putIfAbsent(t.amountMinor, () => []).add(t);
    }
  }

  for (final debit in sorted.where((t) => t.direction == Direction.debit)) {
    if (debit.kindOverride != null) continue;
    Txn? best;
    for (final credit in credits[debit.amountMinor] ?? const <Txn>[]) {
      if (used.contains(credit.id)) continue;
      final gap = credit.at.difference(debit.at).abs();
      if (gap > const Duration(minutes: 30)) continue;
      final ownToOwn = debit.account != null &&
          credit.account != null &&
          debit.account != credit.account &&
          own.contains(debit.account) &&
          own.contains(credit.account);
      final namedSelf = nameMatches(profileName, debit.counterparty) ||
          nameMatches(profileName, credit.counterparty);
      if (!ownToOwn && !namedSelf) continue;
      if (best == null || gap < credit.at.difference(best.at).abs()) best = credit;
    }
    if (best != null) {
      used.add(best.id);
      result[debit.id] = 'Matches a credit to your account ••${best.account ?? '?'}';
      result[best.id] = 'Matches a debit from your account ••${debit.account ?? '?'}';
    }
  }
  return result;
}

/// "Kirtanya K" vs "KIRTANYA KUMAR" → true. First name must match; if both
/// have a last part, initials must agree.
bool nameMatches(String profileName, String? other) {
  if (other == null) return false;
  List<String> tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !const {'mr', 'ms', 'mrs', 'dr'}.contains(w))
      .toList();
  final me = tokens(profileName);
  final them = tokens(other);
  if (me.isEmpty || them.isEmpty || me.first.length < 3) return false;
  if (me.first != them.first) return false;
  if (me.length > 1 && them.length > 1) return me.last[0] == them.last[0];
  return true;
}
