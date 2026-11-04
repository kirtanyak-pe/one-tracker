# Archived: Splitwise API splitting (up to 1.3.0)

Not compiled, analyzed or tested. Kept so the API version can come back.

Until 1.3.0, One Tracker split payments through the Splitwise API: a
floating card after each payment, a chosen group or friends, and equal
splits. It needed a Splitwise Pro API key. In 1.4 it was replaced by a
notification that opens the Splitwise app prefilled, so the app is now
fully offline.

The files are copied from commit 2ea1973 at the same paths they had then.
`lib/split/split_models.dart`, `lib/screens/split_tab.dart` and
`lib/screens/settings/split_settings_page.dart` are the old versions; the
live app has newer ones.

## To bring it back

1. Copy `lib/splitwise/*` and `lib/split/split_service.dart` back into `lib/`,
   plus `split_overlay.dart` and `split_card.dart` if you want the floating card.
2. Add these back to `pubspec.yaml`:
   `http: ^1.6.0`, `flutter_secure_storage: ^11.2.0`,
   `flutter_overlay_window: ^1.0.0` (overlay only).
3. Add these back to `AndroidManifest.xml`: `INTERNET`, plus
   `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE` and the overlay service
   (overlay only). `git show 2ea1973:android/app/src/main/AndroidManifest.xml`
   has the exact entries.
4. Wire `SplitService` into `AppController` again (see `git show 2ea1973:lib/app_controller.dart`).

With the API back, the app could also read which group an expense went to
and whether it was saved. The notification route can't.
