import '../money.dart';
import 'detected_payment.dart';

class ParsedPayment {
  const ParsedPayment(this.amountMinor, this.merchant);

  final int amountMinor;
  final String? merchant;
}

final _amount = RegExp(
  r'(?:₹|\brs\.?|\binr)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
  caseSensitive: false,
);

final _debit = RegExp(
  r'\b(debited|paid|spent|sent|payment of|withdrawn|purchase|txn of)\b',
  caseSensitive: false,
);

/// Things that mention money but aren't a payment you just made.
final _notAPayment = RegExp(
  r'\b(otp|one time password|credited to your|received|refund|cashback|'
  r'requested|requesting|due|reminder|will be debited|autopay|auto-pay)\b',
  caseSensitive: false,
);

// Tried in order; first hit wins. Merchants must start with a letter so
// "at 10:30" or "to A/c 1234"-style noise is skipped.
const _stop = r'(?=\s+(?:on|via|using|from|ref|upi|for|with|avl|bal|was|is|has|successful)\b|[.,;!\n]|$)';
final _merchantPatterns = [
  RegExp(r'\bto\s+vpa\s+([a-z0-9._-]+)@', caseSensitive: false),
  RegExp('\\bat\\s+([A-Za-z][^.,;!\\n]*?)$_stop', caseSensitive: false),
  RegExp('\\bto\\s+([A-Za-z][^.,;!\\n]*?)$_stop', caseSensitive: false),
];

/// Pulls a debit out of a bank SMS / UPI app notification, or returns null.
ParsedPayment? parsePayment(String text) {
  if (!_debit.hasMatch(text) || _notAPayment.hasMatch(text)) return null;
  final amountMatch = _amount.firstMatch(text);
  if (amountMatch == null) return null;
  final amount = parseMinor(amountMatch.group(1)!);
  if (amount == null) return null;
  return ParsedPayment(amount, _merchant(text));
}

String? _merchant(String text) {
  for (final pattern in _merchantPatterns) {
    final raw = pattern.firstMatch(text)?.group(1)?.trim();
    if (raw == null || raw.isEmpty) continue;
    if (RegExp(r'^(your|you|a/c|ac|account|card)\b', caseSensitive: false).hasMatch(raw)) {
      continue;
    }
    return _tidy(raw);
  }
  return null;
}

/// "AMAZON PAY" / "swiggy" → "Amazon Pay" / "Swiggy"; mixed case left alone.
String _tidy(String raw) {
  final name = raw.length > 40 ? raw.substring(0, 40).trim() : raw;
  final shouty = name == name.toUpperCase() || name == name.toLowerCase();
  if (!shouty) return name;
  return name
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// One UPI payment often fires both the UPI app's and the bank's
/// notification. Treat same amount within two minutes as the same payment.
bool isDuplicate(ParsedPayment parsed, DateTime at, Iterable<DetectedPayment> recent) =>
    recent.any((p) =>
        p.amountMinor == parsed.amountMinor &&
        at.difference(p.detectedAt).abs() < const Duration(minutes: 2));
