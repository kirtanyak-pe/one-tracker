import 'category.dart';

enum Direction { debit, credit }

enum Source { sms, notification, manual, sample }

enum CounterpartyKind { merchant, person, unknown }

/// How a transaction counts. Only [expense] adds to spending.
enum TxnKind {
  expense('Expense'),
  income('Income'),
  selfTransfer('Self transfer'),
  notExpense('Not an expense');

  const TxnKind(this.label);

  final String label;

  bool get excluded => this == selfTransfer || this == notExpense;

  static TxnKind? byName(String? name) =>
      TxnKind.values.where((k) => k.name == name).firstOrNull;
}

/// What was read from a message, plus anything the user changed.
/// Category, kind and tags shown in the app are derived — see `enrich`.
class Txn {
  const Txn({
    required this.id,
    required this.source,
    required this.direction,
    required this.amountMinor,
    required this.at,
    this.sourceId,
    this.counterparty,
    this.vpa,
    this.account,
    this.otherAccount,
    this.ref,
    this.kindHint,
    this.raw,
    this.sender,
    this.categoryOverride,
    this.kindOverride,
    this.userTags = const [],
    this.reviewed = false,
    this.countMonth,
  });

  final String id;
  final Source source;

  /// SMS id / notification key, used to skip re-imports.
  final String? sourceId;
  final Direction direction;
  final int amountMinor;
  final DateTime at;

  /// Merchant or person as written in the message.
  final String? counterparty;
  final String? vpa;

  /// Last digits of *your* account/card the message is about.
  final String? account;

  /// Another account mentioned (e.g. "credited to a/c XX5678").
  final String? otherAccount;
  final String? ref;

  /// P2M / P2A style hint from the message.
  final CounterpartyKind? kindHint;
  final String? raw;

  /// SMS sender id or notifying app package.
  final String? sender;

  final Category? categoryOverride;
  final TxnKind? kindOverride;
  final List<String> userTags;

  /// The user confirmed or corrected this one.
  final bool reviewed;

  /// First day of the month this payment counts in, when the user moved it
  /// (only ever the month after [at]'s). Null = the month it was paid.
  final DateTime? countMonth;

  /// First day of the month after the one it was paid in.
  DateTime get nextMonth => DateTime(at.year, at.month + 1);

  Txn copyWith({
    String? counterparty,
    String? vpa,
    String? account,
    String? otherAccount,
    String? ref,
    CounterpartyKind? kindHint,
    Category? categoryOverride,
    bool clearCategoryOverride = false,
    TxnKind? kindOverride,
    bool clearKindOverride = false,
    List<String>? userTags,
    bool? reviewed,
    DateTime? countMonth,
    bool clearCountMonth = false,
  }) =>
      Txn(
        id: id,
        source: source,
        sourceId: sourceId,
        direction: direction,
        amountMinor: amountMinor,
        at: at,
        counterparty: counterparty ?? this.counterparty,
        vpa: vpa ?? this.vpa,
        account: account ?? this.account,
        otherAccount: otherAccount ?? this.otherAccount,
        ref: ref ?? this.ref,
        kindHint: kindHint ?? this.kindHint,
        raw: raw,
        sender: sender,
        categoryOverride:
            clearCategoryOverride ? null : categoryOverride ?? this.categoryOverride,
        kindOverride: clearKindOverride ? null : kindOverride ?? this.kindOverride,
        userTags: userTags ?? this.userTags,
        reviewed: reviewed ?? this.reviewed,
        countMonth: clearCountMonth ? null : countMonth ?? this.countMonth,
      );

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        source: Source.values.byName(j['source'] as String),
        sourceId: j['sourceId'] as String?,
        direction: Direction.values.byName(j['direction'] as String),
        amountMinor: j['amountMinor'] as int,
        at: DateTime.parse(j['at'] as String),
        counterparty: j['counterparty'] as String?,
        vpa: j['vpa'] as String?,
        account: j['account'] as String?,
        otherAccount: j['otherAccount'] as String?,
        ref: j['ref'] as String?,
        kindHint: j['kindHint'] == null
            ? null
            : CounterpartyKind.values.byName(j['kindHint'] as String),
        raw: j['raw'] as String?,
        sender: j['sender'] as String?,
        categoryOverride: Category.byName(j['categoryOverride'] as String?),
        kindOverride: TxnKind.byName(j['kindOverride'] as String?),
        userTags: ((j['userTags'] as List?) ?? const []).cast<String>(),
        reviewed: (j['reviewed'] as bool?) ?? false,
        countMonth: j['countMonth'] == null ? null : DateTime.parse(j['countMonth'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source.name,
        'sourceId': sourceId,
        'direction': direction.name,
        'amountMinor': amountMinor,
        'at': at.toIso8601String(),
        'counterparty': counterparty,
        'vpa': vpa,
        'account': account,
        'otherAccount': otherAccount,
        'ref': ref,
        'kindHint': kindHint?.name,
        'raw': raw,
        'sender': sender,
        'categoryOverride': categoryOverride?.name,
        'kindOverride': kindOverride?.name,
        'userTags': userTags,
        'reviewed': reviewed,
        'countMonth': countMonth?.toIso8601String(),
      };
}

/// "Always treat payments to X like this." Can also rename X ([name]) and tag
/// every payment to it ([tags]).
class PayeeRule {
  const PayeeRule({
    required this.key,
    required this.label,
    this.category,
    this.kind,
    this.name,
    this.tags = const [],
  });

