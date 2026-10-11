# Auto Spend

Tracks where your money goes by reading bank SMS and UPI/bank-app
notifications on your phone. Android-first. Nothing leaves the phone — the app
has no internet permission.

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

## Try it

- **Web preview:** loads sample bank SMS through the real pipeline.
- **Android:** `flutter run`, or `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
  Allow SMS access from the home screen; notification access is optional.

## Code map

| Path | What |
|---|---|
| `lib/engine/parser.dart` | SMS/notification text → amount, direction, payee, UPI id, accounts, ref |
| `lib/engine/classify.dart` | Merchant vs person, merchant → category, payee keys for rules |
| `lib/engine/enrich.dart` | Derives category/kind/tags; self-transfer and card-bill detection |
| `lib/engine/ingest.dart` | Adds messages, skips re-reads, merges SMS + notification twins |
| `lib/engine/summary.dart` | Monthly totals and category breakdown |
| `lib/sources/` | SMS inbox (native channel in `MainActivity.kt`), notifications, sample data |
| `lib/ui/` | Design system — see `docs/DESIGN_STYLE.md` |
| `test/` | Parser, detectors, dedupe and an end-to-end sample month |

## Known limits

- The parser is regex-based; bank formats vary. Add real messages that it misreads
  to `test/parser_test.dart` and adjust.
- Notifications are only caught while the app process is alive; the SMS scan on
  open fills the gaps.
- Storage is JSON in app preferences — fine for thousands of transactions; move to
  SQLite if it grows past that.
