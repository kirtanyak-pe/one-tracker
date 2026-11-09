# One Tracker

Tracks where your money goes by reading bank SMS and UPI/bank-app
notifications on your phone, and hands payments to the Splitwise app to split.
Android-first. Fully offline: the app has no internet permission, and
transactions never leave the phone.

**Download:** [latest APK](https://github.com/kirtanyak-pe/one-tracker/releases/latest) (64-bit Android). Open it on the phone and allow installing from your browser.

```
Bank SMS (inbox scan) ─┐
                       ├─► parser ─► ingest (dedupe SMS + app twins) ─► stored facts
UPI app notifications ─┘                                                   │
                                                                           ▼
            your overrides + payee rules + profile ─► enrich ─► category · kind · tags
                                                                           │
                                                                           ▼
                                                              month summary + review queue
```

## What it does

- **Reads transactions** from bank SMS (last 90 days on first run, then catches up
  every time the app opens) and live from payment-app notifications.
- **Names the payee** — merchant or the person you paid/received from — and tags
  the transaction with it.
- **Categorises** by merchant (Swiggy → Food, Uber → Transport, …); payments to
  people go to *People*.
- **Spots self transfers** and leaves them out of spending:
  - debit on one of your accounts + same-amount credit on another within 30 min
  - "sent to A/c XX7712" where ••7712 is also yours
  - paid to your own name (set in Settings)
  - the bank calls it a self transfer
- **Leaves out credit-card bill payments** — the card spends are already counted.
- **You can override anything**: mark *Not expense* / *Self transfer*, change the
  category, add tags, or set "Same for all <payee>" to make it a rule.
- **Every payment counts as an expense automatically.** Only big ones (above
  ₹5,000, adjustable or off in Settings) get a "count it as an expense?" check.
  Picking a category there teaches it for that payee.

### Automation
- **Repeating payments** (rent, subscriptions, gym) are found automatically — same
  payee, steady amount, monthly or weekly — with the next due date on Home.
- **Budgets**: a monthly total and per-category limits; a phone notification at
  80% and at 100%, once each per month.
- **Keyword rules**: "anything mentioning *zerodha* → Not an expense",
  "*canteen* → Food & drinks #Office". Applies to past and future payments.

### Analysis (Insights tab)
- Spend so far vs the same day last month, and the month-end projection.
- Day-by-day chart with the daily average; 6-month trend.
- Biggest category changes vs last month, top payees, repeating payments,
  biggest payments.

### Split (Splitwise)
Nothing is sent anywhere: One Tracker opens the Splitwise app's *Add expense*
screen with the amount and payee filled in (a link Splitwise handles itself), and
you pick who to split with and how, there.
- **After every payment** (above ₹100, adjustable) a notification offers
  "₹450 · Swiggy — Tap to split it in Splitwise", with **Split**, **Skip** and
  **Not expense** buttons. It works while the app is closed. If One Tracker is
  open, a card shows in-app instead.
- **Default group** (optional): paste the group's link from Splitwise on the web
  (`secure.splitwise.com/#/groups/<id>`) and new expenses start in it.
- **Split tab**: payments still to split (Split / Skip; tap a row for details),
  and what you sent to Splitwise, with undo. The app only knows you opened
  Splitwise, not whether you saved the expense or which group you picked. Settings → Splitwise has the switches and a test.
- Splitwise isn't installed → its Play Store page opens.
- The earlier version (floating pop-up card + Splitwise API with equal splits)
  is archived in `archive/splitwise-api/` (not built), with steps to restore it.

### Home-screen widget
Spent today / this week / this month with a Today | Week | Month toggle on the
widget itself (handled natively — instant, doesn't open the app). Month shows the
budget bar when one is set. Figures refresh whenever the app runs; after a period
ends without the app opening, it says "Open to refresh" instead of showing stale
numbers. Add it from Settings → Home screen → Add, or the launcher's widget list.

### Navigation
Home · Insights · Activity under a floating tab bar. Activity searches every
month by payee, #tag, category or amount, with Spent / Big / Excluded / Income filters.

### Performance on low-end phones
- Deriving everything (categories, transfers, insights, repeats) runs on a
  background isolate once there are 400+ payments; the UI thread only paints.
- Store read/write (JSON) is off the UI thread; stored messages are re-parsed
  only when `parserVersion` changes.
- Ingest and self-transfer pairing use indexes (linear, not quadratic).
- Tabs are built on first visit and kept fully offstage when hidden; the
  Activity list builds day cards lazily as you scroll.
- **Lite mode** (Settings → Appearance → Animations & effects, default Auto):
  on low-RAM phones (< 4.5 GB or Android "low RAM") animations collapse to
  instant and blurred shadows are dropped.
- Per-CPU APKs: `flutter build apk --release --split-per-abi` (17–20 MB vs 55 MB
  universal).
- Benchmarks: `flutter test test/perf` (3,000-payment year).

## Try it

- **Web preview:** loads sample bank SMS through the real pipeline.
- **Android:** `flutter run`, or `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
  Allow SMS access from the home screen; notification access is optional.

## App icon

Rendered from the design tokens by `tool/make_icon.py` (needs Pillow): an orange
background lit top-right with the review card's arcs, and a white ₹ coin in a
soft halo — the app's accent orb. Adaptive (foreground/background) and
monochrome (themed) layers included. Regenerate:

```
python3 tool/make_icon.py && dart run flutter_launcher_icons
```

## Code map

| Path | What |
|---|---|
| `lib/engine/parser.dart` | SMS/notification text → amount, direction, payee, UPI id, accounts, ref |
| `lib/engine/classify.dart` | Merchant vs person, merchant → category, payee keys for rules |
| `lib/engine/enrich.dart` | Derives category/kind/tags; self-transfer and card-bill detection |
| `lib/engine/ingest.dart` | Adds messages, skips re-reads, merges SMS + notification twins |
| `lib/engine/summary.dart` | Monthly totals and category breakdown |
| `lib/engine/insights.dart` | Pace, projection, daily/6-month series, movers, top payees, budget alerts |
| `lib/engine/recurring.dart` | Repeating-payment detection |
| `lib/ui/bar_chart.dart` | Single-series column chart (tap a bar for its value) |
| `lib/sources/` | SMS inbox (native channel in `MainActivity.kt`), notifications, Splitwise hand-off, sample data |
| `android/.../SplitwiseLauncher.kt`, `SplitNotifications.kt` | Builds the Splitwise link; posts the split notification and queues its button presses |
| `lib/engine/widget_data.dart` | Today/week/month figures for the widget |
| `android/.../SpendWidgetProvider.kt` | The widget: renders figures, handles the period toggle |
| `lib/split/` | Split records and settings, suggestion rules, queued notification actions, group-link parsing |
| `lib/splitwise/` | Splitwise API client (real + demo), models, equal-split maths |
| `lib/ui/` | Design system — see `docs/DESIGN_STYLE.md` |
| `test/` | Parser, detectors, dedupe and an end-to-end sample month |

## Known limits

- The parser is regex-based; bank formats vary. Add real messages that it misreads
  to `test/parser_test.dart` and adjust.
- Notifications are only caught while the app process is alive; the SMS scan on
  open fills the gaps.
- Storage is JSON in app preferences — fine for thousands of transactions; move to
  SQLite if it grows past that.
