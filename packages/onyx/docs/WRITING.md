# Writing for the One apps

One voice across One Tracker, One Split and anything else in the family. Based on the copy both apps already use.

## Voice
- **Short and plain.** The fewest words that are still clear. No jargon, no exclamation marks, no emoji, no "please".
- **Second person.** Talk to "you". "You pay Sam" not "User owes Sam". The app says "we" only when it did something ("We couldn't save that").
- **Sentence case** everywhere: titles, buttons, tabs, menu items, section labels in the source (the overline style uppercases them for you). Proper nouns keep their capitals (Splitwise, UPI).
- **Calm.** State the fact, then the next step. Never blame the person.

## Buttons and links
- **A verb, or verb and object.** "Add expense", "Settle up", "Remind all", "Save", "Delete", "Leave". Not "OK", "Yes", "Submit" or "Confirm".
- Say the thing that happens: a delete confirm says "Delete", a leave confirm says "Leave", not "Yes".
- The safe choice names itself: "Keep it", "Stay", "Cancel". The destructive one comes second and uses the danger kind.
- While working, switch to the -ing form: "Saving…", "Deleting…", "Leaving…". One ellipsis character, not three dots.
- Navigation labels are nouns: "Home", "Groups", "Activity", "Settings".

## Confirmations and dialogs
- **Title is a question about the action:** "Delete transaction?", "Leave Flat 3?", "Restore this backup?".
- **The message says what will happen, and to whom.** "You'll stop seeing Flat 3 in your groups. Everything you added stays for the others, and Splitwise lets them know you left." "It will come off every payment to Corner Cafe, not just this one."
- Name the thing ("Delete “Groceries”?") when there is one. Mention the way back if there is one ("It may come back if the SMS is scanned again").
- Two buttons: the safe one, then the action. Don't ask when undo is cheap: do it and show a toast with Undo.

## Money
- **Who pays whom, in words:** "You pay Sam", "Sam pays you", "you get back", "you get", "you pay", "settled". **Never "owe"** or "owed".
- **No + or − on amounts.** Colour shows direction: positive (green) when you get money, negative (red) when you pay, plain when it is zero or settled. A caption says it in words too ("you get", "you pay") so colour is never the only signal.
- **Whole rupees on totals and headline amounts** (₹958, not ₹958.40); show paise where exactness matters (a single expense, a payment you are about to record) or when the user turns decimals on.
- Symbol first, no space: ₹1,200. Indian digit grouping (₹1,25,000). Use tabular figures so columns line up. Other currencies use their own symbol or code first.
- A balance headline reads as a sentence: "Overall, you get back ₹958".

## Empty states
- **Say what to do next**, in one or two short lines, with a button when there is one obvious action. Title says what is missing; text says how to fix it.
  - "No groups yet. Make one, or join one in Splitwise and it shows up here." [New group]
  - "All settled with Sam. Nothing to pay, nothing to get. Add an expense the next time you split a bill."
  - "Nothing here this month." / "No matches" for an empty search.
- "Nothing" or "No" + the thing, plus "yet" when it will fill itself.

## Errors
- **What happened, then what to try.** "Couldn't reach Splitwise. Try again in a moment." "Couldn't save the backup. Try another location."
- Use "Couldn't" (contraction, curly apostrophe in the web app). Name the action ("Couldn't delete that expense"), not the cause ("Request failed").
- If the system gave a reason that helps, add it after a colon ("Couldn't save: no signal"). Never show raw codes or stack traces.
- Say when nothing was lost: "Your input is kept — try again."
- Disabled things explain why when it isn't obvious ("Set a screen lock in Android settings first").

## Toasts
- One short sentence, past tense, no full stop needed when it is a fragment: "Skipped Corner Cafe", "Counted in December", "3 payments counted in December". Add an action only for Undo.

## Small rules
- Numbers: digits ("3 payments"), singular for one ("1 payment"). Dates read the way people say them ("05 Nov", "this month", "last 90 days").
- Use the same word for the same thing everywhere: expense (a split bill), payment (money that moved), group, friend, settle up.
- Placeholders are examples, not labels: "Dinner 1200 with Sam and Alex", "name@bank". Every field still has a label.
- Privacy lines are plain and specific: "Nothing leaves your phone."
- No hyphen as a dash: use an em dash with spaces " — " or split into two sentences.