  /// Normalised payee key — see `payeeKey`.
  final String key;

  /// The payee as the bank wrote it (for lists and reasons).
  final String label;
  final Category? category;
  final TxnKind? kind;

  /// What the user calls this payee ("Maid", "Blinkit"). Shown instead of the
  /// bank name everywhere, including in Splitwise. Null = the bank's name.
  final String? name;

  /// Tags on every payment to this payee.
  final List<String> tags;

  /// Category or type is set (the "Same for all" switch).
  bool get hasClassification => category != null || kind != null;

  /// Nothing left to remember — the rule can be dropped.
  bool get isEmpty => !hasClassification && name == null && tags.isEmpty;

  PayeeRule copyWith({
    Category? category,
    bool clearCategory = false,
    TxnKind? kind,
    bool clearKind = false,
    String? name,
    bool clearName = false,
    List<String>? tags,
  }) =>
      PayeeRule(
        key: key,
        label: label,
        category: clearCategory ? null : category ?? this.category,
        kind: clearKind ? null : kind ?? this.kind,
        name: clearName ? null : name ?? this.name,
        tags: tags ?? this.tags,
      );

  factory PayeeRule.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim();
    return PayeeRule(
      key: j['key'] as String,
      label: j['label'] as String,
      category: Category.byName(j['category'] as String?),
      kind: TxnKind.byName(j['kind'] as String?),
      name: name == null || name.isEmpty ? null : name,
      tags: ((j['tags'] as List?) ?? const []).cast<String>().toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'category': category?.name,
        'kind': kind?.name,
        if (name != null) 'name': name,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

/// Things the detectors need to know about you.
class Profile {
  const Profile({
    this.name = '',
    this.ignoredAccounts = const {},
    this.reviewAboveMinor = defaultReviewAbove,
  });

  /// ₹5,000 — payments above this get a "was this an expense?" check.
  static const defaultReviewAbove = 500000;

  /// Your name as banks print it — payments to it are self transfers.
  final String name;

  /// Learned accounts the user said aren't theirs.
  final Set<String> ignoredAccounts;

  /// Expenses above this are shown on the review card; null = never ask.
  final int? reviewAboveMinor;

  Profile copyWith({
    String? name,
    Set<String>? ignoredAccounts,
    int? reviewAboveMinor,
    bool neverReview = false,
  }) =>
      Profile(
        name: name ?? this.name,
        ignoredAccounts: ignoredAccounts ?? this.ignoredAccounts,
        reviewAboveMinor: neverReview ? null : reviewAboveMinor ?? this.reviewAboveMinor,
      );

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] as String?) ?? '',
        ignoredAccounts: ((j['ignoredAccounts'] as List?) ?? const []).cast<String>().toSet(),
        reviewAboveMinor: j.containsKey('reviewAboveMinor')
            ? j['reviewAboveMinor'] as int?
            : defaultReviewAbove,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'ignoredAccounts': ignoredAccounts.toList(),
        'reviewAboveMinor': reviewAboveMinor,
      };
}
