/// A split that was sent to Splitwise, kept locally for the home summary.
class SplitRecord {
  const SplitRecord({
    required this.amountMinor,
    required this.description,
    required this.withWhom,
    required this.at,
  });

  final int amountMinor;
  final String description;

  /// Group name, or friend names joined.
  final String withWhom;
  final DateTime at;

  factory SplitRecord.fromJson(Map<String, dynamic> json) => SplitRecord(
        amountMinor: json['amountMinor'] as int,
        description: json['description'] as String,
        withWhom: json['withWhom'] as String,
        at: DateTime.parse(json['at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'amountMinor': amountMinor,
        'description': description,
        'withWhom': withWhom,
        'at': at.toIso8601String(),
      };
}

/// Monday 00:00 of the week containing [now].
DateTime startOfWeek(DateTime now) =>
    DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
