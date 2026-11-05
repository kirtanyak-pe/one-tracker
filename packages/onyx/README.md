# Onyx

A small, Material-free design system for Flutter. Monochrome ink on a cool
canvas, one blue accent, Inter type, Lucide icons, superellipse corners.
Built on `package:flutter/widgets.dart` only, so apps using it ship without
Material's theme, ripples or icon font.

```yaml
dependencies:
  onyx:
    path: packages/onyx   # or a git dependency when shared across repos
```

```dart
import 'package:onyx/onyx.dart';

void main() => runApp(const OApp(title: 'My app', home: HomeScreen()));
```

## Principles

1. **Ink first.** Primary buttons, selected chips, toggles and the tab bar's
   current tab are ink. Colour is a signal, not decoration.
2. **One accent.** Blue marks focus (the cursor, a focused field) and rare
   emphasis. Never two accents on one screen.
3. **Status colours mean status.** `positive`, `negative`, `warning` only for
   money direction, errors and alerts.
4. **Borders, not shadows.** Cards are surface + a hairline. Only things that
   float (tab bar, toasts, dialogs) cast a shadow.
5. **Quiet motion.** Ease-out, 140–380 ms, no bounce except a released drag.
   Everything respects the system's reduce-motion setting.
6. **Type does the hierarchy.** Inter 400/500/600; Inter Display for large
   numbers; money is always `.tabular`.

## Foundations

| | |
|---|---|
| Colour | `context.colors` — canvas, surface, raised, line, lineStrong, ink, inkSoft, inkFaint, onInk, accent, onAccent, positive, negative, warning, scrim |
| Type | `context.type` — hero 56, display 36, title1 28, title2 22, title3 17, body 15, bodyStrong, small 13, smallStrong, caption 12, label 15, overline 11 |
| Space | `OSpace` — 2, 4, 8, 12, 16, 20, 24, 32, 48; gutter 20 |
| Radius | `ORadius` — 8, 12, 16, 22, 28, pill; `ORadius.smooth(r)` |
| Motion | `OMotion` — fast 140, base 240, slow 380; standard / emphasized / exit |
| Theme | `OApp(mode: OThemeMode.system, light: ..., dark: ...)`; pass your own `OThemeData(colors: OColors(...))` to rebrand |

## Components

| Group | Widgets |
|---|---|
| App | `OApp`, `OPageRoute`, `pushScreen`, `OScrollBehavior` |
| Layout | `OScreen`, `OTopBar`, `OTabPage`, `OTabBar` |
| Surfaces | `OCard`, `OInset`, `ODivider`, `OSectionHeader`, `ORow`, `OGroup` |
| Actions | `OPressable`, `OButton` (primary/secondary/ghost/danger/accent/inverse/inverseSoft · sm/md/lg), `OIconButton`, `OTextButton` |
| Inputs | `OField` (own selection handles + copy/paste menu), `OToggle`, `OCheckbox`, `OCheckRow`, `OChip`, `OSegmented`, `showODatePicker` |
| Feedback | `OSpinner`, `OProgressBar`, `OBadge`, `OToast`, `OTooltip`, `ORefresh` |
| Overlays | `showOSheet` + `OSheetBody`, `showODialog` + `ODialog`, `showOConfirm` |
| Icons | `LucideIcons` (re-exported, pinned 3.1.25) |

Moving an existing Material app: see [MIGRATION.md](MIGRATION.md).

Inter is © The Inter Project Authors, SIL Open Font License 1.1
(`fonts/Inter-LICENSE.txt`); the bundled files are Latin subsets.
