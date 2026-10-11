import 'package:intl/intl.dart';

/// Bank SMS here are in rupees.
const appCurrency = 'INR';

/// Money is kept in minor units (paise / cents) as ints to avoid float drift.

/// "1,250.5" → 125050. Returns null for anything that isn't a positive amount.
int? parseMinor(String input) {
  final cleaned = input.replaceAll(',', '').trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final minor = whole * 100 + int.parse(fraction);
  return minor > 0 ? minor : null;
}

/// 125050 → "1250.50" (the format Splitwise expects for `cost` and shares).
String minorToDecimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

/// 125050 → "₹1,250.50", 45000 → "₹450" for display. [round] drops paise
/// (hero numbers: "₹1,34,174").
String formatMoney(int minor, String currency, {bool round = false}) {
  final value = round ? (minor / 100).round() * 100 : minor;
  final format = NumberFormat.simpleCurrency(
    locale: currency == 'INR' ? 'en_IN' : 'en_US',
    name: currency,
    decimalDigits: value % 100 == 0 ? 0 : 2,
  );
  return format.format(value / 100);
}

/// Short amounts for chart labels: ₹850, ₹1.2k, ₹45k, ₹1.3L, ₹2.1Cr.
String formatCompact(int minor) {
  final rupees = minor / 100;
  String trim(double v) => v >= 10 ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.0', '');
  if (rupees >= 10000000) return '₹${trim(rupees / 10000000)}Cr';
  if (rupees >= 100000) return '₹${trim(rupees / 100000)}L';
  if (rupees >= 1000) return '₹${trim(rupees / 1000)}k';
  return '₹${rupees.round()}';
}
