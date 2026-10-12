import 'dart:convert';

import 'package:http/http.dart' as http;

import '../money.dart';
import 'models.dart';

/// What the app needs from Splitwise. [HttpSplitwiseApi] talks to the real
/// API; [DemoSplitwiseApi] fakes it so the UI works before a key is added.
abstract class SplitwiseApi {
  bool get isDemo;
  Future<CurrentUser> getCurrentUser();
  Future<List<SwGroup>> getGroups();
  Future<List<SwUser>> getFriends();

  /// Splits equally among everyone in the group; current user pays.
  Future<void> createGroupExpense({
    required int groupId,
    required int costMinor,
    required String description,
    required String currency,
  });

  /// Expense with explicit shares — in [groupId], or outside groups (0).
  Future<void> createSharedExpense({
    required List<ExpenseShare> shares,
    required int costMinor,
    required String description,
    required String currency,
    int groupId = 0,
  });
}

class HttpSplitwiseApi implements SplitwiseApi {
  HttpSplitwiseApi(this._apiKey, {http.Client? client})
      : _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static final _base = Uri.parse('https://secure.splitwise.com/api/v3.0/');

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  @override
  bool get isDemo => false;

  @override
  Future<CurrentUser> getCurrentUser() async {
    final json = await _get('get_current_user');
    final user = json['user'] as Map<String, dynamic>;
    return CurrentUser(
      user: SwUser.fromJson(user),
      defaultCurrency: (user['default_currency'] as String?) ?? 'INR',
    );
  }

  @override
  Future<List<SwGroup>> getGroups() async {
    final json = await _get('get_groups');
    return (json['groups'] as List)
        .map((g) => SwGroup.fromJson(g as Map<String, dynamic>))
        // Group 0 is Splitwise's bucket for non-group expenses.
        .where((g) => g.id != 0)
        .toList();
  }

  @override
  Future<List<SwUser>> getFriends() async {
    final json = await _get('get_friends');
    return (json['friends'] as List)
        .map((f) => SwUser.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> createGroupExpense({
    required int groupId,
    required int costMinor,
    required String description,
    required String currency,
  }) =>
      _post('create_expense', {
        'cost': minorToDecimal(costMinor),
        'description': description,
        'currency_code': currency,
        'group_id': groupId,
        'split_equally': true,
      });

  @override
  Future<void> createSharedExpense({
    required List<ExpenseShare> shares,
    required int costMinor,
    required String description,
    required String currency,
    int groupId = 0,
  }) =>
      _post('create_expense', {
        'cost': minorToDecimal(costMinor),
        'description': description,
        'currency_code': currency,
        'group_id': groupId,
        for (var i = 0; i < shares.length; i++) ...{
          'users__${i}__user_id': shares[i].userId,
          'users__${i}__paid_share': minorToDecimal(shares[i].paidMinor),
          'users__${i}__owed_share': minorToDecimal(shares[i].owedMinor),
        },
      });

  Future<Map<String, dynamic>> _get(String path) async =>
      _decode(await _client.get(_base.resolve(path), headers: _headers));

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async =>
      _decode(await _client.post(
        _base.resolve(path),
        headers: _headers,
        body: jsonEncode(body),
      ));

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 401) {
      throw const SplitwiseException('Splitwise rejected the API key.');
    }
    if (response.statusCode == 429) {
      throw const SplitwiseException('Too many requests — try again in a minute.');
    }
    if (response.statusCode >= 400) {
      throw SplitwiseException('Splitwise error (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // A 200 can still be a failure: success only if `errors` is empty.
    final message = errorMessage(json['errors']);
    if (message != null) throw SplitwiseException(message);
    return json;
  }
}

/// Flattens Splitwise's `errors` (map of lists, or a list) into one line.
/// Returns null when there are no errors.
String? errorMessage(Object? errors) {
  final messages = <String>[];
  void collect(Object? value) {
    if (value is Map) {
      value.values.forEach(collect);
    } else if (value is List) {
      value.forEach(collect);
    } else if (value != null && '$value'.isNotEmpty) {
      messages.add('$value');
    }
  }

  collect(errors);
  return messages.isEmpty ? null : messages.join(' ');
}

class DemoSplitwiseApi implements SplitwiseApi {
  static const _you = SwUser(id: 1, firstName: 'You');
  static const _aarav = SwUser(id: 2, firstName: 'Aarav', lastName: 'Mehta');
  static const _meera = SwUser(id: 3, firstName: 'Meera', lastName: 'Iyer');
  static const _kabir = SwUser(id: 4, firstName: 'Kabir', lastName: 'Singh');
  static const _zoya = SwUser(id: 5, firstName: 'Zoya', lastName: 'Khan');

  @override
  bool get isDemo => true;

  Future<void> _latency() => Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<CurrentUser> getCurrentUser() async {
    await _latency();
    return const CurrentUser(user: _you, defaultCurrency: 'INR');
  }

  @override
  Future<List<SwGroup>> getGroups() async {
    await _latency();
    return const [
      SwGroup(id: 101, name: 'Flatmates', members: [_you, _aarav, _meera]),
      SwGroup(id: 102, name: 'Goa trip', members: [_you, _aarav, _kabir, _zoya]),
      SwGroup(id: 103, name: 'Office lunch', members: [_you, _meera, _zoya]),
    ];
  }

  @override
  Future<List<SwUser>> getFriends() async {
    await _latency();
    return const [_aarav, _meera, _kabir, _zoya];
  }

  @override
  Future<void> createGroupExpense({
    required int groupId,
    required int costMinor,
    required String description,
    required String currency,
  }) =>
      _latency();

  @override
  Future<void> createSharedExpense({
    required List<ExpenseShare> shares,
    required int costMinor,
    required String description,
    required String currency,
    int groupId = 0,
  }) =>
      _latency();
}
