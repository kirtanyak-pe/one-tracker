# Moving a Flutter app from Material to Onyx

Onyx replaces `package:flutter/material.dart` completely. After migration a
file imports `package:flutter/widgets.dart` (plus `services.dart` if it needs
haptics/clipboard) and `package:onyx/onyx.dart` — never material or cupertino.

Read the component sources in `packages/onyx/lib/src/` when a parameter is unclear.

## Design direction (premium and clean)

- Monochrome: ink on canvas. Surfaces are white (dark: near-black) with a
  hairline border, **no shadows** (only floating layers — tab bar, toasts,
  dialogs — lift).
- `accent` (indigo) is for focus/selection/rare emphasis only — never decoration.
- `positive` / `negative` / `warning` only ever mean status or money direction.
- Former orange "hero" cards become **ink cards**: `OCard(color: c.ink, border: false)`,
  text in `c.onInk`, buttons `OButtonVariant.inverse` (main) / `inverseSoft` (secondary).
- Weights: 400/500/600. Avoid w700/w800 (use `.semibold`).
- Money: `.tabular`.

## Tokens (already renamed in the app)

`context.colors` (`final t = context.colors;` in this app):
canvas, surface, raised, line, lineStrong, ink, inkSoft, inkFaint, onInk,
accent, onAccent, positive, negative, warning, scrim; `c.soft(color)` = 12 % wash; `c.accentSoft`.

`context.type` (`final text = context.type;`): hero 56, display 36, title1 28,
title2 22, title3 17, body 15, bodyStrong 15/500, small 13 (inkSoft), smallStrong 13/500,
caption 12 (inkSoft), label 15/600, overline 11. These are non-null — no `?.` / `!`.
Extensions: `.tabular`, `.tint(color)`, `.medium`, `.semibold`.

`OSpace` xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48 · gutter 20.
`ORadius` xs 8 · sm 12 · md 16 · lg 22 · xl 28 · pill; `ORadius.smooth(r, side:)` = superellipse ShapeBorder.
`OMotion` fast/base/slow, curves standard/emphasized/exit, `OMotion.of(context, d)`.
`context.onyx.isDark` / `.brightness`.

## Widgets

