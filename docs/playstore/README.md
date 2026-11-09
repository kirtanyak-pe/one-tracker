# Google Play — release checklist

Branch `playstore`. One Tracker reads bank SMS and payment notifications on the
phone, with **no internet permission**: nothing is collected, uploaded or shared.

## Done in the app (this branch)

- [x] Prominent disclosure before every sensitive ask (SMS, notification access,
      contacts): `lib/ui/access_disclosure.dart`. Each says what is read, why,
      and that it stays on the phone; "Not now" skips Android's prompt.
- [x] Contacts are no longer asked for automatically — only from Settings › Sources.
- [x] `android:allowBackup="false"`: Android's cloud backup can't copy the data
      off the phone. The app's own backup file (user-chosen location) stays.
- [x] No `INTERNET` permission (checked in the merged manifest of the AAB).
- [x] Target SDK 36. Version 1.5.0 (2100).
- [x] Splitwise stays: it only opens the Splitwise app with an intent the user
      taps, no API, no account, no data sent by us. Listing says "not affiliated".

## You do (in Play Console)

1. **Developer account** (one-time $25). Personal accounts made after
   13 Nov 2023 need a **closed test with 12+ testers opted in for 14 days in a
   row** before Production is unlocked.
2. **Package name** — permanent after the first upload. Currently
   `com.autosplit.auto_split`. Change it *before* uploading if you want e.g.
   `app.onetracker`.
3. **Play App Signing**: upload `OneTracker-1.5.0.aab`; the official key becomes
   the upload key. Keep `~/.config/one-tracker/` backed up.
4. **Privacy policy URL** — host `privacy-policy.md` (GitHub Pages is fine).
5. **App content** forms:
   - Data safety → `data-safety.md`
   - Sensitive permissions (SMS) → `sms-declaration.md` + demo video
   - Financial features → "None of these" except budgeting/expense tracking
     (no loans, no payments, no investments)
   - Content rating questionnaire → Finance, no user content → Everyone
   - Target audience 18+; no ads; government app: no; news: no
6. **Store listing** → `store-listing.md`, plus assets:
   - Icon 512×512 PNG, feature graphic 1024×500
   - 2–8 phone screenshots — **from sample data only** (Settings › Add sample data)
7. **Notification listener**: no declaration form exists for it, but the
   disclosure + listing must say why (done).

## Risks the reviewer may raise

- SMS is a restricted permission: approval depends on the declaration matching
  what the app visibly does. Core feature must be SMS-based expense tracking —
  keep the video showing the disclosure → Android prompt → spending appearing.
- The `<queries>` list of ~90 bank/UPI apps: used only to show app icons and
  match notifications. If questioned, it can be trimmed or moved to
  `QUERY_ALL_PACKAGES`-free matching by notification package name.
