import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../app_controller.dart';

/// Sensitive access the app asks for. Google Play wants each one explained
/// in the app, with a clear choice, before Android's own prompt.
enum Access { sms, notifications, contacts }

/// Says what [access] reads, what for, and that it stays on the phone.
/// True when the person chose to go ahead to Android's prompt.
Future<bool> explainAccess(BuildContext context, Access access) {
  final (icon, title, message) = switch (access) {
    Access.sms => (
      LucideIcons.messageSquareText,
      'Read your bank SMS?',
      'One Tracker reads the SMS on this phone to find bank, card and UPI alerts, and turns their '
          'amount, merchant, account ending and date into your spending. It reads the last 90 days '
          'now, and new alerts as they arrive, even when the app is closed.\n\n'
          'Messages that aren\'t payment alerts are skipped and not kept. Everything stays on this '
          'phone: the app has no internet access and never uploads or shares your messages.',
    ),
    Access.notifications => (
      LucideIcons.bellRing,
      'Read payment notifications?',
      'With notification access, One Tracker catches payments from UPI and bank apps the moment '
          'they happen, including ones that send no SMS.\n\n'
          'Android calls this access to all notifications. The app only keeps notifications that '
          'look like payments and skips everything else, chats included. Nothing leaves this phone.',
    ),
    Access.contacts => (
      LucideIcons.contactRound,
      'Show photos of people you pay?',
      'One Tracker looks up the people you pay in your contacts, by UPI number or exact name, to '
          'show their photo on those payments.\n\n'
          'It only reads names, numbers and photos, never changes your contacts, and nothing leaves '
          'this phone.',
    ),
  };
  return showOConfirm(context, title: title, message: message, icon: icon, confirm: 'Continue', cancel: 'Not now');
}

/// Explains [access], then asks Android for it if the person agreed.
Future<void> askAccess(BuildContext context, Access access) async {
  final app = AppScope.of(context);
  if (!await explainAccess(context, access)) return;
  await switch (access) {
    Access.sms => app.requestSms(),
    Access.notifications => app.requestNotifications(),
    Access.contacts => app.requestContacts(),
  };
}