| Material / old app widget | Onyx |
|---|---|
| `Scaffold(body: CanvasBackground(SafeArea(Column[TopBar(title:'X', trailing:), Expanded(body)])))` | `OScreen(title: 'X', trailing: ..., body: body, bottom: optionalPinnedButton)` |
| `TabPage(...)` (app) | `OTabPage(...)` same params |
| `TopBar` / `CanvasBackground` (app) | gone — `OScreen` / `OTabPage` paint the canvas and bar |
| `SurfaceCard(child, padding, radius, onTap, selected)` (app) | `OCard(...)` same params (+ `color`, `border`, `onLongPress`) |
| `Tray(child, padding, radius)` (app) | `OInset(child, padding, radius)` (old default padding was `OSpace.xl`, radius `ORadius.lg`) |
| `CircleIconButton(icon, tooltip, onPressed)` (app) | `OIconButton(icon:, label: tooltip, onPressed:, filled: true, size: 44)` |
| `PillSegmented<T>(options: map, value, onChanged)` (app) | `OSegmented<T>(values: map.keys.toList(), selected: value, labelOf: (v) => map[v]!, onChanged:)` |
| `SectionHeader(title, trailing:, top:)` (app) | `OSectionHeader(title, trailing:, top:)` |
| `AccentOrb(icon, onPressed, tooltip)` (app) | `OIconButton(icon:, label: tooltip, onPressed:, size: 44, background: c.ink, color: c.onInk)` |
| `Card` | `OCard` |
| `Material` / `InkWell` / `InkResponse` / `Ink` | `OPressable(onTap:, child:)` around a `Container`/`DecoratedBox`; or `OCard(onTap:)` |
| `FilledButton(child: Text('X'))` / `.icon` | `OButton(label: 'X', icon: LucideIcons.y, onPressed:)` |
| `FilledButton.tonal` / `OutlinedButton` | `OButton.secondary(...)` |
| `TextButton` | `OButton.ghost(...)`, or `OTextButton(label:, onPressed:, icon:)` for inline links |
| full-width button (`SizedBox(width: double.infinity, child: ...)`) | `OButton(..., expand: true)` |
| sizes | `size: OButtonSize.sm` (36) / `md` (44, default) / `lg` (52) |
| `IconButton(icon: Icon(x), tooltip:, onPressed:)` | `OIconButton(icon: x, label: tooltip, onPressed:)` |
| `TextField(decoration: InputDecoration(hintText, labelText, prefixIcon, prefixText, suffixIcon, errorText))` | `OField(placeholder:, label:, prefixIcon: IconData, prefixText:, suffix: Widget, error:, controller:, onChanged:, onSubmitted:, keyboardType:, textInputAction:, textCapitalization:, inputFormatters:, autofocus:, autocorrect:, style:, textAlign:, maxLines:)` |
| borderless amount `TextField` (`InputBorder.none`, `isCollapsed`) | `OField(bare: true, style: ..., textAlign: ...)` |
| `Switch` | `OToggle(value:, onChanged:)` |
| `Checkbox` | `OCheckbox(value:, onChanged:)` (non-null bool) |
| `CheckboxListTile` | `OCheckRow(value:, onChanged:, title:, subtitle:)` |
| `ActionChip` / `FilterChip` / `Chip` | `OChip(label:, selected:, onTap:, icon:, dense:)` |
| `Divider` | `ODivider(indent:, endIndent:, space:)` |
| `Tooltip(message, child)` | `OTooltip(message:, child:, tapToShow:)` — drop it when the child is an `OIconButton` (its `label` covers it) |
| `LinearProgressIndicator(value)` | `OProgressBar(value:, height:, color:, track:)` |
| `CircularProgressIndicator` | `OSpinner(size:, color:)` |
| `RefreshIndicator(onRefresh, child)` | `ORefresh(onRefresh:, child:)` |
| `SelectableText` | `Text` |
| `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), action: SnackBarAction(label, onPressed)))` | `OToast.show(context, m, actionLabel: label, onAction: onPressed)` (`hideCurrentSnackBar` → `OToast.hide()`) |
| `showDialog(builder: AlertDialog(title, content, actions))` | `showODialog<T>(context, builder: (context) => ODialog(title: 'X', message: 'Y', content: widget, actions: [OButton(label:, expand: true, onPressed:), OButton.ghost(label: 'Cancel', expand: true, onPressed:)]))` — primary first; destructive → `variant: OButtonVariant.danger` |
| a pure yes/no dialog | `await showOConfirm(context, title:, message:, confirm: 'Delete', destructive: true)` → bool |
| `showModalBottomSheet(builder: ...)` | `showOSheet<T>(context, builder: (context) => OSheetBody(title:, subtitle:, child:, actions: [...]))` |
| `Navigator.push(context, MaterialPageRoute(builder: (_) => X()))` | `pushScreen(context, const X())` or `OPageRoute(builder: ...)` |
| `showDatePicker(initialDate, firstDate, lastDate)` | `showODatePicker(context, initial:, first:, last:)` |
| `Colors.transparent` / `Colors.white` / `Colors.black` | `const Color(0x00000000)` / `Color(0xFFFFFFFF)` / role colours |
| `Theme.of(context).brightness == Brightness.dark` | `context.onyx.isDark` |
| `Shadows.card(...)` / `Shadows.lifted` / `Shadows.glow` (app, deleted) | remove — use a hairline border (`c.line`) instead |
| `Shadows.floating` | `OShadow.floating(context.onyx.brightness)` |
| `Curves.x` | fine (from widgets) — prefer `OMotion` curves |

## Icons — Material → Lucide (`LucideIcons.x`, outline style, verified in 3.1.25)

chevron_right→chevronRight · chevron_left→chevronLeft · close→x · add→plus ·
remove→minus · sms_outlined→messageSquareText · call_split/split→split ·
tune→slidersHorizontal · search→search · receipt_long_outlined→receiptText ·
notifications_active_outlined→bellRing · notifications_none→bell ·
delete_outline→trash2 · check_circle→circleCheck · check→check ·
widgets_outlined→layoutGrid · upload_file_outlined→fileUp ·
trending_up→trendingUp · trending_down→trendingDown · swap_horiz→arrowLeftRight ·
storage_outlined→database · south_west→arrowDownLeft ·
shopping_bag_outlined→shoppingBag · settings_backup_restore→archiveRestore ·
science_outlined→flaskConical · restaurant_outlined→utensils · refresh→refreshCw ·
priority_high→circleAlert · person_outline→user · palette_outlined→palette ·
open_in_new→externalLink · movie_outlined→film · more_horiz→ellipsis ·
local_grocery_store_outlined→shoppingCart · local_atm_outlined→banknote ·
groups_outlined→users · flight_outlined→plane · favorite_outline→heart ·
event_repeat(_outlined)→calendarSync · edit_outlined→pencil ·
donut_large_outlined→chartPie · directions_car_outlined→car ·
calendar_today_outlined→calendar · calendar_month_outlined→calendarDays ·
bolt→zap · auto_fix_high_outlined→wandSparkles · arrow_upward→arrowUp ·
arrow_downward→arrowDown · arrow_forward→arrowRight ·
arrow_drop_up→chevronUp · arrow_drop_down→chevronDown · settings→settings

Any other: check it exists with
`grep -n "static const IconData NAME =" ~/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.25/lib/lucide_icons.dart`.
Lucide icons are thinner — use size 20 in rows/buttons, 18 in chips/fields.
