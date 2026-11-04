# One Tracker 1.4 — plan

Three changes, built in parallel by three agents in one working tree. Each agent owns its files and doesn't edit anyone else's.

## A. Count a payment in next month (agent A)

**The problem.** Salary arrives on the 28th and bills are paid the same day, so they belong to next month's budget. Today a payment always counts in the month it was paid.

**Model**
- Add `Txn.countMonth`: a nullable `DateTime`, the first day of the month the payment counts in. Null means it counts in the month it was paid. It goes in JSON and in `copyWith`, with a `clearCountMonth` flag.
- Add `Enriched.countAt`: the effective date. If `countMonth` is set it is `countMonth` (the 1st at 00:00); otherwise it is `txn.at`.

**Engine.** Every month, period or day bucket that feeds spend totals uses `countAt` instead of `txn.at`:
- `summary.dart` (`summarize`)
- `widget_data.dart` (today, week and month periods)
- `insights.dart` (daily bars, last month to date)
- `budgets` alerts, which go through `summarize`
- anything else found by grepping for `txn.at`

Lists, sorting and the displayed time still use `txn.at`.

**Controller**
- `moveToNextMonth(txnId)` sets `countMonth` to the month after the one the payment was paid in.
- `moveBack(txnId)` clears it.
- Both save, recompute and push the widget, like the other overrides.

**UI**
- *Transaction screen:* a row action reading "Count in November" (the month after it was paid). When the payment is moved, it shows "Counts in November · paid 28 Oct" and a "Move back to October" action.
- *Lists:* a moved payment shows a small "→ Nov" chip. It is listed under the month it counts in, with its real date.
- *Nudge:* while viewing a month, payments made in the last 5 days of the previous month aren't shown here. Within 5 days of the 1st, if the previous month has expense payments from its last 4 days, the home screen shows one quiet card: "3 payments on 28–31 Oct. Count them in November?" It offers "Review" (a sheet with checkboxes for each payment) and "Not now" (hidden for that month).

**Tests:** model JSON round-trip, `summarize` / widget / insights bucketing, moving a payment across a year boundary, and moving back.

## B. Splitwise goes offline (agent B)

**The problem.** The floating pop-up interrupts and doesn't work well. The API needs Splitwise Pro and can only split equally. The fix is to drop both and hand the payment to the Splitwise app, prefilled, where the user can split it any way they like.

**Remove**
- The floating overlay: `split_overlay.dart`, the `flutter_overlay_window` package, `SYSTEM_ALERT_WINDOW` and the overlay service in the manifest.
- The Splitwise API: `splitwise_api.dart`, `split_service.dart`, `split_math.dart`, the API key, the secure storage, the balances cache and the connect UI. Remove the `http` and `flutter_secure_storage` packages and the INTERNET permission if nothing else uses them. The app becomes fully offline.
- Keep the old git history as the archive, and note it in the README.

**Add**
- *Native `SplitwiseLauncher` (Kotlin):* opens Splitwise's add-expense screen prefilled with amount and description (and the group, if supported). The exact intent comes from the research below. If Splitwise isn't installed, it opens the Play Store page.
- *Split notification:* when a new debit at or above the minimum arrives, the app posts a notification instead of the overlay.
  - Title: "₹450 · Swiggy". Body: "Split it in Splitwise".
  - Tapping it, or the **Split** action, opens Splitwise prefilled. This goes through a small no-UI activity of ours, which records "split" and starts Splitwise, so no notification trampoline is involved.
  - **Skip** records "skipped" and dismisses.
  - **Not expense** marks the payment as not an expense and dismisses.
  - Actions are recorded natively in SharedPreferences as a pending queue. Dart applies the queue on start and on resume.
  - The notification is posted from both the live-app path and the background SMS engine path.
- *Settings → Splitwise:* the split notification on/off, the minimum amount, and the default group name (and group id if the intent supports it), plus "Test it" (opens Splitwise prefilled with ₹1).
- *Split tab:* lists "To split" (each with a Split button that opens Splitwise, and Skip) and history ("Opened in Splitwise", with undo). It no longer shows balances or API state.
- *Migration:* old split records and skips are kept. Old target, key and cache data are dropped.

**Tests:** the description and amount formatting for the intent, the queue apply logic, and that the split candidates still filter correctly.

## C. Card redesign (agent C)

**Scope.** Redesign the big review card ("₹X to Y. Count it as an expense?") and the in-app split card so they match the app's theme. The current cards are large elements placed loosely, with the floating card's orange and white look.
- Use the app's tokens and components, with a clear hierarchy: an amount and payee row, one line of context, then a row of actions. Use the `Shadows.lifted` and Lite-mode rules, dark mode, and the reduced-motion entrance.
- The split card no longer needs a group picker. It becomes a compact "Split ₹450 at Swiggy?" card with **Split in Splitwise** and **Skip**, calling the controller APIs that agent B provides.
- Check it in the web preview (port 8096, demo mode) at phone width, in light and dark. Update the golden and widget tests.

## Coordination
- **Contracts, fixed up front:**
  - `AppController.moveToNextMonth`, `moveBack` and `Enriched.countAt` (A).
  - `AppController.openInSplitwise(txnId)`, `skipSplit(txnId)` and `markNotExpense(txnId)` (B).
  - C builds UI against B's names.
- Agents never run `git commit`. I review, run the full tests, build, install and commit at the end. The version is 1.4.0+2007.
