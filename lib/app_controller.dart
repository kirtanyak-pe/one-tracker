import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'engine/classify.dart';
import 'engine/derive.dart';
import 'engine/enrich.dart';
import 'engine/ingest.dart';
import 'engine/parser.dart' show parserVersion;
import 'engine/insights.dart';
import 'engine/month_nudge.dart';
import 'engine/recurring.dart';
import 'engine/summary.dart';
import 'engine/widget_data.dart';
import 'model/appearance.dart';
import 'model/automation.dart';
import 'model/category.dart';
import 'model/transaction.dart';
import 'money.dart';
import 'sources/backup_bridge.dart';
import 'sources/notification_source.dart';
import 'sources/notifier.dart';
import 'sources/sample_data.dart';
import 'sources/sms_source.dart';
import 'sources/splitwise_bridge.dart';
import 'sources/widget_bridge.dart';
import 'split/pending_actions.dart';
import 'split/split_models.dart';
import 'split/suggest.dart';
import 'storage/app_store.dart';
import 'storage/backup.dart';
import 'ui/payee_logo.dart';
import 'ui/perf.dart';
import 'ui/wallpaper_colors.dart';

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
  Set<String> _dismissedNudges = {};
  Profile profile = const Profile();
  Ledger ledger = Ledger.empty;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// The calendar month as of the last check. The app can stay alive for
  /// days (live SMS keeps it running), so "now" has to be re-read.
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// Moves a screen that was showing the current month on to the new one
  /// when the month changes. Returns true if anything moved.
  bool _followCalendar() {
    final current = currentMonthOf(DateTime.now());
    if (current == _calendarMonth) return false;
    _month = followMonth(viewed: _month, lastCurrent: _calendarMonth, current: current);
    _calendarMonth = current;
    return true;
  }
  late MonthSummary month = summarize(ledger, _month);
  late Insights insights = buildInsights(ledger, _month);
  List<Recurring> recurring = [];

  // Splitwise (offline: payments are handed to the Splitwise app)
  Map<String, SplitRecord> splitRecords = {};
  Set<String> splitSkipped = {};
  SplitSettings splitSettings = const SplitSettings();

  /// Shows the split card inside the app (when it's open at payment time).
  void Function(Enriched payment)? onSplitSuggestion;

  /// Splits sent this calendar month.
  ({int totalMinor, int count}) get splitThisMonth {
    final now = DateTime.now();
    final mine = splitRecords.values.where((r) => r.at.year == now.year && r.at.month == now.month);
    return (totalMinor: mine.fold(0, (sum, r) => sum + r.amountMinor), count: mine.length);
  }
  Set<String> get _splitHandled => {...splitRecords.keys, ...splitSkipped};

  /// Last 30 days of payments not yet split or skipped.
  List<Enriched> get splitTodo => splitCandidates(
        ledger.items,
        handled: _splitHandled,
        settings: splitSettings,
        since: DateTime.now().subtract(const Duration(days: 30)),
      );

  Appearance appearance = const Appearance();

  /// Wallpaper colour from the system, when available.
  Color? wallpaper;

  /// This phone looks low-end (low RAM).
  bool lowEndDevice = false;

  /// Animations and blurred shadows off.
  bool get lite => switch (appearance.effects) {
        Effects.auto => lowEndDevice,
        Effects.reduced => true,
        Effects.full => false,
      };

  /// The seed the theme uses right now (null = brand palette).
  Color? get themeSeed => appearance.wallpaperColors ? wallpaper : null;

  bool loading = true;
  bool scanning = false;
  bool smsGranted = false;
  bool notificationsGranted = false;

  /// May post notifications (Android 13+ asks; the split offer needs it).
  bool postNotificationsGranted = true;
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
    await _readStore();
    lowEndDevice = await Perf.isLowEndDevice();
    Perf.lite = lite;
    wallpaper = await wallpaperSeed();
    notifyListeners();
    await _store.migrateSplitwise();
    await _loadSplitState();
    // Bank SMS arriving while we're running come straight here.
    SmsSource.listenLive(_onLiveSms);
    lastScan = await _store.readLastScan();
    await _recompute();
    await _applyPendingSplitActions();
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

  /// Loads the saved facts and choices (on start, and after a restore).
  Future<void> _readStore() async {
    // Drop payments made by the adb test hook (TestSmsReceiver uses this id),
    // and re-parse stored payments once whenever the parser has improved.
    _txns = (await _store.readTxns()).where((t) => t.vpa != testHookVpa).toList();
    if (await _store.readParserVersion() != parserVersion) {
      _txns = _txns.length > _offThreadAbove ? await compute(reparseAll, _txns) : reparseAll(_txns);
      await _store.writeTxns(_txns);
      await _store.writeParserVersion(parserVersion);
    }
    rules = await _store.readRules();
    autoRules = await _store.readAutoRules();
    budgets = await _store.readBudgets();
    _sentAlerts = await _store.readSentAlerts();
    _dismissedNudges = await _store.readDismissedNudges();
    profile = await _store.readProfile();
    appearance = await _store.readAppearance();
  }

  /// Above this many payments, deriving runs on a background isolate so the
  /// UI never stalls on slower phones.
  static const _offThreadAbove = 400;
  int _generation = 0;

  Future<void> _recompute() async {
    _followCalendar();
    final generation = ++_generation;
    final input = DeriveInput(
      txns: List.of(_txns),
      profile: profile,
      rules: rules,
      autoRules: autoRules,
      month: _month,
      now: DateTime.now(),
    );
    final d = _txns.length > _offThreadAbove ? await compute(derive, input) : derive(input);
    if (generation != _generation) return; // a newer change already won
    ledger = d.ledger;
    PayeeLogos.instance.prefetch(ledger.items.take(150)); // logos of what's on screen first
    month = d.month;
    insights = d.insights;
    recurring = d.recurring;
  }

  void _recomputeMonth() {
    month = summarize(ledger, _month);
    insights = buildInsights(ledger, _month);
  }

  Future<void> _save() async {
    await _recompute();
    notifyListeners();
    await _store.writeTxns(_txns);
    await _checkBudgets();
    await _pushWidget();
  }

  Future<void> _pushWidget() => WidgetBridge.push(widgetPeriods(ledger, budgets), last: lastPayment(ledger));

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
    await SmsSource.upgradeToLive();
    smsGranted = await SmsSource.hasPermission();
    notificationsGranted = await NotificationSource.hasPermission();
    postNotificationsGranted = !isAndroid || await Permission.notification.isGranted;
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

  /// A bank SMS just arrived (via the native receiver).
  void _onLiveSms(RawMessage message) {
    final result = ingest(_txns, [message]);
    _txns = result.txns;
    unawaited(_save().then((_) => _suggestSplit(result.addedIds)));
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

  /// Counts a payment in the month after the one it was paid in (e.g. a bill
  /// paid on salary day). Only ever one step; [moveBack] undoes it.
  Future<void> moveToNextMonth(String txnId) => moveManyToNextMonth([txnId]);

  /// Clears the move: it counts in the month it was paid again.
  Future<void> moveBack(String txnId) => moveManyBack([txnId]);

  Future<void> moveManyToNextMonth(Iterable<String> ids) =>
      _setCountMonth(ids, (t) => t.copyWith(countMonth: t.nextMonth));

  Future<void> moveManyBack(Iterable<String> ids) =>
      _setCountMonth(ids, (t) => t.copyWith(clearCountMonth: true));

  Future<void> _setCountMonth(Iterable<String> ids, Txn Function(Txn t) change) async {
    final wanted = ids.toSet();
    var changed = false;
    for (var i = 0; i < _txns.length; i++) {
      if (!wanted.contains(_txns[i].id)) continue;
      _txns[i] = change(_txns[i]);
      changed = true;
    }
    if (changed) await _save();
  }

  /// The "count last month's end-of-month payments in this month?" card.
  MonthNudge? get monthNudge => isCurrentMonth ? buildMonthNudge(ledger, _dismissedNudges) : null;

  /// "Not now": hides the card for that month.
  Future<void> dismissNudge(MonthNudge nudge) async {
    _dismissedNudges = {..._dismissedNudges, nudge.key};
    notifyListeners();
    await _store.writeDismissedNudges(_dismissedNudges);
  }

  Future<void> markReviewed(Txn txn) => _update(txn.id, (t) => t.copyWith(reviewed: true));

  /// Adds a tag. [forPayee] (the default) remembers it for every payment to
  /// the same payee, past and future; off, it stays on this payment only.
  Future<void> addTag(Txn txn, String tag, {bool forPayee = true}) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;
    final key = payeeKey(txn);
    if (forPayee && key.isNotEmpty) {
      final rule = rules[key] ?? PayeeRule(key: key, label: _bankName(txn));
      if (rule.tags.contains(clean)) return;
      await _putRule(rule.copyWith(tags: [...rule.tags, clean]));
      return;
    }
    await _update(txn.id, (t) => t.copyWith(userTags: {...t.userTags, clean}.toList()));
  }

  /// Removes a tag wherever it comes from: if it's on the payee rule it goes
  /// from every payment to that payee.
  Future<void> removeTag(Txn txn, String tag) async {
    final rule = ruleFor(txn);
    final onRule = rule != null && rule.tags.contains(tag);
    final i = _txns.indexWhere((t) => t.id == txn.id);
    if (i != -1 && _txns[i].userTags.contains(tag)) {
      _txns[i] = _txns[i].copyWith(userTags: _txns[i].userTags.where((x) => x != tag).toList());
    }
    if (onRule) {
      await _putRule(rule.copyWith(tags: rule.tags.where((x) => x != tag).toList()));
    } else {
      await _save();
    }
  }

  /// Names this payee for every payment to it, past and future (and in
  /// Splitwise). Null or blank — or the bank's own name — goes back to the
  /// bank's name. Payments with no payee to key on can't be renamed.
  Future<void> renamePayee(Enriched e, String? name) async {
    final key = payeeKey(e.txn);
    if (key.isEmpty) return;
    final clean = name?.trim() ?? '';
    final back = clean.isEmpty || clean == e.originalPayee;
    final rule = rules[key] ?? PayeeRule(key: key, label: e.originalPayee);
    await _putRule(back ? rule.copyWith(clearName: true) : rule.copyWith(name: clean));
  }

  /// Whether [renamePayee] and payee-wide tags work for this payment.
  bool canRename(Txn txn) => payeeKey(txn).isNotEmpty;

  /// Names the user has given to payees, for suggestions.
  List<String> get knownNames =>
      ({for (final r in rules.values) if (r.name != null) r.name!}.toList()..sort());

  /// Every tag the user has used (payee-wide or per payment), most used first.
  List<String> get knownTags {
    final counts = <String, int>{};
    for (final r in rules.values) {
      for (final tag in r.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    for (final t in _txns) {
      for (final tag in t.userTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  static String _bankName(Txn t) => enrich([t]).items.single.originalPayee;

  /// Stores [rule] (dropping it if nothing is left in it), then recomputes.
  Future<void> _putRule(PayeeRule rule) async {
    rules = {...rules};
    if (rule.isEmpty) {
      rules.remove(rule.key);
    } else {
      rules[rule.key] = rule;
    }
    await _store.writeRules(rules);
    await _save();
  }

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
  /// to the same payee, now and in future. Keeps the payee's name and tags.
  Future<void> rememberFor(Enriched e) async {
    final key = payeeKey(e.txn);
    if (key.isEmpty) return;
    final rule = rules[key] ?? PayeeRule(key: key, label: e.originalPayee);
    await _putRule(PayeeRule(
      key: key,
      label: rule.label,
      category: e.category == Category.income ? null : e.category,
      kind: e.kind == TxnKind.expense || e.kind == TxnKind.income ? null : e.kind,
      name: rule.name,
      tags: rule.tags,
    ));
  }

  /// Turns "Same for all" off: forgets the payee's category and type but
  /// keeps its name and tags.
  Future<void> forgetClassification(String key) async {
    final rule = rules[key];
    if (rule == null) return;
    await _putRule(rule.copyWith(clearCategory: true, clearKind: true));
  }

  /// Deletes everything remembered about a payee (name, tags, category, type).
  Future<void> forget(String key) async {
    rules = {...rules}..remove(key);
    await _store.writeRules(rules);
    await _save();
  }

  /// Saves an edited rule as is (Rules screen, undo of a delete).
  Future<void> saveRule(PayeeRule rule) => _putRule(rule);

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
    splitRecords = {};
    splitSkipped = {};
    splitSettings = const SplitSettings();
    profile = const Profile();
    lastScan = null;
    await _save();
  }

  // ── Backup ─────────────────────────────────────────────────────────

  /// Asks where to save, then writes a backup of everything. False if the
  /// user backed out of the picker.
  Future<bool> exportBackup() async {
    final now = DateTime.now();
    final json = Backup.encode(await _store.readBackupData(), version: await BackupBridge.appVersion(), now: now);
    return BackupBridge.save(Backup.fileName(now), json);
  }

  /// Replaces everything on this phone with [backup] and reloads it all.
  Future<void> restoreBackup(Backup backup) async {
    await _store.writeBackupData(backup.data);
    await _readStore();
    await _loadSplitState();
    lastScan = await _store.readLastScan();
    Perf.lite = lite;
    await _save();
  }

  Future<void> _onResume() async {
    await _applyPendingSplitActions();
    if (_followCalendar()) {
      await _recompute();
      notifyListeners();
      await _pushWidget();
    }
    await _loadSplitState();
    await refreshPermissions();
    await scanSms();
  }

  // ── Splitwise ──────────────────────────────────────────────────────

  Future<void> _loadSplitState() async {
    splitRecords = await _store.readSplitRecords();
    splitSkipped = await _store.readSplitSkipped();
    splitSettings = await _store.readSplitSettings();
  }

  /// Applies what was pressed on split notifications since last time (queued
  /// natively): Split records it, Skip hides it, Not expense marks it.
  Future<void> _applyPendingSplitActions() async {
    final actions = await SplitwiseBridge.takePendingActions();
    if (actions.isEmpty) return;
    final out = applySplitActions(
      actions,
      records: splitRecords,
      skipped: splitSkipped,
      lookup: find,
      groupName: splitSettings.groupName ?? 'Splitwise',
    );
    if (!out.changed) return;
    splitRecords = out.records;
    splitSkipped = out.skipped;
    await _store.writeSplitRecords(splitRecords);
    await _store.writeSplitSkipped(splitSkipped);
    if (out.notExpense.isEmpty) {
      notifyListeners();
      return;
    }
    for (var i = 0; i < _txns.length; i++) {
      if (out.notExpense.contains(_txns[i].id)) {
        _txns[i] = _txns[i].copyWith(kindOverride: TxnKind.notExpense, reviewed: true);
      }
    }
    await _save();
  }

  Future<void> setAppearance(Appearance next) async {
    appearance = next;
    Perf.lite = lite;
    await _store.writeAppearance(next);
    notifyListeners();
  }

  Future<void> setSplitSettings(SplitSettings next) async {
    splitSettings = next;
    await _store.writeSplitSettings(next);
    notifyListeners();
  }

  Future<void> requestPostNotifications() async {
    await Notifier.requestPermission();
    await refreshPermissions();
  }

  /// Opens Splitwise's Add expense screen with this payment filled in, and
  /// remembers it as handed over.
  Future<void> openInSplitwise(String txnId) async {
    final e = find(txnId);
    if (e == null) return;
    splitRecords = await _store.addSplitRecord(SplitRecord(
      txnId: txnId,
      label: splitSettings.groupName ?? 'Splitwise',
      amountMinor: e.txn.amountMinor,
      description: e.payee,
      at: DateTime.now(),
    ));
    if (splitSkipped.remove(txnId)) await _store.writeSplitSkipped(splitSkipped);
    notifyListeners();
    await SplitwiseBridge.open(amountMinor: e.txn.amountMinor, payee: e.payee, groupId: splitSettings.groupId);
  }

  /// "Not splitting this one": it leaves the To split list.
  Future<void> skipSplit(String txnId) async {
    splitSkipped = {...splitSkipped, txnId};
    await _store.writeSplitSkipped(splitSkipped);
    notifyListeners();
  }

  /// Marks the payment "Not an expense" (like the review card does) and
  /// takes it off the split list.
  Future<void> markNotExpense(String txnId) async {
    splitSkipped = {...splitSkipped, txnId};
    await _store.writeSplitSkipped(splitSkipped);
    await _update(txnId, (t) => t.copyWith(kindOverride: TxnKind.notExpense, reviewed: true));
  }

  /// Back to To split: forgets that it was opened in Splitwise (or skipped).
  Future<void> undoSplit(String txnId) async {
    splitRecords = {...splitRecords}..remove(txnId);
    splitSkipped = {...splitSkipped}..remove(txnId);
    await _store.writeSplitRecords(splitRecords);
    await _store.writeSplitSkipped(splitSkipped);
    notifyListeners();
  }

  /// Right after new payments: offer to split the freshest one.
  Future<void> _suggestSplit(List<String> addedIds) async {
    if (addedIds.isEmpty) return;
    final ids = addedIds.toSet();
    final pick = notifyFor(
      ledger.items.where((e) => ids.contains(e.txn.id)),
      handled: _splitHandled,
      settings: splitSettings,
      now: DateTime.now(),
    );
    if (pick == null) return;
    final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foreground && onSplitSuggestion != null) {
      onSplitSuggestion!(pick);
    } else {
      await SplitwiseBridge.showNotification(
        txnId: pick.txn.id,
        amountMinor: pick.txn.amountMinor,
        payee: pick.payee,
        groupId: splitSettings.groupId,
      );
    }
  }

  /// Posts the split notification for the latest payment, to try it out.
  Future<bool> sendTestSplitNotification() async {
    final e = splitTodo.firstOrNull ?? ledger.items.where((e) => e.countsAsSpend).firstOrNull;
    if (e == null) return false;
    await SplitwiseBridge.showNotification(
      txnId: e.txn.id,
      amountMinor: e.txn.amountMinor,
      payee: e.payee,
      groupId: splitSettings.groupId,
    );
    return true;
  }

  /// Opens Splitwise with "₹1 · Test", to check the hand-off works.
  Future<bool> tryOpenSplitwise() =>
      SplitwiseBridge.open(amountMinor: 100, payee: 'Test', groupId: splitSettings.groupId);

  @override
  void dispose() {
    _notifications.stop();
    _lifecycle.dispose();
    super.dispose();
  }
}

/// UPI id used only by on-device tests via TestSmsReceiver (see SmsReceiver.kt).
const testHookVpa = 'autospend.test@ybl';

/// Makes the [AppController] available to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

DateTime currentMonthOf(DateTime now) => DateTime(now.year, now.month);

/// Which month to show after the calendar moved from [lastCurrent] to
/// [current]: follow it if the user was on the then-current month, otherwise
/// keep the past month they chose.
DateTime followMonth({required DateTime viewed, required DateTime lastCurrent, required DateTime current}) =>
    viewed == lastCurrent ? current : viewed;
