import 'package:flutter/widgets.dart';

import 'detection/detected_payment.dart';
import 'detection/payment_parser.dart';
import 'detection/payment_watcher.dart';
import 'history/split_record.dart';
import 'overlay/split_bubble.dart';
import 'splitwise/models.dart';
import 'splitwise/split_math.dart';
import 'splitwise/splitwise_api.dart';
import 'storage/app_store.dart';

/// App-wide state: Splitwise connection, detected payments, permissions.
class AppController extends ChangeNotifier {
  AppController(this._store);

  final AppStore _store;
  late final _watcher = PaymentWatcher(_onNotificationText);
  late final _lifecycle = AppLifecycleListener(onResume: _onResume);

  SplitwiseApi _api = DemoSplitwiseApi();
  CurrentUser? currentUser;
  List<SwGroup> groups = [];
  List<SwUser> friends = [];
  List<DetectedPayment> inbox = [];
  List<SplitRecord> history = [];
  String currency = 'INR';
  bool loading = true;
  String? error;
  bool detectionGranted = false;
  bool bubbleGranted = false;

  bool get isDemo => _api.isDemo;

  /// Shows the quick-split card in-app when the floating bubble can't be used.
  void Function(DetectedPayment payment)? onBubbleFallback;

  Future<void> init() async {
    _lifecycle; // start listening for resume
    final key = await _store.readApiKey();
    if (key != null) _api = HttpSplitwiseApi(key);
    inbox = await _store.readInbox();
    history = await _store.readHistory();
    currency = await _store.readCurrency();
    await refreshPermissions();
    await refreshSplitwise();
  }

  Future<void> refreshSplitwise() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getCurrentUser(),
        _api.getGroups(),
        _api.getFriends(),
      ]);
      currentUser = results[0] as CurrentUser;
      groups = results[1] as List<SwGroup>;
      friends = results[2] as List<SwUser>;
      currency = currentUser!.defaultCurrency;
      await _store.cacheGroups(groups);
      await _store.writeCurrency(currency);
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Validates the key against Splitwise before saving it.
  Future<void> connect(String apiKey) async {
    final api = HttpSplitwiseApi(apiKey.trim());
    await api.getCurrentUser();
    await _store.writeApiKey(apiKey.trim());
    _api = api;
    await refreshSplitwise();
  }

  Future<void> disconnect() async {
    await _store.clearApiKey();
    _api = DemoSplitwiseApi();
    await refreshSplitwise();
  }

  Future<void> refreshPermissions() async {
    detectionGranted = await PaymentWatcher.hasPermission();
    bubbleGranted = await SplitBubble.hasPermission();
    if (detectionGranted) _watcher.start();
    notifyListeners();
  }

  Future<void> requestDetection() async {
    await PaymentWatcher.requestPermission();
    await refreshPermissions();
  }

  Future<void> requestBubble() async {
    await SplitBubble.requestPermission();
    await refreshPermissions();
  }

  void _onNotificationText(String packageName, String text) {
    final parsed = parsePayment(text);
    if (parsed == null) return;
    _addPayment(parsed, packageName);
  }

  static const _samples = [
    ParsedPayment(45000, 'Swiggy'),
    ParsedPayment(28640, 'Uber'),
    ParsedPayment(112000, 'Blinkit'),
    ParsedPayment(69000, 'Third Wave Coffee'),
  ];
  var _sampleIndex = 0;

  /// Pretends a payment just happened — for trying the flow.
  void simulatePayment() => _addPayment(
        _samples[_sampleIndex++ % _samples.length],
        'demo',
        allowDuplicate: true,
      );

  Future<void> _addPayment(
    ParsedPayment parsed,
    String sourceApp, {
    bool allowDuplicate = false,
  }) async {
    final now = DateTime.now();
    if (!allowDuplicate && isDuplicate(parsed, now, inbox)) return;
    final payment = DetectedPayment(
      id: now.microsecondsSinceEpoch.toString(),
      amountMinor: parsed.amountMinor,
      merchant: parsed.merchant,
      sourceApp: sourceApp,
      detectedAt: now,
    );
    inbox = [payment, ...inbox];
    await _store.writeInbox(inbox);
    notifyListeners();

    if (bubbleGranted) {
      await SplitBubble.show(payment, _store);
    } else {
      onBubbleFallback?.call(payment);
    }
  }

  Future<void> dismiss(DetectedPayment payment) async {
    inbox = inbox.where((p) => p.id != payment.id).toList();
    await _store.writeInbox(inbox);
    notifyListeners();
  }

  Future<void> splitWithGroup({
    required SwGroup group,
    required int amountMinor,
    required String description,
    DetectedPayment? from,
  }) async {
    await _api.createGroupExpense(
      groupId: group.id,
      costMinor: amountMinor,
      description: description,
      currency: currency,
    );
    await _recordSplit(amountMinor, description, group.name, from);
  }

  Future<void> splitWithFriends({
    required List<SwUser> people,
    required int amountMinor,
    required String description,
    DetectedPayment? from,
  }) async {
    final me = currentUser;
    if (me == null) throw const SplitwiseException('Not connected to Splitwise yet.');
    await _api.createSharedExpense(
      shares: equalSplit(
        payerId: me.user.id,
        participantIds: people.map((p) => p.id).toList(),
        totalMinor: amountMinor,
      ),
      costMinor: amountMinor,
      description: description,
      currency: currency,
    );
    await _recordSplit(amountMinor, description, people.map((p) => p.firstName).join(', '), from);
  }

  Future<void> _recordSplit(
    int amountMinor,
    String description,
    String withWhom,
    DetectedPayment? from,
  ) async {
    history = await _store.addHistory(SplitRecord(
      amountMinor: amountMinor,
      description: description,
      withWhom: withWhom,
      at: DateTime.now(),
    ));
    if (from != null) {
      await dismiss(from);
    } else {
      notifyListeners();
    }
  }

  /// Split this week, and what share of this week's payments got split.
  ({int totalMinor, int count, double share}) get weekSummary {
    final since = startOfWeek(DateTime.now());
    final split = history.where((r) => !r.at.isBefore(since)).toList();
    final waiting = inbox.where((p) => !p.detectedAt.isBefore(since)).length;
    final all = split.length + waiting;
    return (
      totalMinor: split.fold(0, (sum, r) => sum + r.amountMinor),
      count: split.length,
      share: all == 0 ? 0 : split.length / all,
    );
  }

  int get waitingMinor => inbox.fold(0, (sum, p) => sum + p.amountMinor);

  /// The bubble may have split or skipped things while we were away, and the
  /// user may have just granted a permission in system settings.
  Future<void> _onResume() async {
    inbox = await _store.readInbox();
    history = await _store.readHistory();
    await refreshPermissions();
  }

  @override
  void dispose() {
    _watcher.stop();
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
