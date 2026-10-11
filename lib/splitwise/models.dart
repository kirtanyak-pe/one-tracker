class SwUser {
  const SwUser({required this.id, required this.firstName, this.lastName});

  final int id;
  final String firstName;
  final String? lastName;

  String get name =>
      [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  factory SwUser.fromJson(Map<String, dynamic> json) => SwUser(
        id: json['id'] as int,
        firstName: (json['first_name'] as String?) ?? '',
        lastName: json['last_name'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'first_name': firstName, 'last_name': lastName};
}

class SwGroup {
  const SwGroup({required this.id, required this.name, required this.members});

  final int id;
  final String name;
  final List<SwUser> members;

  factory SwGroup.fromJson(Map<String, dynamic> json) => SwGroup(
        id: json['id'] as int,
        name: (json['name'] as String?) ?? 'Group',
        members: ((json['members'] as List?) ?? const [])
            .map((m) => SwUser.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
      };
}

class CurrentUser {
  const CurrentUser({required this.user, required this.defaultCurrency});

  final SwUser user;
  final String defaultCurrency;
}

/// One person's line in a non-group expense.
class ExpenseShare {
  const ExpenseShare({
    required this.userId,
    required this.paidMinor,
    required this.owedMinor,
  });

  final int userId;
  final int paidMinor;
  final int owedMinor;
}

class SplitwiseException implements Exception {
  const SplitwiseException(this.message);

  final String message;

  @override
  String toString() => message;
}
