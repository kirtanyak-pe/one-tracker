import 'package:flutter/widgets.dart';
import 'package:onyx/onyx.dart';

import '../../app_controller.dart';

/// First run: what stays on the phone, and the access the app can use.
/// The rows say what each access reads, so Allow goes straight to Android.
Future<void> showWelcomeSheet(BuildContext context) async {
  final app = AppScope.of(context);
  await showOSheet<void>(context, builder: (_) => const _WelcomeSheet());
  await app.markWelcomed();
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = context.colors;
    final text = context.type;

    Widget point(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.symmetric(vertical: OSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: t.ink),
          ),
          const SizedBox(width: OSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodyStrong),
                const SizedBox(height: OSpace.xxs),
                Text(body, style: text.small.copyWith(color: t.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );

    Widget access(
      IconData icon,
      String title,
      String body,
      bool granted,
      Future<void> Function() onAllow, {
      String label = 'Allow',
    }) => ORow(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: granted
          ? Padding(
              padding: const EdgeInsets.all(OSpace.sm),
              child: Icon(LucideIcons.circleCheck, color: t.positive),
            )
          : OButton(label: label, variant: OButtonVariant.secondary, size: OButtonSize.sm, onPressed: onAllow),
    );

    return OSheetBody(
      title: 'Your money stays on this phone',
      subtitle: 'One Tracker builds your spending from the payment alerts you already get. No sign-up, no account.',
      actions: [
        OButton(label: 'Continue', size: OButtonSize.lg, expand: true, onPressed: () => Navigator.pop(context)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          point(
            LucideIcons.wifiOff,
            'No internet access',
            'The app can\'t go online, so nothing is uploaded, sold or shared.',
          ),
          point(
            LucideIcons.shieldCheck,
            'Only payment alerts',
            'Other messages and notifications are skipped and never stored.',
          ),
          point(LucideIcons.slidersHorizontal, 'You stay in control', 'Turn any access off in Settings, any time.'),
          OSectionHeader('What it can read', top: OSpace.xl),
          OGroup(
            children: [
              access(
                LucideIcons.messageSquareText,
                'Bank SMS',
                'Bank, card and UPI alerts from the last 90 days, and new ones as they arrive',
                app.smsGranted,
                app.requestSms,
                label: app.smsBlocked ? 'Settings' : 'Allow',
              ),
              access(
                LucideIcons.bellRing,
                'Payment notifications',
                'Payments from UPI and bank apps, the moment you pay',
                app.notificationsGranted,
                app.requestNotifications,
              ),
              access(
                LucideIcons.contactRound,
                'Contact photos',
                'Optional. Faces on payments to people you know',
                app.contactsGranted,
                app.requestContacts,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
