# Onyx components

One page for both apps. Dart is the reference (`packages/onyx/lib/src`); One Split implements the same thing in CSS
(`src/ui/ui.module.css`, `src/screens/screens.module.css`). Numbers are logical px. Colours, spacing, radii, type and the
finishes come from `tokens/onyx.tokens.json`; the CSS variable is given as `--o-*` / `--f-*`.

**Depth** says which finish recipe a thing takes (see the `finish` section of the tokens):
**strong** solid fills (`--f-strong`, with `--f-strong-sheen`), **soft** light or outlined pressables (`--f-soft`, `--f-soft-sheen`),
**surface** cards, bars, dialogs (`--f-surface`, `--f-surface-sheen`), **well** fields, trays, tracks (`--f-well`).
Floating layers (sheet, dialog, tab bar, toast, menu) add `--f-floating` (`OShadow.floating`). Cards keep a 1px hairline
(`--f-hairline`, `--f-edge` on outlined things) in the **flat** and **raised** finishes only. Every pressable scales to 0.97
while held (0.94 for icon buttons and tab labels) and dims to 0.38 when disabled (CSS: 0.4).

| Component | Dart | One Split CSS |
|---|---|---|
| Button | `OButton`, `OIconButton`, `OTextButton` | `.btn` `.btnPrimary` `.btnSecondary` `.btnGhost` `.btnDanger` `.btnSm` `.btnLg` `.iconBtn` `.textBtn` |
| Row, group | `ORow`, `OGroup` | `.row`, `.rowText`, `.rowEnd` inside `.card` |
| Card, inset | `OCard`, `OInset` | `.card` `.cardPad`, `.inset` |
| Chip | `OChip` | `.chip` `.chipOn` |
| Segmented | `OSegmented` | `.segmented` `.segment` `.segmentOn` |
| Field | `OField` | `.field` (screens) |
| Sheet | `showOSheet` | `.sheet` `.grab` `.scrim` |
| Dialog | `showODialog`, `showOConfirm` | `.dialog` `.actions` `.scrimCenter` |
| Tab bar | `OTabBar` | `.tabbar` `.tab` `.tabOn` `.tabPill` |
| Top bar | `OTopBar`, `OTabPage` header | `.topbar` `.topbarTab` `.topTitle` |
| Snackbar / toast | `OToast.show` | `.toast` `.snack` `.snackAction` |

## Button
- **Sizes** (height / side padding / label size / icon): sm 36 / 14 / 13 / 16, md 44 / 18 / 15 / 18 (default), lg 52 / 20 / 16 / 22. Label is `label` type (weight 600, tracking -0.1) at that size; icon gap 8. Always a stadium (`radius.pill`).
- **Kinds**: primary = ink fill, onInk label, **strong**. Secondary = soft surface with a hairline edge, ink label, **soft** (Dart fills `raised`, CSS fills `surface`; same look). Ghost = no fill, ink label, side padding 6 less, no finish. Danger = negative fill, **strong**. Accent = accent fill, **strong**. Inverse / inverse-soft (on an ink card): onInk fill, or onInk at 14 %.
- **States**: pressed = scale 0.97 and the bevel turns inward (`pressedShade`); disabled = 0.38 opacity, flat; loading = flat, label hidden behind a spinner of the icon size, no taps.
- **Icon button**: 40 circle (44 tap area; 44 filled on tab pages), icon 20, **soft** with hairline when `filled`, bare otherwise; pressed scale 0.9 (CSS `.iconBtn` is a 40 **surface** circle, 0.94).
- **Text button**: `smallStrong` semibold, padding 8 x 4, no fill; pressed = 0.5 opacity.
- One primary per screen. In a dialog or sheet, actions stack full width with 8 between (CSS 10), primary on top.

## Row and group
- Row: min height 56, padding 16 x 12, 14 between leading, text and trailing. Title `bodyStrong`, subtitle `small` (inkSoft), 2 between. Trailing amount is tabular and right-aligned.
- Group: rows in one card (**surface**), a 1px divider (`line`) between them, inset 16 from the left.

