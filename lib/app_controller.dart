import 'dart:async';

import 'package:flutter/widgets.dart';

import 'engine/classify.dart';
import 'engine/enrich.dart';
import 'engine/ingest.dart';
import 'engine/summary.dart';
import 'model/category.dart';
import 'model/transaction.dart';
import 'sources/notification_source.dart';
import 'sources/sample_data.dart';
import 'sources/sms_source.dart';
import 'storage/app_store.dart';

/// App-wide state. Stores facts + user choices; [ledger] and [month] are
/// re-derived from them after every change.
class AppController extends ChangeNotifier {
  AppController(this._store);

  final AppStore _store;
  late final _notifications = NotificationSource(_onNotification);
  late final _lifecycle = AppLifecycleListener(onResume: _onResume);

  List<Txn> _txns = [];
  Map<String, PayeeRule> rules = {};
  Profile profile = const Profile();
  Ledger ledger = Ledger.empty;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late MonthSummary month = summarize(ledger, _month);

  bool loading = true;
  bool scanning = false;
  bool smsGranted = false;
  bool notificationsGranted = false;
  DateTime? lastScan;

  static const _backfill = Duration(days: 90);

  bool get isAndroid => SmsSource.isSupported;
  bool get isCurrentMonth =>
      _month.year == DateTime.now().year && _month.month == DateTime.now().month;
  List<Enriched> get toReview => month.items.where((e) => e.needsReview).toList();
  bool get hasSampleData => _txns.any((t) => t.source == Source.sample);

  Enriched? find(String id) => ledger.items.where((e) => e.txn.id == id).firstOrNull;
  PayeeRule? ruleFor(Txn t) => rules[payeeKey(t)];

  Future<void> init() async {
    _lifecycle; // start listening for resume
    _txns = await _store.readTxns();
    rules = await _store.readRules();
    profile = await _store.readProfile();
    lastScan = await _store.readLastScan();
    _recompute();
    await refreshPermissions();
    if (smsGranted) {
      await scanSms();
    } else if (!isAndroid && _txns.isEmpty) {
      await loadSamples(); // web preview: show something real-looking
    }
    loading = false;
    notifyListeners();
  }

  void _recompute() {
    ledger = enrich(_txns, profile: profile, rules: rules);
    month = summarize(ledger, _month);
  }

  Future<void> _save() async {
    _recompute();
    notifyListeners();
    await _store.writeTxns(_txns);
  }

  // ── Sources ──────────────────────────────────────────────────────────

  Future<void> refreshPermissions() async {
    smsGranted = await SmsSource.hasPermission();
    notificationsGranted = await NotificationSource.hasPermission();
    if (notificationsGranted) _notifications.start();
    notifyListeners();
  }

  Future<void> requestSms() async {
    await SmsSource.requestPermission();
    await refreshPermissions();
    if (smsGranted) await scanSms(full: true);
  }

  Future<void> requestNotifications() async {
    await NotificationSource.requestPermission();
    await refreshPermissions();
  }

  /// Reads new bank SMS. [full] re-reads the last 90 days.
  Future<int> scanSms({bool full = false}) async {
    if (!smsGranted || scanning) return 0;
    scanning = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final since = full || lastScan == null
          ? now.subtract(_backfill)
          // Small overlap; re-reads are skipped by SMS id.
          : lastScan!.subtract(const Duration(hours: 1));
      final result = ingest(_txns, await SmsSource.read(since: since));
      _txns = result.txns;
      lastScan = now;
      await _store.writeLastScan(now);
      await _save();
      return result.added;
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void _onNotification(RawMessage message) {
    // Saved even when nothing was added: it may have enriched an SMS twin.
    _txns = ingest(_txns, [message]).txns;
    unawaited(_save());
  }

  Future<void> loadSamples() async {
    _txns = ingest(_txns, sampleMessages(DateTime.now())).txns;
    await _save();
  }

  Future<void> removeSamples() async {
    _txns = _txns.where((t) => t.source != Source.sample).toList();
    await _save();
  }

  // ── Month ────────────────────────────────────────────────────────────

  void shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    _month = next;
    month = summarize(ledger, _month);
    notifyListeners();
  }

  // ── Edits ────────────────────────────────────────────────────────────

  Future<void> _update(String id, Txn Function(Txn t) change) async {
    final i = _txns.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _txns[i] = change(_txns[i]);
    await _save();
  }

  Future<void> setKind(Txn txn, TxnKind kind) =>
      _update(txn.id, (t) => t.copyWith(kindOverride: kind, reviewed: true));

  Future<void> setCategory(Txn txn, Category category) =>
      _update(txn.id, (t) => t.copyWith(categoryOverride: category, reviewed: true));

  Future<void> markReviewed(Txn txn) => _update(txn.id, (t) => t.copyWith(reviewed: true));

  Future<void> addTag(Txn txn, String tag) {
    final clean = tag.trim();
    if (clean.isEmpty) return Future.value();
    return _update(txn.id, (t) => t.copyWith(userTags: {...t.userTags, clean}.toList()));
  }

  Future<void> removeTag(Txn txn, String tag) =>
      _update(txn.id, (t) => t.copyWith(userTags: t.userTags.where((x) => x != tag).toList()));

  Future<void> delete(Txn txn) async {
    _txns = _txns.where((t) => t.id != txn.id).toList();
    await _save();
  }

  Future<void> addManual({
    required int amountMinor,
    required String payee,
    required Category category,
    required DateTime at,
  }) async {
    final id = 'manual-${DateTime.now().microsecondsSinceEpoch}';
    _txns = [
      ..._txns,
      Txn(
        id: id,
        source: Source.manual,
        direction: Direction.debit,
        amountMinor: amountMinor,
        at: at,
        counterparty: payee.trim().isEmpty ? null : payee.trim(),
        categoryOverride: category,
        reviewed: true,
      ),
    ];
    await _save();
  }

  // ── Rules & profile ──────────────────────────────────────────────────

  /// Applies this transaction's current category and kind to every payment
  /// to the same payee, now and in future.
  Future<void> rememberFor(Enriched e) async {
    final key = payeeKey(e.txn);
    if (key.isEmpty) return;
    rules = {
      ...rules,
      key: PayeeRule(
        key: key,
        label: e.payee,
        category: e.category == Category.income ? null : e.category,
        kind: e.kind == TxnKind.expense || e.kind == TxnKind.income ? null : e.kind,
      ),
    };
    await _store.writeRules(rules);
    await _save();
  }

  Future<void> forget(String key) async {
    rules = {...rules}..remove(key);
    await _store.writeRules(rules);
    await _save();
  }

  Future<void> setName(String name) async {
    profile = Profile(name: name, ignoredAccounts: profile.ignoredAccounts);
    await _store.writeProfile(profile);
    await _save();
  }

  Future<void> toggleAccount(String last4) async {
    final ignored = {...profile.ignoredAccounts};
    if (!ignored.remove(last4)) ignored.add(last4);
    profile = Profile(name: profile.name, ignoredAccounts: ignored);
    await _store.writeProfile(profile);
    await _save();
  }

  /// Accounts seen in SMS, including ones the user switched off.
  Set<String> get knownAccounts => {...ledger.ownAccounts, ...profile.ignoredAccounts};

  Future<void> clearAll() async {
    await _store.clear();
    _txns = [];
    rules = {};
    profile = const Profile();
    lastScan = null;
    await _save();
  }

  Future<void> _onResume() async {
    await refreshPermissions();
    await scanSms();
  }

  @override
  void dispose() {
    _notifications.stop();
    _lifecycle.dispose();
    super.dispose();
  }
}

/// Makes the [AppController] available to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
