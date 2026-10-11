import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/transaction.dart';

/// Everything lives on the phone, in app storage.
class AppStore {
  final _prefs = SharedPreferencesAsync();

  static const _txns = 'txns_v1';
  static const _rules = 'rules_v1';
  static const _profile = 'profile_v1';
  static const _lastScan = 'last_sms_scan';

  Future<List<Txn>> readTxns() async {
    final raw = await _prefs.getString(_txns);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((j) => Txn.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> writeTxns(List<Txn> txns) =>
      _prefs.setString(_txns, jsonEncode(txns.map((t) => t.toJson()).toList()));

  Future<Map<String, PayeeRule>> readRules() async {
    final raw = await _prefs.getString(_rules);
    if (raw == null) return {};
    final rules = (jsonDecode(raw) as List).map((j) => PayeeRule.fromJson(j as Map<String, dynamic>));
    return {for (final r in rules) r.key: r};
  }

  Future<void> writeRules(Map<String, PayeeRule> rules) =>
      _prefs.setString(_rules, jsonEncode(rules.values.map((r) => r.toJson()).toList()));

  Future<Profile> readProfile() async {
    final raw = await _prefs.getString(_profile);
    return raw == null ? const Profile() : Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeProfile(Profile profile) => _prefs.setString(_profile, jsonEncode(profile.toJson()));

  Future<DateTime?> readLastScan() async {
    final ms = await _prefs.getInt(_lastScan);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> writeLastScan(DateTime at) => _prefs.setInt(_lastScan, at.millisecondsSinceEpoch);

  Future<void> clear() => _prefs.clear(allowList: {_txns, _rules, _profile, _lastScan});
}