## Card and inset
- Card: radius `lg` 22 (smooth), padding 20, **surface**; hairline when the finish allows it; selected = 1.5 ink border.
- Inset: a well inside a card, radius `md` 16, padding 16, **well**, fill `raised`.

## Chip
- Height 36 (dense 30), padding 14 (dense 10), icon 16 (dense 14) with 6 gap, label `smallStrong` medium (dense: `caption`). Stadium.
- Off = **soft** on `surface` with a `lineStrong` outline; on = **strong** ink with an onInk label. Pressed scales 0.97.

## Segmented
- Track: height 40, padding 3, stadium, **well** on `raised`. Thumb: stadium, **soft** on `surface`, slides to the choice. Labels `smallStrong`, inkSoft off, ink on; 6 gap to an icon.

## Field
- Radius `md` 16, **well** on `raised`; focused = **surface** on `surface` with a 1.5 border (ink; error = negative). Min height 52 (One Split 56), padding 16 left and right (14 left with a prefix icon, 4 right with a suffix), prefix icon 18 (inkSoft, ink when focused).
- Label above (`smallStrong`) with 8 gap; helper or error below with 6 gap, `small` (error in negative). Placeholder `inkFaint`. Focus animates in `motion.fast`.

## Sheet
- Slides up from the bottom, max width 640, top radius `xl` 28, **surface** plus `--f-floating`; in glass it blurs what is behind it. Grab handle 36 x 4 (`lineStrong`) 8 below the top. Drag down past 35 % of its height, or fling, to close.
- Content padding 20 sides, 16 top and bottom. Title `title2`, 6 gap, subtitle `small`, 20 gap, then the content. Actions below, stacked, 20 sides, 12 bottom. Scrim = `--o-scrim`, fading in `motion.base`; the page behind blurs up to `blur.scrimSigma` while it opens. Open 380 ms (`emphasized`).

## Dialog
- Centered, max width 400, 24 from the screen edge, radius `xl` 28, padding 24, **surface** plus `--f-floating`. Optional 40 icon tile (radius `sm`, **surface**), then title (`title2`), message (`small`), actions: stacked full width, 8 gap, primary on top, cancel last. Pops in `motion.base`.
- Confirm = title as a question, message says what will happen, two buttons (see WRITING.md). Destructive confirms use the danger kind.

## Tab bar
- Floating stadium, height 64, padding 6, 20 from the sides, 14 above the bottom inset. **Surface** plus `--f-floating` (pillow and glass use **soft**; glass blurs with `blur.tabBarSigma` and, in CSS, saturates 1.6).
- The selected tab is an ink **strong** pill that slides (`motion.slow`, `emphasized`) and shows its label (`smallStrong`, onInk); the others show an icon only (inkSoft) and share the rest of the width 3:5.

## Top bar
- Height 56, padding 10, 52-wide slots left and right (back button, actions), title `title3` centered, one line. Tab pages use a 60 tall bar with the 20 gutter and 44 filled icon buttons.

## Snackbar / toast
- Floating above the tab bar (96 + bottom inset), 16 from the sides, max width 480, min height 48, radius `md` 16, padding 16 x 8 (6 right with an action), `smallStrong`. Icon 18 with 10 gap. Action = a pill (12 x 8) at 12 % of the text colour, semibold; in CSS an underlined text button.
- Shows 3 s (5 s with an action); in `motion.base`, out `motion.fast`; swipe down to dismiss. One at a time.
- Colours: One Tracker keeps it dark (`#1A1E25` on `#F2F5F9`) in both themes; One Split uses ink on onInk, so it flips with the theme.

## Known differences between the apps (components, not tokens)
- Field height 52 (Tracker) vs 56 (Split), and Split's focus ring is the accent where Tracker's is ink.
- Toast colours (above). Secondary button fill (`raised` vs `surface`), identical to the eye.
- Danger button label: Tracker is always white; Split uses `onInk` (dark text on the dark-mode red, which passes 4.5:1; white on `#FF6370` does not).
- Soft sheen in pillow runs top to bottom in both apps since the token change (Split used a 135 degree diagonal).
