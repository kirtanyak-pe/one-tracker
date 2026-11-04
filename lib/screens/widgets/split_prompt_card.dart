import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../engine/enrich.dart';
import '../../money.dart';
import '../../ui/components.dart';
import '../../ui/format.dart';
import '../../ui/payee_logo.dart';
import '../../ui/tokens.dart';
import 'prompt_card_parts.dart';

/// "Split ₹450 at Swiggy?" — the in-app split prompt. No picker: the
/// payment goes to Splitwise pre-filled and the split is set up there.
class SplitPromptCard extends StatefulWidget {
  const SplitPromptCard({
    super.key,
    required this.txnId,
    required this.payee,
    required this.amountMinor,
    required this.at,
    this.currency = 'INR',
    this.onDone,
    this.onSplit,
    this.onSkip,
    this.payment,
  });

  /// From a payment: `SplitPromptCard.of(payment, currency: ...)`.
  SplitPromptCard.of(Enriched e, {super.key, this.currency = 'INR', this.onDone, this.onSplit, this.onSkip})
    : txnId = e.txn.id,
      payee = e.payee,
      payment = e,
      amountMinor = e.txn.amountMinor,
      at = e.txn.at;

  final String txnId;
  final String payee;

  /// The payment, when known: its payee logo leads the header.
  final Enriched? payment;
  final int amountMinor;
  final DateTime at;
  final String currency;

  /// Called after either action (e.g. close the sheet).
  final VoidCallback? onDone;

  /// Override the controller calls (tests). Default: openInSplitwise/skipSplit.
  final Future<void> Function()? onSplit;
  final Future<void> Function()? onSkip;

  @override
  State<SplitPromptCard> createState() => _SplitPromptCardState();
}

class _SplitPromptCardState extends State<SplitPromptCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onDone?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return PromptSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromptHeader(
            icon: Icons.call_split,
            leading: widget.payment == null ? null : PayeeAvatar(widget.payment!, size: 44),
            title: 'Split at ${widget.payee}?',
            amount: formatMoney(widget.amountMinor, widget.currency),
          ),
          const SizedBox(height: Space.sm),
          Text(
            '${friendlyTime(widget.at)} · Opens Splitwise with this filled in',
            style: text.bodySmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: PromptButtons.secondary(t),
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onSkip ?? () => AppScope.of(context).skipSplit(widget.txnId)),
                  child: const OneLineLabel('Skip'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                flex: 3,
                child: FilledButton(
                  style: PromptButtons.primary(t),
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onSplit ?? () => AppScope.of(context).openInSplitwise(widget.txnId)),
                  child: const OneLineLabel('Split in Splitwise'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the prompt as a bottom sheet over the app (a payment just arrived).
Future<void> showSplitPromptSheet(BuildContext context, Enriched payment) {
  final app = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: SplitPromptCard.of(
          payment,
          currency: appCurrency,
          onSplit: () => app.openInSplitwise(payment.txn.id),
          onSkip: () => app.skipSplit(payment.txn.id),
          onDone: () => Navigator.pop(sheet),
        ),
      ),
    ),
  );
}
