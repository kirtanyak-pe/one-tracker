import 'package:intl/intl.dart';

import '../model/transaction.dart';

/// "Just now", "12 min ago", "Today, 3:44 PM", "Yesterday, 9:10 AM", "8 Oct".
String friendlyTime(DateTime at, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1 && !diff.isNegative) return 'Just now';
  if (diff.inMinutes < 60 && !diff.isNegative) return '${diff.inMinutes} min ago';
  final day = dayLabel(at, now: now);
  final time = DateFormat('h:mm a').format(at);
  return '$day, $time';
}

/// "Today", "Yesterday", "Mon, 6 Oct".
String dayLabel(DateTime at, {DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(at);
}

String monthLabel(DateTime month) => DateFormat('MMMM yyyy').format(month);
String monthName(DateTime month) => DateFormat('MMMM').format(month);

const _apps = {
  'com.google.android.apps.nbu.paisa.user': 'Google Pay',
  'com.phonepe.app': 'PhonePe',
  'net.one97.paytm': 'Paytm',
  'com.dreamplug.androidapp': 'CRED',
  'in.org.npci.upiapp': 'BHIM',
  'in.amazon.mShop.android.shopping': 'Amazon Pay',
  'com.google.android.apps.messaging': 'Messages',
  'com.samsung.android.messaging': 'Messages',
};

/// Where a transaction came from, for the detail screen.
String sourceLabel(Txn t) => switch (t.source) {
      Source.sms => 'Bank SMS · ${t.sender ?? ''}',
      Source.notification => '${_apps[t.sender] ?? 'App'} notification',
      Source.manual => 'Added by you',
      Source.sample => 'Sample SMS · ${t.sender ?? ''}',
    };
