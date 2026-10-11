import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../detection/detected_payment.dart';
import '../history/split_record.dart';
import '../splitwise/models.dart';

/// Persistence shared by the main app and the floating bubble. The bubble
/// runs in its own isolate, so everything goes through uncached storage.
class AppStore {
  final _secure = const FlutterSecureStorage();
  final _prefs = SharedPreferencesAsync();

  static const _apiKey = 'splitwise_api_key';
  static const _inbox = 'inbox';
  static const _groups = 'cached_groups';
  static const _currency = 'currency';
  static const _bubblePayment = 'bubble_payment';
  static const _history = 'split_history';

  Future<String?> readApiKey() => _secure.read(key: _apiKey);
  Future<void> writeApiKey(String key) => _secure.write(key: _apiKey, value: key);
  Future<void> clearApiKey() => _secure.delete(key: _apiKey);

  Future<List<DetectedPayment>> readInbox() async {
    final raw = await _prefs.getString(_inbox);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((p) => DetectedPayment.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> writeInbox(List<DetectedPayment> inbox) =>
      _prefs.setString(_inbox, jsonEncode(inbox.map((p) => p.toJson()).toList()));

  Future<void> removeFromInbox(String id) async {
    final inbox = await readInbox();
    await writeInbox(inbox.where((p) => p.id != id).toList());
  }

  /// Groups are cached so the bubble can offer them without a network call.
  Future<List<SwGroup>> readCachedGroups() async {
    final raw = await _prefs.getString(_groups);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((g) => SwGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<void> cacheGroups(List<SwGroup> groups) =>
      _prefs.setString(_groups, jsonEncode(groups.map((g) => g.toJson()).toList()));

  Future<String> readCurrency() async => (await _prefs.getString(_currency)) ?? 'INR';
  Future<void> writeCurrency(String currency) => _prefs.setString(_currency, currency);

  /// The payment the bubble should show; written before the bubble opens so
  /// it never misses a message sent before its isolate was listening.
  Future<DetectedPayment?> readBubblePayment() async {
    final raw = await _prefs.getString(_bubblePayment);
    return raw == null
        ? null
        : DetectedPayment.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> writeBubblePayment(DetectedPayment payment) =>
      _prefs.setString(_bubblePayment, jsonEncode(payment.toJson()));

  Future<List<SplitRecord>> readHistory() async {
    final raw = await _prefs.getString(_history);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((r) => SplitRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Newest first; capped so it never grows unbounded.
  Future<List<SplitRecord>> addHistory(SplitRecord record) async {
    final history = [record, ...await readHistory()].take(100).toList();
    await _prefs.setString(_history, jsonEncode(history.map((r) => r.toJson()).toList()));
    return history;
  }
}
