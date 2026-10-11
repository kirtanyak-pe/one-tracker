# Auto Split

Spots payments you make on your phone and asks, in a floating bubble, whether
to split them on Splitwise. Android-first.

```
Bank / UPI notification ─► PaymentWatcher ─► parsePayment ─► "To split" inbox
                                                     │
                                                     ▼
                                     Floating bubble (QuickSplitCard)
                                                     │  Split equally
                                                     ▼
                                    Splitwise API  POST /create_expense
```

## Try it

- **Web preview (UI only):** runs in demo mode with fake groups. Tap ⚡ to
  simulate a payment. Auto-detection and the bubble need Android.
- **Android:** `flutter run` on a phone (USB debugging on) or an emulator.

## Connect your Splitwise account

1. On the web, open <https://secure.splitwise.com/apps> → **Register your application**
   (any name and URL).
2. Copy the **API key**.
3. In the app: **Settings → Splitwise API key → Connect**.

The key is stored with `flutter_secure_storage`. Without a key the app stays
in demo mode and nothing is sent to Splitwise.

> Splitwise's self-serve API is for **non-commercial** use. A paid or public
> release needs a commercial licence from developers@splitwise.com.

## Android permissions

| Permission | Why | Granted from |
|---|---|---|
| Notification access | Read bank SMS / GPay / PhonePe / bank-app notifications | Home → *Turn on detection* |
| Display over other apps | Show the split bubble on top of whatever app you're in | Settings → *Floating bubble* |

No `READ_SMS`: bank SMS are picked up from the SMS app's notification, which
avoids Google Play's restricted SMS permission review.

## Code map

| Path | What |
|---|---|
| `lib/detection/payment_parser.dart` | Regex parser: amount + merchant from notification text, ignores OTPs, credits, refunds, reminders. Dedupes the UPI-app + bank double notification. |
| `lib/detection/payment_watcher.dart` | Android `NotificationListenerService` bridge |
| `lib/overlay/split_bubble.dart` | Opens the bubble; `SplitBubbleApp` runs in the overlay's own isolate |
| `lib/overlay/quick_split_card.dart` | The "₹450 at Swiggy — split it?" card (bubble + in-app sheet) |
| `lib/splitwise/` | API client (real + demo), models, equal-split math |
| `lib/app_controller.dart` | App state; glues detection → inbox → bubble → Splitwise |
| `test/` | Parser, dedupe, split math, money and API-error tests |

## Known limits / next steps

- **Detection only runs while the app process is alive.** Android may kill it
  in the background. Next: move parsing into a native foreground service or a
  headless Dart entry point so it survives.
- **Parser is regex-based.** Tune it with real notification texts from your
  bank and UPI apps (add them to `test/payment_parser_test.dart` first).
- **Bubble splits equally with a group only.** "More options" (friends, custom
  amount) is in-app; the bubble can't open the app yet.
- **Personal API key, not OAuth.** Fine for your own account; other users would
  need the OAuth 2.0 flow.
- **iOS:** no notification reading or overlays. Manual split works; detection
  would need email parsing.
