import '../engine/enrich.dart';
import '../engine/ingest.dart';
import '../engine/insights.dart';
import '../engine/summary.dart';
import '../engine/widget_data.dart';
import '../money.dart';
import '../split/split_models.dart';
import '../split/split_overlay.dart';
import '../split/suggest.dart';
import '../storage/app_store.dart';
import 'notifier.dart';
import 'sms_source.dart';
import 'widget_bridge.dart';

/// A bank SMS arrived while Auto Spend wasn't running (see SmsReceiver.kt,
/// `smsMain`). Saves it, refreshes the widget, checks budgets, and pops the
/// split card — all from storage, since there's no app state in memory.
Future<void> handleBackgroundSms({
  required String sender,
  required String body,
  required DateTime at,
  required double pixelRatio,
}) async {
  final store = AppStore();
  final result = ingest(await store.readTxns(), [SmsSource.liveMessage(sender: sender, body: body, at: at)]);
  if (result.added == 0) return;
  await store.writeTxns(result.txns);

  final ledger = enrich(
    result.txns,
    profile: await store.readProfile(),
    rules: await store.readRules(),
    autoRules: await store.readAutoRules(),
  );
  final budgets = await store.readBudgets();
  await WidgetBridge.push(widgetPeriods(ledger, budgets));

  // Budget alerts, once per threshold per month.
  if (!budgets.isEmpty) {
    final sent = await store.readSentAlerts();
    final now = DateTime.now();
    final alerts = budgetAlerts(
      summarize(ledger, DateTime(now.year, now.month)),
      budgets,
      sent,
      money: (m) => formatMoney(m, appCurrency),
    );
    for (final a in alerts) {
      await Notifier.show(a.key.hashCode & 0x7fffffff, a.title, a.body);
      sent.add(a.key);
    }
    if (alerts.isNotEmpty) await store.writeSentAlerts(sent);
  }

  // The split pop-up.
  final ids = result.addedIds.toSet();
  final pick = popupFor(
    ledger.items.where((e) => ids.contains(e.txn.id)),
    handled: {...(await store.readSplitRecords()).keys, ...await store.readSplitSkipped()},
    settings: await store.readSplitSettings(),
    now: DateTime.now(),
  );
  if (pick == null || !await SplitOverlay.hasPermission()) return;
  await SplitOverlay.show(
    SplitPrompt(txnId: pick.txn.id, amountMinor: pick.txn.amountMinor, payee: pick.payee, at: pick.txn.at),
    store,
    expanded: await store.readSplitTarget() == null,
    pixelRatio: pixelRatio,
  );
}
