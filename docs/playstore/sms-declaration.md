# Permissions Declaration Form — SMS

**Core functionality:** SMS-based money management
(policy example: "apps that track and manage budget").

**Permissions:** `READ_SMS`, `RECEIVE_SMS`.

**Describe the core functionality (paste):**

> One Tracker is a personal expense tracker. Its core feature is building the
> user's spending history automatically from the transaction alerts their bank
> and card issuer send by SMS. READ_SMS reads the last 90 days of bank alerts
> when the user first allows access; RECEIVE_SMS records new alerts as they
> arrive, so spending stays up to date without opening the app. From each alert
> the app extracts the amount, merchant, account ending and date. Messages that
> are not bank or payment alerts are skipped and not stored. All processing is
> on the device: the app has no INTERNET permission and never uploads or shares
> SMS data. Before Android's permission prompt the app shows a disclosure that
> explains this, and the user can decline and add expenses manually.

**Is it the default SMS handler?** No — exception: SMS-based money management.

**Demo video (record on a test phone, ~60 s, no real SMS on screen):**
1. Fresh install → Home shows "Read your bank SMS" card.
2. Tap → the disclosure dialog → Continue → Android SMS prompt → Allow.
3. Spending appears on Home and in Activity (use test bank SMS sent to the
   test phone, or the sample data).
4. Settings › Sources shows Bank SMS allowed.
Upload unlisted to YouTube or Drive and paste the link.
