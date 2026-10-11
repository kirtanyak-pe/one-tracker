import 'package:intl/intl.dart';

/// "Just now", "12 min ago", "Today, 3:44 PM", "Yesterday, 9:10 AM", "8 Oct".
String friendlyTime(DateTime at, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = DateFormat('h:mm a').format(at);
  if (day == today) return 'Today, $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
  return DateFormat('d MMM').format(at);
}

const _apps = {
  'com.google.android.apps.nbu.paisa.user': 'Google Pay',
  'com.phonepe.app': 'PhonePe',
  'net.one97.paytm': 'Paytm',
  'com.dreamplug.androidapp': 'CRED',
  'in.org.npci.upiapp': 'BHIM',
  'in.amazon.mShop.android.shopping': 'Amazon Pay',
  'com.google.android.apps.messaging': 'SMS',
  'com.samsung.android.messaging': 'SMS',
  'demo': 'Test payment',
  'manual': 'Added by you',
};

/// Friendly name for the app a payment was detected in.
String appLabel(String packageName) => _apps[packageName] ?? 'Bank alert';
