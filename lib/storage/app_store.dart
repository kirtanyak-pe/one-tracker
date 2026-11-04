import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/appearance.dart';
import '../model/automation.dart';
import '../model/transaction.dart';
import '../split/split_models.dart';

/// Everything lives on the phone, in app storage. The background SMS engine
/// is its own isolate, so everything goes through uncached storage.
class AppStore {
  final _prefs = SharedPreferencesAsync();

  static const _txns = 'txns_v1';
  static const _rules = 'rules_v1';
  static const _profile = 'profile_v1';
  static const _lastScan = 'last_sms_scan';
  static const _autoRules = 'auto_rules_v1';
  static const _budgets = 'budgets_v1';
  static const _sentAlerts = 'sent_alerts_v1';
  static const _nudgeDismissed = 'month_nudge_dismissed_v1';
  // Left by the 1.3 API/overlay version; dropped by migrateSplitwise().
  static const _oldSwUser = 'sw_user_v1';
  static const _oldSwGroups = 'sw_groups_v1';
  static const _oldSwFriends = 'sw_friends_v1';
  static const _oldSplitTarget = 'split_target_v1';
  static const _oldSplitPrompt = 'split_prompt_v1';
  static const _splitRecords = 'split_records_v1';
  static const _splitSkipped = 'split_skipped_v1';
  static const _splitSettings = 'split_settings_v1';
  static const _appearance = 'appearance_v1';
  static const _parserVersion = 'parser_version';

  // A year of SMS is a few MB of JSON: decode/encode off the UI thread.
  Future<List<Txn>> readTxns() async {
    final raw = await _prefs.getString(_txns);
    if (raw == null) return [];
    return raw.length > _offThreadBytes ? compute(_decodeTxns, raw) : _decodeTxns(raw);
  }

  Future<void> writeTxns(List<Txn> txns) async =>
      _prefs.setString(_txns, txns.length > 300 ? await compute(_encodeTxns, txns) : _encodeTxns(txns));

  static const _offThreadBytes = 200000;

  static List<Txn> _decodeTxns(String raw) =>
      (jsonDecode(raw) as List).map((j) => Txn.fromJson(j as Map<String, dynamic>)).toList();

  static String _encodeTxns(List<Txn> txns) => jsonEncode(txns.map((t) => t.toJson()).toList());

  Future<int> readParserVersion() async => (await _prefs.getInt(_parserVersion)) ?? 0;
  Future<void> writeParserVersion(int v) => _prefs.setInt(_parserVersion, v);

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

  /// Months whose "count them next month?" card was dismissed ("2026-10").
  Future<Set<String>> readDismissedNudges() async =>
      ((await _prefs.getStringList(_nudgeDismissed)) ?? const []).toSet();

  Future<void> writeDismissedNudges(Set<String> months) =>
      _prefs.setStringList(_nudgeDismissed, months.toList());

  Future<Appearance> readAppearance() async {
    final raw = await _prefs.getString(_appearance);
    return raw == null ? const Appearance() : Appearance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeAppearance(Appearance a) => _prefs.setString(_appearance, jsonEncode(a.toJson()));

  // ── Splitwise ──────────────────────────────────────────────────────

  /// Records the old demo mode made never reached Splitwise: left out.
  Future<Map<String, SplitRecord>> readSplitRecords() async {
    final raw = await _prefs.getString(_splitRecords);
    if (raw == null) return {};
    final list = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .where((j) => !SplitRecord.isOldDemo(j))
        .map(SplitRecord.fromJson);
    return {for (final r in list) r.txnId: r};
  }

  Future<void> writeSplitRecords(Map<String, SplitRecord> records) =>
      _prefs.setString(_splitRecords, jsonEncode(records.values.map((r) => r.toJson()).toList()));

  Future<Map<String, SplitRecord>> addSplitRecord(SplitRecord record) async {
    final records = {...await readSplitRecords(), record.txnId: record};
    await writeSplitRecords(records);
    return records;
  }

  Future<Set<String>> readSplitSkipped() async => ((await _prefs.getStringList(_splitSkipped)) ?? const []).toSet();

  Future<void> writeSplitSkipped(Set<String> ids) => _prefs.setStringList(_splitSkipped, ids.toList());

  Future<SplitSettings> readSplitSettings() async {
    final raw = await _prefs.getString(_splitSettings);
    return raw == null ? const SplitSettings() : SplitSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeSplitSettings(SplitSettings s) => _prefs.setString(_splitSettings, jsonEncode(s.toJson()));

  /// One-time clean-up of the API/overlay version's data. An old default
  /// *group* carries over as the default group; keys, caches and friends go.
  Future<void> migrateSplitwise() async {
    final target = await _prefs.getString(_oldSplitTarget);
    if (target != null) {
      try {
        final j = jsonDecode(target) as Map<String, dynamic>;
        final settings = await readSplitSettings();
        if (j['kind'] == 'group' && j['groupId'] is int && settings.groupId == null) {
          await writeSplitSettings(settings.withGroup(j['groupId'] as int, j['label'] as String?));
        }
      } catch (_) {
        // unreadable: just drop it
      }
    }
    for (final k in [_oldSwUser, _oldSwGroups, _oldSwFriends, _oldSplitTarget, _oldSplitPrompt]) {
      await _prefs.remove(k);
    }
  }

  Future<void> clear() async {
    await _prefs.clear(
      allowList: {
        _txns, _rules, _profile, _lastScan, _autoRules, _budgets, _sentAlerts, //
        _splitRecords, _splitSkipped, _splitSettings, _appearance,
      },
    );
  }
}
