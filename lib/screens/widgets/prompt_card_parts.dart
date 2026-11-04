import 'package:flutter/material.dart';

import '../../ui/tokens.dart';

/// Shared pieces of the two "decide this payment" cards (review + split), so
/// they read as one family: white card, header row, one muted line, actions.

/// The card surface: same card colour, radius and shadow as the day cards.
class PromptSurface extends StatelessWidget {
  const PromptSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(Radii.tile),
        boxShadow: Shadows.card(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}

/// Icon in a tray circle · title and muted subtitle · optional amount on the right.
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
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        leading ??
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.tray, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: t.ink),
            ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.muted),
                ),
            ],
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: Space.md),
          Text(
            amount!,
            maxLines: 1,
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// Buttons for the action row: one accent primary, one quiet tray secondary.
/// Both 48dp tall pills.
abstract final class PromptButtons {
  static const height = 48.0;

  /// The one primary action. [AppTokens.accentDeep] so white text passes AA.
  static ButtonStyle primary(AppTokens t) => FilledButton.styleFrom(
    backgroundColor: t.accentDeep,
    foregroundColor: t.onAccent,
    disabledBackgroundColor: t.trayDeep,
    disabledForegroundColor: t.muted,
    minimumSize: const Size(64, height),
    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
    shape: const StadiumBorder(),
  );

  static ButtonStyle secondary(AppTokens t) => FilledButton.styleFrom(
    backgroundColor: t.tray,
    foregroundColor: t.ink,
    disabledBackgroundColor: t.tray,
    disabledForegroundColor: t.muted,
    minimumSize: const Size(64, height),
    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
    shape: const StadiumBorder(),
  );
}
