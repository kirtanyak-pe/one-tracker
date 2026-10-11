import 'category.dart';
import 'transaction.dart';

/// "If a payment mentions this text, file it as …" — applied to every payment,
/// past and future. Payee rules and per-payment choices win over these.
class AutoRule {
  const AutoRule({
    required this.id,
    required this.contains,
    this.category,
    this.kind,
    this.tag,
  });

  final String id;

  /// Matched case-insensitively against payee, UPI id and the message text.
  final String contains;
  final Category? category;
  final TxnKind? kind;
  final String? tag;

  bool matches(String haystack) =>
      contains.trim().isNotEmpty && haystack.toLowerCase().contains(contains.trim().toLowerCase());

  String get summary => [
        if (category != null) category!.label,
        if (kind != null) kind!.label,
        if (tag != null && tag!.isNotEmpty) '#$tag',
      ].join(' · ');

  factory AutoRule.fromJson(Map<String, dynamic> j) => AutoRule(
        id: j['id'] as String,
        contains: j['contains'] as String,
        category: Category.byName(j['category'] as String?),
        kind: TxnKind.byName(j['kind'] as String?),
        tag: j['tag'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'contains': contains,
        'category': category?.name,
        'kind': kind?.name,
        'tag': tag,
      };
}

/// Monthly spending limits. Amounts in paise; null = no limit.
class Budgets {
  const Budgets({this.monthlyMinor, this.byCategory = const {}});

  final int? monthlyMinor;
  final Map<Category, int> byCategory;

  bool get isEmpty => monthlyMinor == null && byCategory.isEmpty;

  Budgets withMonthly(int? minor) => Budgets(monthlyMinor: minor, byCategory: byCategory);

  Budgets withCategory(Category c, int? minor) {
    final next = {...byCategory};
    minor == null ? next.remove(c) : next[c] = minor;
    return Budgets(monthlyMinor: monthlyMinor, byCategory: next);
  }

  factory Budgets.fromJson(Map<String, dynamic> j) => Budgets(
        monthlyMinor: j['monthlyMinor'] as int?,
        byCategory: {
          for (final e in ((j['byCategory'] as Map?) ?? const {}).entries)
            if (Category.byName(e.key as String) != null) Category.byName(e.key as String)!: e.value as int,
        },
      );

  Map<String, dynamic> toJson() => {
        'monthlyMinor': monthlyMinor,
        'byCategory': {for (final e in byCategory.entries) e.key.name: e.value},
      };
}
