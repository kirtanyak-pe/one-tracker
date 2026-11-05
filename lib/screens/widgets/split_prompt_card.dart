import 'package:flutter/widgets.dart';

import '../../app_controller.dart';
import '../../engine/enrich.dart';
import '../../money.dart';
import '../../ui/format.dart';
import '../../ui/payee_logo.dart';

import 'package:onyx/onyx.dart';

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
    final t = context.colors;
    final text = context.type;
    return PromptSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromptHeader(
            icon: LucideIcons.split,
            leading: widget.payment == null ? null : PayeeAvatar(widget.payment!, size: 44),
            title: 'Split at ${widget.payee}?',
            amount: formatMoney(widget.amountMinor, widget.currency),
          ),
          const SizedBox(height: OSpace.sm),
          Text(
            '${friendlyTime(widget.at)} · Opens Splitwise with this filled in',
            style: text.small.copyWith(color: promptMuted(t)),
          ),
          const SizedBox(height: OSpace.lg),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OButton(
                  label: 'Skip',
                  variant: OButtonVariant.inverseSoft,
                  size: OButtonSize.lg,
                  expand: true,
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onSkip ?? () => AppScope.of(context).skipSplit(widget.txnId)),
                ),
              ),
              const SizedBox(width: OSpace.sm),
              Expanded(
                flex: 3,
                child: OButton(
                  label: 'Split in Splitwise',
                  variant: OButtonVariant.inverse,
                  size: OButtonSize.lg,
                  expand: true,
                  onPressed: _busy
                      ? null
                      : () => _run(widget.onSplit ?? () => AppScope.of(context).openInSplitwise(widget.txnId)),
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
  return showOSheet<void>(
    context,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(OSpace.md, 0, OSpace.md, OSpace.md),
      child: SplitPromptCard.of(
        payment,
        currency: appCurrency,
        onSplit: () => app.openInSplitwise(payment.txn.id),
        onSkip: () => app.skipSplit(payment.txn.id),
        onDone: () => Navigator.pop(sheet),
      ),
    ),
  );
}
