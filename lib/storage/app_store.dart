import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/automation.dart';
import '../model/transaction.dart';
import '../split/split_models.dart';
import '../splitwise/models.dart';

/// Everything lives on the phone, in app storage. The floating split card
/// runs in its own isolate, so everything goes through uncached storage.
class AppStore {
  final _prefs = SharedPreferencesAsync();
  final _secure = const FlutterSecureStorage();

  static const _txns = 'txns_v1';
  static const _rules = 'rules_v1';
  static const _profile = 'profile_v1';
  static const _lastScan = 'last_sms_scan';
  static const _autoRules = 'auto_rules_v1';
  static const _budgets = 'budgets_v1';
  static const _sentAlerts = 'sent_alerts_v1';
  static const _swKey = 'splitwise_api_key';
  static const _swUser = 'sw_user_v1';
  static const _swGroups = 'sw_groups_v1';
  static const _swFriends = 'sw_friends_v1';
  static const _splitTarget = 'split_target_v1';
  static const _splitRecords = 'split_records_v1';
  static const _splitSkipped = 'split_skipped_v1';
  static const _splitSettings = 'split_settings_v1';
  static const _splitPrompt = 'split_prompt_v1';

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

  Future<List<AutoRule>> readAutoRules() async {
    final raw = await _prefs.getString(_autoRules);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((j) => AutoRule.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> writeAutoRules(List<AutoRule> rules) =>
      _prefs.setString(_autoRules, jsonEncode(rules.map((r) => r.toJson()).toList()));

  Future<Budgets> readBudgets() async {
    final raw = await _prefs.getString(_budgets);
    return raw == null ? const Budgets() : Budgets.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeBudgets(Budgets budgets) => _prefs.setString(_budgets, jsonEncode(budgets.toJson()));

  Future<Set<String>> readSentAlerts() async => ((await _prefs.getStringList(_sentAlerts)) ?? const []).toSet();

  Future<void> writeSentAlerts(Set<String> keys) => _prefs.setStringList(_sentAlerts, keys.toList());

  // ── Splitwise ──────────────────────────────────────────────────────

  /// In the Android keystore, not plain preferences.
  Future<String?> readSplitwiseKey() => _secure.read(key: _swKey);
  Future<void> writeSplitwiseKey(String key) => _secure.write(key: _swKey, value: key);
  Future<void> clearSplitwiseKey() => _secure.delete(key: _swKey);

  /// Cached so the floating card works without a network round-trip first.
  Future<({CurrentUser? user, List<SwGroup> groups, List<SwUser> friends})> readSplitwiseCache() async {
    final user = await _prefs.getString(_swUser);
    final groups = await _prefs.getString(_swGroups);
    final friends = await _prefs.getString(_swFriends);
    return (
      user: user == null ? null : _userFromJson(jsonDecode(user) as Map<String, dynamic>),
      groups: groups == null
          ? <SwGroup>[]
          : (jsonDecode(groups) as List).map((g) => SwGroup.fromJson(g as Map<String, dynamic>)).toList(),
      friends: friends == null
          ? <SwUser>[]
          : (jsonDecode(friends) as List).map((f) => SwUser.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> writeSplitwiseCache(CurrentUser user, List<SwGroup> groups, List<SwUser> friends) async {
    await _prefs.setString(_swUser, jsonEncode({...user.user.toJson(), 'default_currency': user.defaultCurrency}));
    await _prefs.setString(_swGroups, jsonEncode(groups.map((g) => g.toJson()).toList()));
    await _prefs.setString(_swFriends, jsonEncode(friends.map((f) => f.toJson()).toList()));
  }

  Future<void> clearSplitwiseCache() async {
    await _prefs.remove(_swUser);
    await _prefs.remove(_swGroups);
    await _prefs.remove(_swFriends);
  }

  static CurrentUser _userFromJson(Map<String, dynamic> j) =>
      CurrentUser(user: SwUser.fromJson(j), defaultCurrency: (j['default_currency'] as String?) ?? 'INR');

  Future<SplitTarget?> readSplitTarget() async {
    final raw = await _prefs.getString(_splitTarget);
    return raw == null ? null : SplitTarget.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeSplitTarget(SplitTarget? target) => target == null
      ? _prefs.remove(_splitTarget)
      : _prefs.setString(_splitTarget, jsonEncode(target.toJson()));

  Future<Map<String, SplitRecord>> readSplitRecords() async {
    final raw = await _prefs.getString(_splitRecords);
    if (raw == null) return {};
    final list = (jsonDecode(raw) as List).map((j) => SplitRecord.fromJson(j as Map<String, dynamic>));
    return {for (final r in list) r.txnId: r};
  }

  /// Adds one record; safe to call from either isolate.
  Future<Map<String, SplitRecord>> addSplitRecord(SplitRecord record) async {
    final records = {...await readSplitRecords(), record.txnId: record};
    await _prefs.setString(_splitRecords, jsonEncode(records.values.map((r) => r.toJson()).toList()));
    return records;
  }

  Future<Set<String>> readSplitSkipped() async => ((await _prefs.getStringList(_splitSkipped)) ?? const []).toSet();

  Future<void> writeSplitSkipped(Set<String> ids) => _prefs.setStringList(_splitSkipped, ids.toList());

  Future<SplitSettings> readSplitSettings() async {
    final raw = await _prefs.getString(_splitSettings);
    return raw == null ? const SplitSettings() : SplitSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeSplitSettings(SplitSettings s) => _prefs.setString(_splitSettings, jsonEncode(s.toJson()));

  /// The payment the floating card is about (written before it opens).
  Future<SplitPrompt?> readSplitPrompt() async {
    final raw = await _prefs.getString(_splitPrompt);
    return raw == null ? null : SplitPrompt.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeSplitPrompt(SplitPrompt prompt) => _prefs.setString(_splitPrompt, jsonEncode(prompt.toJson()));

  Future<void> clear() async {
    await _prefs.clear(
      allowList: {
        _txns, _rules, _profile, _lastScan, _autoRules, _budgets, _sentAlerts, //
        _swUser, _swGroups, _swFriends, _splitTarget, _splitRecords, _splitSkipped, _splitSettings, _splitPrompt,
      },
    );
    await clearSplitwiseKey();
  }
}
