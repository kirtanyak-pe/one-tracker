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
({List<Txn> txns, int added}) ingest(List<Txn> existing, Iterable<RawMessage> messages) {
  final txns = [...existing];
  final seen = {for (final t in txns) if (t.sourceId != null) '${t.source.name}:${t.sourceId}'};
  var added = 0;

  for (final m in messages) {
    if (!seen.add('${m.source.name}:${m.sourceId}')) continue;
    final p = parseMessage(m.body);
    if (p == null) continue;

    final twinIndex = txns.indexWhere((t) =>
        t.direction == p.direction &&
        t.amountMinor == p.amountMinor &&
        t.at.difference(m.at).abs() <= const Duration(minutes: 5) &&
        ((p.ref != null && p.ref == t.ref) || t.source != m.source));
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

    txns.add(Txn(
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
    ));
    added++;
  }
  return (txns: txns, added: added);
}
