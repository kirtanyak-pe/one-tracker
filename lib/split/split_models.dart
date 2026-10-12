import '../splitwise/models.dart';

enum TargetKind { group, friends }

/// Who a payment gets split with — a Splitwise group, or a set of friends.
/// Always split equally, you paid.
class SplitTarget {
  const SplitTarget._({
    required this.kind,
    required this.label,
    required this.people,
    this.groupId,
    this.friendIds = const [],
  });

  factory SplitTarget.group(SwGroup g) => SplitTarget._(
        kind: TargetKind.group,
        groupId: g.id,
        label: g.name,
        people: g.members.length,
      );

  factory SplitTarget.friends(List<SwUser> friends) => SplitTarget._(
        kind: TargetKind.friends,
        friendIds: friends.map((f) => f.id).toList(),
        label: friends.map((f) => f.firstName).join(', '),
        people: friends.length + 1, // + you
      );

  final TargetKind kind;
  final int? groupId;
  final List<int> friendIds;
  final String label;

  /// Including you.
  final int people;

  int shareOf(int amountMinor) => people <= 0 ? amountMinor : amountMinor ~/ people;

  bool sameAs(SplitTarget? other) =>
      other != null &&
      other.kind == kind &&
      other.groupId == groupId &&
      ({...other.friendIds}.length == friendIds.length && other.friendIds.every(friendIds.contains));

  factory SplitTarget.fromJson(Map<String, dynamic> j) => SplitTarget._(
        kind: TargetKind.values.byName(j['kind'] as String),
        groupId: j['groupId'] as int?,
        friendIds: ((j['friendIds'] as List?) ?? const []).cast<int>(),
        label: j['label'] as String,
        people: j['people'] as int,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'groupId': groupId,
        'friendIds': friendIds,
        'label': label,
        'people': people,
      };
}

/// A payment that was sent to Splitwise.
class SplitRecord {
  const SplitRecord({
    required this.txnId,
    required this.label,
    required this.amountMinor,
    required this.description,
    required this.at,
    this.demo = false,
  });

  final String txnId;

  /// Group name or friends.
  final String label;
  final int amountMinor;
  final String description;
  final DateTime at;

  /// Made in demo mode — nothing was sent.
  final bool demo;

  factory SplitRecord.fromJson(Map<String, dynamic> j) => SplitRecord(
        txnId: j['txnId'] as String,
        label: j['label'] as String,
        amountMinor: j['amountMinor'] as int,
        description: j['description'] as String,
        at: DateTime.parse(j['at'] as String),
        demo: (j['demo'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'txnId': txnId,
        'label': label,
        'amountMinor': amountMinor,
        'description': description,
        'at': at.toIso8601String(),
        'demo': demo,
      };
}

class SplitSettings {
  const SplitSettings({this.popup = true, this.minMinor = 10000});

  /// Ask right after each new payment.
  final bool popup;

  /// Don't ask about payments at or below this (default ₹100).
  final int minMinor;

  SplitSettings copyWith({bool? popup, int? minMinor}) =>
      SplitSettings(popup: popup ?? this.popup, minMinor: minMinor ?? this.minMinor);

  factory SplitSettings.fromJson(Map<String, dynamic> j) => SplitSettings(
        popup: (j['popup'] as bool?) ?? true,
        minMinor: (j['minMinor'] as int?) ?? 10000,
      );

  Map<String, dynamic> toJson() => {'popup': popup, 'minMinor': minMinor};
}

/// What the floating card needs to know about the payment.
class SplitPrompt {
  const SplitPrompt({
    required this.txnId,
    required this.amountMinor,
    required this.payee,
    required this.at,
  });

  final String txnId;
  final int amountMinor;
  final String payee;
  final DateTime at;

  factory SplitPrompt.fromJson(Map<String, dynamic> j) => SplitPrompt(
        txnId: j['txnId'] as String,
        amountMinor: j['amountMinor'] as int,
        payee: j['payee'] as String,
        at: DateTime.parse(j['at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'txnId': txnId,
        'amountMinor': amountMinor,
        'payee': payee,
        'at': at.toIso8601String(),
      };
}
