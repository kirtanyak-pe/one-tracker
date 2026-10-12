import 'dart:async';

import 'package:flutter/widgets.dart';

import 'engine/classify.dart';
import 'engine/enrich.dart';
import 'engine/ingest.dart';
import 'engine/insights.dart';
import 'engine/recurring.dart';
import 'engine/summary.dart';
import 'engine/widget_data.dart';
import 'model/automation.dart';
import 'model/category.dart';
import 'model/transaction.dart';
import 'money.dart';
import 'sources/notification_source.dart';
import 'sources/notifier.dart';
import 'sources/sample_data.dart';
import 'sources/sms_source.dart';
import 'sources/widget_bridge.dart';
import 'split/split_models.dart';
import 'split/split_overlay.dart';
import 'split/split_service.dart';
import 'split/suggest.dart';
import 'splitwise/models.dart';
import 'splitwise/splitwise_api.dart';
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
  List<AutoRule> autoRules = [];
  Budgets budgets = const Budgets();
  Set<String> _sentAlerts = {};
  Profile profile = const Profile();
  Ledger ledger = Ledger.empty;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late MonthSummary month = summarize(ledger, _month);
  late Insights insights = buildInsights(ledger, _month);
  List<Recurring> recurring = [];

  // Splitwise
  SplitwiseApi _sw = DemoSplitwiseApi();
  CurrentUser? swUser;
  List<SwGroup> swGroups = [];
  List<SwUser> swFriends = [];
  String? swError;
  bool swLoading = false;
  SplitTarget? splitTarget;
  Map<String, SplitRecord> splitRecords = {};
  Set<String> splitSkipped = {};
  SplitSettings splitSettings = const SplitSettings();
  bool overlayGranted = false;
  StreamSubscription<dynamic>? _overlayMessages;

  /// Shows the split card inside the app (when it's open at payment time).
  void Function(Enriched payment)? onSplitSuggestion;

  bool get swConnected => !_sw.isDemo;
  Set<String> get _splitHandled => {...splitRecords.keys, ...splitSkipped};

  /// Last 30 days of payments not yet split or skipped.
  List<Enriched> get splitTodo => splitCandidates(
        ledger.items,
        handled: _splitHandled,
        settings: splitSettings,
        since: DateTime.now().subtract(const Duration(days: 30)),
      );

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
    // Apply any parser improvements to what's already stored.
    _txns = (await _store.readTxns()).map(reparse).toList();
    rules = await _store.readRules();
    autoRules = await _store.readAutoRules();
    budgets = await _store.readBudgets();
    _sentAlerts = await _store.readSentAlerts();
    profile = await _store.readProfile();
    await _loadSplitState();
    final swKey = await _store.readSplitwiseKey();
    if (swKey != null) _sw = HttpSplitwiseApi(swKey);
    final cache = await _store.readSplitwiseCache();
    swUser = cache.user;
    swGroups = cache.groups;
    swFriends = cache.friends;
    if (SplitOverlay.isSupported) {
      // The floating card split something: pick it up straight away.
      _overlayMessages = SplitOverlay.messages.listen((_) async {
        await _loadSplitState();
        notifyListeners();
      });
    }
    unawaited(refreshSplitwise());
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
    await _pushWidget();
  }

  void _recompute() {
    ledger = enrich(_txns, profile: profile, rules: rules, autoRules: autoRules);
    _recomputeMonth();
    recurring = findRecurring(ledger);
  }

  void _recomputeMonth() {
    month = summarize(ledger, _month);
    insights = buildInsights(ledger, _month);
  }

  Future<void> _save() async {
    _recompute();
    notifyListeners();
    await _store.writeTxns(_txns);
    await _checkBudgets();
    await _pushWidget();
  }

  Future<void> _pushWidget() => WidgetBridge.push(widgetPeriods(ledger, budgets));

  /// Notifies once per month per threshold (80%, 100%).
  Future<void> _checkBudgets() async {
    if (budgets.isEmpty) return;
    final now = DateTime.now();
    final current = summarize(ledger, DateTime(now.year, now.month));
    final alerts = budgetAlerts(current, budgets, _sentAlerts, money: (m) => formatMoney(m, appCurrency));
    if (alerts.isEmpty) return;
    for (final a in alerts) {
      await Notifier.show(a.key.hashCode & 0x7fffffff, a.title, a.body);
      _sentAlerts.add(a.key);
    }
    await _store.writeSentAlerts(_sentAlerts);
  }

  /// This month's spend vs the monthly budget, 0..1+ (null if no budget).
  double? get budgetUse {
    final limit = budgets.monthlyMinor;
    if (limit == null || limit == 0) return null;
    return month.spentMinor / limit;
  }

  /// Recurring payments due in the next [days] days.
  List<Recurring> upcoming({int days = 14}) {
    final until = DateTime.now().add(Duration(days: days));
    return recurring.where((r) => r.nextDue.isBefore(until)).toList();
  }

  // ── Sources ──────────────────────────────────────────────────────────

  Future<void> refreshPermissions() async {
    smsGranted = await SmsSource.hasPermission();
    notificationsGranted = await NotificationSource.hasPermission();
    overlayGranted = await SplitOverlay.hasPermission();
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
      if (!full) await _suggestSplit(result.addedIds);
      return result.added;
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void _onNotification(RawMessage message) {
    // Saved even when nothing was added: it may have enriched an SMS twin.
    final result = ingest(_txns, [message]);
    _txns = result.txns;
    unawaited(_save().then((_) => _suggestSplit(result.addedIds)));
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
    _recomputeMonth();
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
    profile = profile.copyWith(name: name);
    await _store.writeProfile(profile);
    await _save();
  }

  Future<void> toggleAccount(String last4) async {
    final ignored = {...profile.ignoredAccounts};
    if (!ignored.remove(last4)) ignored.add(last4);
    profile = profile.copyWith(ignoredAccounts: ignored);
    await _store.writeProfile(profile);
    await _save();
  }

  // ── Automation ───────────────────────────────────────────────────────

  Future<void> saveAutoRule(AutoRule rule) async {
    autoRules = [...autoRules.where((r) => r.id != rule.id), rule];
    await _store.writeAutoRules(autoRules);
    await _save();
  }

  Future<void> removeAutoRule(String id) async {
    autoRules = autoRules.where((r) => r.id != id).toList();
    await _store.writeAutoRules(autoRules);
    await _save();
  }

  Future<void> setBudgets(Budgets next) async {
    final adding = budgets.isEmpty && !next.isEmpty;
    budgets = next;
    await _store.writeBudgets(budgets);
    if (adding) await Notifier.requestPermission();
    await _save();
  }

  /// Null turns the big-payment check off.
  Future<void> setReviewAbove(int? minor) async {
    profile = profile.copyWith(reviewAboveMinor: minor, neverReview: minor == null);
    await _store.writeProfile(profile);
    await _save();
  }

  /// Accounts seen in SMS, including ones the user switched off.
  Set<String> get knownAccounts => {...ledger.ownAccounts, ...profile.ignoredAccounts};

  Future<void> clearAll() async {
    await _store.clear();
    _txns = [];
    rules = {};
    autoRules = [];
    budgets = const Budgets();
    _sentAlerts = {};
    _sw = DemoSplitwiseApi();
    splitTarget = null;
    splitRecords = {};
    splitSkipped = {};
    splitSettings = const SplitSettings();
    profile = const Profile();
    lastScan = null;
    await _save();
  }

  Future<void> _onResume() async {
    await _loadSplitState();
    await refreshPermissions();
    await scanSms();
  }

  // ── Splitwise ──────────────────────────────────────────────────────

  Future<void> _loadSplitState() async {
    splitTarget = await _store.readSplitTarget();
    splitRecords = await _store.readSplitRecords();
    splitSkipped = await _store.readSplitSkipped();
    splitSettings = await _store.readSplitSettings();
  }

  Future<void> refreshSplitwise() async {
    swLoading = true;
    swError = null;
    notifyListeners();
    try {
      final results = await Future.wait([_sw.getCurrentUser(), _sw.getGroups(), _sw.getFriends()]);
      swUser = results[0] as CurrentUser;
      swGroups = results[1] as List<SwGroup>;
      swFriends = results[2] as List<SwUser>;
      await _store.writeSplitwiseCache(swUser!, swGroups, swFriends);
    } catch (e) {
      swError = '$e';
    } finally {
      swLoading = false;
      notifyListeners();
    }
  }

  /// Checks the key with Splitwise before saving it.
  Future<void> connectSplitwise(String key) async {
    final api = HttpSplitwiseApi(key.trim());
    await api.getCurrentUser();
    await _store.writeSplitwiseKey(key.trim());
    _sw = api;
    splitTarget = null; // demo groups don't exist in the real account
    await _store.writeSplitTarget(null);
    await refreshSplitwise();
  }

  Future<void> disconnectSplitwise() async {
    await _store.clearSplitwiseKey();
    await _store.clearSplitwiseCache();
    _sw = DemoSplitwiseApi();
    splitTarget = null;
    await _store.writeSplitTarget(null);
    await refreshSplitwise();
  }

  Future<void> setSplitTarget(SplitTarget? target) async {
    splitTarget = target;
    await _store.writeSplitTarget(target);
    notifyListeners();
  }

  Future<void> setSplitSettings(SplitSettings next) async {
    splitSettings = next;
    await _store.writeSplitSettings(next);
    notifyListeners();
  }

  Future<void> requestOverlay() async {
    await SplitOverlay.requestPermission();
    await refreshPermissions();
  }

  static SplitPrompt promptFor(Enriched e) =>
      SplitPrompt(txnId: e.txn.id, amountMinor: e.txn.amountMinor, payee: e.payee, at: e.txn.at);

  Future<void> split(Enriched e, SplitTarget target, {bool makeDefault = false}) async {
    final record = await splitOnSplitwise(
      api: _sw,
      target: target,
      myUserId: swUser?.user.id ?? 1,
      prompt: promptFor(e),
      currency: swUser?.defaultCurrency ?? appCurrency,
    );
    splitRecords = await _store.addSplitRecord(record);
    if (makeDefault || splitTarget == null) await setSplitTarget(target);
    notifyListeners();
  }

  Future<void> skipSplit(Enriched e) async {
    splitSkipped = {...splitSkipped, e.txn.id};
    await _store.writeSplitSkipped(splitSkipped);
    notifyListeners();
  }

  /// Right after new payments: offer to split the freshest one.
  Future<void> _suggestSplit(List<String> addedIds) async {
    if (addedIds.isEmpty) return;
    final ids = addedIds.toSet();
    final pick = popupFor(
      ledger.items.where((e) => ids.contains(e.txn.id)),
      handled: _splitHandled,
      settings: splitSettings,
      now: DateTime.now(),
    );
    if (pick == null) return;
    final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foreground && onSplitSuggestion != null) {
      onSplitSuggestion!(pick);
    } else if (overlayGranted) {
      await SplitOverlay.show(promptFor(pick), _store, expanded: splitTarget == null);
    }
  }

  /// Shows the floating card for the latest payment, to try it out.
  Future<bool> previewFloatingCard() async {
    final e = splitTodo.firstOrNull ?? ledger.items.where((e) => e.countsAsSpend).firstOrNull;
    if (e == null || !overlayGranted) return false;
    await SplitOverlay.show(promptFor(e), _store, expanded: splitTarget == null);
    return true;
  }

  @override
  void dispose() {
    _overlayMessages?.cancel();
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
