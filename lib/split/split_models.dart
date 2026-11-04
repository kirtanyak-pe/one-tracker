/// A payment that was handed to Splitwise (its Add expense screen opened).
class SplitRecord {
  const SplitRecord({
    required this.txnId,
    required this.label,
    required this.amountMinor,
    required this.description,
    required this.at,
  });

  final String txnId;

  /// The default group's name, or "Splitwise".
  final String label;
  final int amountMinor;
  final String description;

  /// When it was opened in Splitwise.
  final DateTime at;

  /// Records written by the old demo mode (`demo: true`) never reached
  /// Splitwise; [SplitRecord.fromJson] callers drop them with [isOldDemo].
  static bool isOldDemo(Map<String, dynamic> j) => j['demo'] == true;

  factory SplitRecord.fromJson(Map<String, dynamic> j) => SplitRecord(
        txnId: j['txnId'] as String,
        label: (j['label'] as String?) ?? 'Splitwise',
        amountMinor: j['amountMinor'] as int,
        description: j['description'] as String,
        at: DateTime.parse(j['at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'txnId': txnId,
        'label': label,
        'amountMinor': amountMinor,
        'description': description,
        'at': at.toIso8601String(),
      };
}

class SplitSettings {
  const SplitSettings({this.notify = true, this.minMinor = 10000, this.groupId, this.groupName});

  /// Offer to split right after each new payment.
  final bool notify;

  /// Don't offer for payments at or below this (default ₹100).
  final int minMinor;

  /// Splitwise group new expenses start in (its id, from the group's link).
  final int? groupId;

  /// What the user calls that group (shown in the app only).
  final String? groupName;

  SplitSettings copyWith({bool? notify, int? minMinor}) =>
      SplitSettings(notify: notify ?? this.notify, minMinor: minMinor ?? this.minMinor, groupId: groupId, groupName: groupName);

  /// A null [id] clears the default group.
  SplitSettings withGroup(int? id, [String? name]) => SplitSettings(
        notify: notify,
        minMinor: minMinor,
        groupId: id,
        groupName: id == null || (name?.trim().isEmpty ?? true) ? null : name!.trim(),
      );

  /// Reads old data too: `popup` was the name of `notify`.
  factory SplitSettings.fromJson(Map<String, dynamic> j) => SplitSettings(
        notify: (j['notify'] as bool?) ?? (j['popup'] as bool?) ?? true,
        minMinor: (j['minMinor'] as int?) ?? 10000,
        groupId: j['groupId'] as int?,
        groupName: j['groupName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'notify': notify,
        'minMinor': minMinor,
        if (groupId != null) 'groupId': groupId,
        if (groupName != null) 'groupName': groupName,
      };
}
