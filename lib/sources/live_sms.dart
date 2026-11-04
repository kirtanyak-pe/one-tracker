import '../engine/enrich.dart';
import '../engine/ingest.dart';
import '../engine/insights.dart';
import '../engine/summary.dart';
import '../engine/widget_data.dart';
import '../money.dart';
import '../split/suggest.dart';
import '../storage/app_store.dart';
import 'notifier.dart';
import 'sms_source.dart';
import 'splitwise_bridge.dart';
import 'widget_bridge.dart';

/// A bank SMS arrived while One Tracker wasn't running (see SmsReceiver.kt,
/// `smsMain`). Saves it, refreshes the widget, checks budgets, and posts the
/// split notification — all from storage, since there's no app state in memory.
Future<void> handleBackgroundSms({
  required String sender,
  required String body,
  required DateTime at,
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
  await WidgetBridge.push(widgetPeriods(ledger, budgets), last: lastPayment(ledger));

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

  // The split notification.
  final ids = result.addedIds.toSet();
  final settings = await store.readSplitSettings();
  final pick = notifyFor(
    ledger.items.where((e) => ids.contains(e.txn.id)),
    handled: {...(await store.readSplitRecords()).keys, ...await store.readSplitSkipped()},
    settings: settings,
    now: DateTime.now(),
  );
  if (pick == null) return;
  await SplitwiseBridge.showNotification(
    txnId: pick.txn.id,
    amountMinor: pick.txn.amountMinor,
    payee: pick.payee,
    groupId: settings.groupId,
  );
}
