import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

/// Shared pieces of the "decide this payment" cards (review, split, month
/// nudge), so they read as one family: ink card, header row, one muted line,
/// actions.

/// The card surface: an ink card, light text on dark, no border or shadow.
class PromptSurface extends StatelessWidget {
  const PromptSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    return OCard(color: t.ink, border: false, padding: const EdgeInsets.all(OSpace.lg), child: child);
  }
}

/// Muted text on an ink card.
Color promptMuted(OColors t) => t.onInk.withValues(alpha: 0.7);

/// Icon in a soft circle · title and muted subtitle · optional amount on the right.
class PromptHeader extends StatelessWidget {
  const PromptHeader({super.key, required this.icon, required this.title, this.amount, this.subtitle, this.leading});

  final IconData icon;

  /// Replaces the icon circle (e.g. a payee's logo); 44dp.
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final text = context.type;
    return Row(
      children: [
        leading ??
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.onInk.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: t.onInk),
            ),
        const SizedBox(width: OSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.title3.copyWith(color: t.onInk),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(color: promptMuted(t)),
                ),
            ],
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: OSpace.md),
          Text(amount!, maxLines: 1, style: text.title2.semibold.tabular.copyWith(color: t.onInk, letterSpacing: -0.3)),
        ],
      ],
    );
  }
}
