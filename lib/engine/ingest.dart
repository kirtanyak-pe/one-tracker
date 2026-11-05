import '../model/transaction.dart';
import 'parser.dart';

/// A bank SMS or payment-app notification, before parsing.
class RawMessage {
  const RawMessage({
    required this.source,
    required this.sourceId,
    required this.sender,
    required this.body,
    required this.at,
  });

  final Source source;
  final String sourceId;
  final String sender;
  final String body;
  final DateTime at;
}

/// Parses [messages] into transactions and merges them into [existing].
/// The same payment often arrives twice (UPI app notification + bank SMS);
/// those are merged into one, keeping the richer facts.
({List<Txn> txns, int added, List<String> addedIds}) ingest(List<Txn> existing, Iterable<RawMessage> messages) {
  final txns = [...existing];
  final seen = {
    for (final t in txns)
      if (t.sourceId != null) '${t.source.name}:${t.sourceId}',
  };
  // Indexes instead of scanning every stored payment per message — keeps a
  // big backfill linear on slow phones.
  final byAmount = <String, List<int>>{}; // "debit:45000" → positions in txns
  final byText = <String, List<int>>{}; // raw body → positions
  void index(int i) {
    final t = txns[i];
    byAmount.putIfAbsent('${t.direction.name}:${t.amountMinor}', () => []).add(i);
    final raw = t.raw?.trim();
    if (raw != null) byText.putIfAbsent(raw, () => []).add(i);
  }

  for (var i = 0; i < txns.length; i++) {
    index(i);
  }
  final addedIds = <String>[];

  for (final m in messages) {
    if (!seen.add('${m.source.name}:${m.sourceId}')) continue;
    if (m.source == Source.notification && !notificationMayBePayment(m.sender, m.body)) continue;
    final p = parseMessage(m.body);
    if (p == null) continue;
    // Same text minutes apart is the same SMS seen twice (e.g. stored under
    // an older id scheme).
    final body = m.body.trim();
    if ((byText[body] ?? const []).any((i) => txns[i].at.difference(m.at).abs() <= const Duration(minutes: 10))) {
      continue;
    }

    final twinIndex =
        (byAmount['${p.direction.name}:${p.amountMinor}'] ?? const <int>[]).where((i) {
          final t = txns[i];
          return t.at.difference(m.at).abs() <= const Duration(minutes: 5) &&
              ((p.ref != null && p.ref == t.ref) || t.source != m.source);
        }).firstOrNull ??
        -1;
    if (twinIndex != -1) {
      final twin = txns[twinIndex];
      txns[twinIndex] = twin.copyWith(
        counterparty: twin.counterparty ?? p.counterparty,
        vpa: twin.vpa ?? p.vpa,
        account: twin.account ?? p.account,
        otherAccount: twin.otherAccount ?? p.otherAccount,
        ref: twin.ref ?? p.ref,
        kindHint: twin.kindHint ?? p.kindHint,
      );
      continue;
    }

    txns.add(
      Txn(
        id: '${m.source.name}-${m.sourceId}',
        source: m.source,
        sourceId: m.sourceId,
        direction: p.direction,
        amountMinor: p.amountMinor,
        at: m.at,
        counterparty: p.counterparty,
        vpa: p.vpa,
        account: p.account,
        otherAccount: p.otherAccount,
        ref: p.ref,
        kindHint: p.kindHint,
        raw: m.body,
        sender: m.sender,
      ),
    );
    index(txns.length - 1);
    addedIds.add(txns.last.id);
  }
  return (txns: txns, added: addedIds.length, addedIds: addedIds);
}

/// A stored notification payment that today's chat-app rule rejects.
bool isRejectedNotification(Txn t) =>
    t.source == Source.notification && !notificationMayBePayment(t.sender, t.raw ?? '');

/// The user changed something on this payment, so it is never dropped.
bool isUserEdited(Txn t) =>
    t.categoryOverride != null || t.kindOverride != null || t.userTags.isNotEmpty || t.reviewed || t.countMonth != null;

/// Re-reads stored messages with the current parser, so parser fixes reach
/// transactions saved before them. Your edits (category, kind, tags,
/// reviewed) are kept; amount, direction and time never change.
Txn reparse(Txn t) {
  if (isRejectedNotification(t) && !isUserEdited(t)) return t;
  final raw = t.raw;
  if (raw == null) return t;
  final p = parseMessage(raw);
  if (p == null || p.amountMinor != t.amountMinor || p.direction != t.direction) return t;
  return Txn(
    id: t.id,
    source: t.source,
    sourceId: t.sourceId,
    direction: t.direction,
    amountMinor: t.amountMinor,
    at: t.at,
    // Merged notification twins may have filled these; keep them if the
    // new parse finds nothing.
    counterparty: p.counterparty ?? (t.counterparty != null && isUsableName(t.counterparty!) ? t.counterparty : null),
    vpa: p.vpa ?? t.vpa,
    account: p.account ?? t.account,
    otherAccount: p.otherAccount ?? t.otherAccount,
    ref: p.ref ?? t.ref,
    kindHint: p.kindHint ?? t.kindHint,
    raw: raw,
    sender: t.sender,
    categoryOverride: t.categoryOverride,
    kindOverride: t.kindOverride,
    userTags: t.userTags,
    reviewed: t.reviewed,
    countMonth: t.countMonth,
  );
}

/// [reparse] over a whole list, also dropping stored chat-app notifications
/// that were wrongly counted as payments (unless the user edited them).
List<Txn> reparseAll(List<Txn> txns) => [
  for (final t in txns)
    if (!isRejectedNotification(t) || isUserEdited(t)) reparse(t),
];
