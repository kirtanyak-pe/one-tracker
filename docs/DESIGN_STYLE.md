# Auto Split — design style

Extracted from the fitness-app reference shots (Dashboard / Progress / Assistant)
and adapted to a payment-splitting app. Tokens live in `lib/ui/tokens.dart`,
components in `lib/ui/components.dart`.

## 1. What the reference is doing

**Mood:** calm, soft, tactile. A warm-grey world, white "objects" resting on it,
and one hot orange that only shows up where something needs you.

| Trait | Observed | Notes |
|---|---|---|
| Canvas | `#E8E8E8 → #F0F0F0` soft vertical gradient | Never pure white — white is reserved for objects |
| Objects | Pure white cards, r ≈ 28, near-invisible shadow | Lift comes from contrast with the canvas, not shadow |
| Trays | Slightly *darker* grey (`#E0E0E0`) inset areas holding white things | Goal card, segmented control, quick-action tiles, chat bubbles |
| Accent | Burnt orange `#DE6645`, used sparingly | Hero tip card, the ⚡ orb, ring arcs, active nav icon |
| Glow | Accent orb with 2–3 fading orange halos | Signals "the thing to tap" |
| Ink | Near-black `#060606` text and dark data marks | Black arcs/bars next to orange ones |
| Muted text | `#929292` labels above big values | Too light for AA → adapted below |
| Shape | Everything is a pill or a big-radius rectangle | Buttons, tabs, chips, nav, inputs are full pills |
| Type | Geometric grotesk; huge centred hero (≈40 bold, tight); big values (≈28 medium); small grey labels | Label-above-value pattern everywhere |
| Data | Thin rings, thin bar ticks, arcs | Minimal, mostly monochrome + one orange series |
| Nav | Floating dark-grey gradient pill; active item = white pill with icon + label | |
| Hero card | Orange card, white copy, ghost pill + solid white pill, dark badge overlapping the top edge, concentric arc décor | |
| Chat | User bubble grey tray, reply bubble white, timestamps small grey, suggestion chips grey pills, input a white pill | |
| Layout | 20–24 px gutters, 2-up stat tiles, horizontal rows that bleed off-screen | |

## 2. Tokens (adapted)

| Token | Light | Dark | Why |
|---|---|---|---|
| `canvas` | `#EDEDED` (gradient to `#F3F3F3`) | `#121212` | reference bg |
| `tray` | `#E2E2E2` | `#1C1C1C` | inset containers |
| `trayDeep` | `#D9D9D9` | `#262626` | tracks, dividers |
| `card` | `#FFFFFF` | `#222222` | objects |
| `ink` | `#111111` | `#F2F2F2` | text, primary button fill |
| `onInk` | `#FFFFFF` | `#111111` | text on primary |
| `muted` | `#616161` | `#9A9A9A` | **darkened** from `#929292` (2.7:1 → 4.7:1 on tray) |
| `accent` | `#DE6645` | `#DE6645` | |
| `accentDeep` | `#C24C2C` | `#C24C2C` | orange *surfaces with text* (white 4.8:1); the reference orange stays for orb, rings, glow |
| `accentHalo` | accent @ 18% / 8% | same | glow rings |
| `success` | `#2F9E6B` | `#4CC38A` | "split done" only |

Radius: `card 28 · tile 24 · input 20 · pill 999`.
Spacing: 4-pt scale, page gutter 20, card padding 20.
Shadow: one soft shadow (`0 8 24 / 6%`) on cards; accent glow on the orb only.

Type (Plus Jakarta Sans — closest free match):
`hero 34/1.1 bold -1` · `amount 28 semibold` · `section 20 semibold` ·
`title 16 semibold` · `body 15 medium` · `label 13 medium muted` · `button 15 semibold`.

## 3. Rules that make it systemic

1. **Canvas → tray → card.** Grey holds white. Never white-on-white, never grey-on-grey cards.
2. **One orange moment per screen.** Orange means "a payment needs you" — the split
   prompt, the ⚡ orb, a ring arc. Everything else is ink + greys.
3. **Ink is the button.** Orange + white text fails AA (3.45:1), so the primary
   button is an ink pill. Orange cards that carry text use `accentDeep` (4.8:1),
   lit by a reference-orange glow in the corner; their buttons flip to white
   (solid) and white-ghost (secondary).
4. **Label above value.** Small muted label, big value underneath — stats, amounts,
   per-person shares.
5. **Pills for anything you tap.** Buttons, chips, segmented controls, inputs.
6. **Big, centred, human headline** on the home screen that reflects state
   ("You're all square!" / "2 payments to split").

## 4. Where each pattern lands in Auto Split

| Reference pattern | Auto Split use |
|---|---|
| Hero headline "Let's start strong!" | Home headline driven by inbox: *all square* vs *n payments to split* |
| Goal tray + ⚡ orb | Status tray: Splitwise connection + detection state; orb = test payment |
| Workout / Meal / Water / Sync tiles | Quick actions: **Add · Test · Sync · Settings** |
| Daily Summary stat tiles + ring | **Waiting** (₹ pending, count) and **Split this week** (₹, ring = share of payments split) |
| Orange tip card with Dismiss / Set Routine + dark badge | **The split prompt** — floating bubble *and* in-app sheet: "₹450 at Swiggy", group pills, *Later* / *Split equally* |
| Daily / Weekly / Monthly segmented tray | Group / Friends switch on the split screen |
| Big numbers (2.340, 3.4km) | Centred amount entry on the split screen |
| Chat bubbles / timestamps | "Recent splits" rows (white rows in a tray, time in muted) |
| Suggestion chips | Group pills inside the split prompt |
| White pill input with mic | All text fields: white, borderless, rounded |
| Floating dark nav pill | Not used — the app has no tabs. The floating ink pill style is reused for snackbars |

## 5. Not carried over

- Bottom tab bar (no sections to switch between).
- Decorative bar/arc charts with no data behind them.
- `#929292` muted grey (contrast).
