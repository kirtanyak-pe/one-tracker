import '../model/transaction.dart';
import '../money.dart';

/// Bump when parsing changes, so stored payments get re-parsed once.
const parserVersion = 4;

/// Facts pulled out of one bank SMS or payment-app notification.
class Parsed {
  const Parsed({
    required this.direction,
    required this.amountMinor,
    this.counterparty,
    this.vpa,
    this.account,
    this.otherAccount,
    this.ref,
    this.kindHint,
    this.atm = false,
    this.refund = false,
    this.selfHint = false,
  });

  final Direction direction;
  final int amountMinor;
  final String? counterparty;
  final String? vpa;
  final String? account;
  final String? otherAccount;
  final String? ref;
  final CounterpartyKind? kindHint;
  final bool atm;
  final bool refund;

  /// The bank itself called it a self / own-account transfer.
  final bool selfHint;
}

RegExp _re(String pattern) => RegExp(pattern, caseSensitive: false);

final _amount = _re(r'(?:₹|\brs\.?|\binr)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)');

// "debited by 500.0" (SBI style, no currency before the number).
final _bareAmount = _re(r'\b(?:debited|credited)\s+(?:by|with|for)\s+([0-9][0-9,]*(?:\.[0-9]{1,2})?)');

final _debit = _re(r'\b(debited|paid|spent|sent|withdrawn|withdrawal|purchase|payment of|txn of|transferred to|trf to|dr\b)');
final _credit = _re(r'\b(credited|received|deposited|refund(?:ed)?|reversed|reversal|cr\b)');

/// Mentions money but isn't a completed transaction.
final _noise = _re(
  r'\b(otp|one time password|verification code|requested|requesting|request|'
  r'is due|due on|due date|reminder|will be debited|will be auto|scheduled|'
  r'autopay (?:set|registered|mandate)|e-?mandate|failed|declined|unsuccessful|'
  r'offer|cashback of up to|eligible|pre-?approved|loan of|emi of rs|statement|'
  r'min(?:imum)? amount|total amount due|bill generated)\b',
);

final _account = _re(r'(?:a/?c|acct|account|card)(?:\s*(?:no\.?|number|ending(?: with)?))?\s*[:.]?\s*(?:[x*•.]+\s*)?(\d{3,6})\b');
final _vpa = _re(r'\b([a-z0-9][a-z0-9._-]{1,48}@[a-z][a-z0-9]{1,20})\b');
final _ref = _re(r'\b(?:upi\s*ref(?:\s*no)?|ref(?:erence)?\s*(?:no|number|#)?|utr|rrn|txn\s*id|imps\s*ref)[\s.:#-]*([a-z0-9]{6,})');

final _p2m = _re(r'\bupi[/-]p2m\b');
final _p2a = _re(r'\bupi[/-]p2[ap]\b');

/// Bank "UPI/P2A/123456/RAHUL SHARMA/..." strings.
final _upiString = _re(r'\bupi[/-]p2[amp][/-]\d+[/-]([a-z][a-z .]*[a-z])');

final _selfWords = _re(r'\b(self[ -]?transfer|to self|own account|between your accounts|to your own)\b');

const _stop = r'(?=\s+(?:on|via|using|from|ref|refno|upi|for|with|avl|bal|was|is|has|successful|thru|through|at|dated|txn|info|-)\b|[.,;!\n(]|$)';

final _counterpartyDebit = [
  _re('\\b(?:trf|transfer(?:red)?)\\s+to\\s+([A-Za-z][^.,;!\\n(]*?)$_stop'),
  _re('\\bat\\s+([A-Za-z][^.,;!\\n(]*?)$_stop'),
  _re('\\b(?:paid|sent|payment)\\b[^\\n]*?\\bto\\s+([A-Za-z][^.,;!\\n(]*?)$_stop'),
  _re('\\bto\\s+([A-Za-z][^.,;!\\n(]*?)$_stop'),
  _re(r';\s*([A-Z][A-Z .]{2,40}?)\s+credited\b'),
];

final _counterpartyCredit = [
  _re('\\b(?:from|by)\\s+([A-Za-z][^.,;!\\n(]*?)$_stop'),
];

final _notAName = _re(r'^(?:your|you|a/?c|ac|acct|account|card|vpa|upi|the|self|bank|beneficiary|mobile|net ?banking|imps|neft|rtgs|rs|inr|amount|amt)\b');

/// Parses a bank SMS / payment notification. Null when it isn't a completed
/// debit or credit.
Parsed? parseMessage(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_noise.hasMatch(t)) return null;

  final debitAt = _debit.firstMatch(t)?.start;
  final creditAt = _credit.firstMatch(t)?.start;
  if (debitAt == null && creditAt == null) return null;
  // Earliest verb wins: "debited from your a/c … credited to VPA x" is a debit.
  final direction = creditAt == null || (debitAt != null && debitAt < creditAt)
      ? Direction.debit
      : Direction.credit;

  final amountText = _amount.firstMatch(t)?.group(1) ?? _bareAmount.firstMatch(t)?.group(1);
  final amount = amountText == null ? null : parseMinor(amountText);
  if (amount == null) return null;

  final accounts = _account.allMatches(t).map((m) => _last4(m.group(1)!)).toSet().toList();
  final vpa = _vpa.firstMatch(t)?.group(1)?.toLowerCase();

  CounterpartyKind? hint;
  if (_p2m.hasMatch(t)) hint = CounterpartyKind.merchant;
  if (_p2a.hasMatch(t)) hint = CounterpartyKind.person;

  return Parsed(
    direction: direction,
    amountMinor: amount,
    counterparty: _counterparty(t, direction, vpa),
    vpa: vpa,
    account: accounts.firstOrNull,
    otherAccount: accounts.length > 1 ? accounts[1] : null,
    ref: _ref.firstMatch(t)?.group(1),
    kindHint: hint,
    atm: _re(r'\batm\b|cash withdrawal').hasMatch(t),
    refund: _re(r'\b(refund(?:ed)?|reversed|reversal)\b').hasMatch(t),
    selfHint: _selfWords.hasMatch(t),
  );
}

String _last4(String digits) => digits.length > 4 ? digits.substring(digits.length - 4) : digits;

String? _counterparty(String t, Direction direction, String? vpa) {
  final upi = _upiString.firstMatch(t)?.group(1);
  if (upi != null && _usable(upi)) return tidyName(upi);

  final patterns = direction == Direction.debit ? _counterpartyDebit : _counterpartyCredit;
  for (final p in patterns) {
    // Try every hit: "by NEFT from ACME TECH" skips "NEFT", takes "ACME TECH".
    for (final m in p.allMatches(t)) {
      final raw = m.group(1)!.trim();
      if (!_usable(raw)) continue;
      if (raw.contains('@')) return nameFromVpa(raw);
      return tidyName(raw);
    }
  }
  return vpa == null ? null : nameFromVpa(vpa);
}

/// Whether [name] passes today's payee-name rules (used when re-parsing).
bool isUsableName(String name) => _usable(name);

bool _usable(String raw) =>
    raw.trim().length >= 2 && !_notAName.hasMatch(raw.trim()) && RegExp(r'[A-Za-z]{2}').hasMatch(raw);

/// "swiggy@icici" → "Swiggy", "rahul.sharma@okaxis" → "Rahul Sharma",
/// "9876543210@ybl" → "9876543210".
String nameFromVpa(String vpa) {
  final full = vpa.split('@').first;
  for (final entry in _qrMerchants.entries) {
    if (entry.key.hasMatch(full)) return entry.value;
  }
  final words = full
      .replaceAll(RegExp(r'\d{6,}$'), '')
      .split(RegExp(r'[._-]+'))
      // "blinkit.payu" → "blinkit": drop payment-gateway tags.
      .where((w) => w.isNotEmpty && !_gatewayTags.contains(w))
      .toList();
  if (words.isEmpty) return full;
  return tidyName(words.join(' '));
}

final _qrMerchants = {
  RegExp(r'^paytmqr'): 'Paytm QR merchant',
  RegExp(r'^bharatpe'): 'BharatPe merchant',
  RegExp(r'^gpay-\d'): 'Google Pay merchant',
  RegExp(r'^q\d{6,}$'): 'QR merchant',
};

const _gatewayTags = {
  'payu', 'rzp', 'razorpay', 'cf', 'cashfree', 'billdesk', 'upi', 'mer', 'pg',
  'payments', 'pay', 'online', 'ccavenue', 'juspay', 'easebuzz',
};

/// "AMAZON PAY INDIA" → "Amazon Pay India"; mixed case kept; trimmed to 40.
String tidyName(String raw) {
  var name = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.length > 40) name = name.substring(0, 40).trim();
  final shouty = name == name.toUpperCase() || name == name.toLowerCase();
  if (!shouty) return name;
  return name.split(' ').map((w) {
    if (w.length <= 1 || _acronyms.contains(w.toUpperCase())) return w.toUpperCase();
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

const _acronyms = {
  'ATM', 'SBI', 'HDFC', 'ICICI', 'PNB', 'BOB', 'IDFC', 'IDBI', 'UPI', 'NEFT', 'IMPS', 'RTGS',
  'KFC', 'LIC', 'IRCTC', 'BSNL', 'DTH', 'HPCL', 'BPCL', 'IOCL', 'PVR', 'OYO', 'ACT', 'EMI',
  'GST', 'NSE', 'BSE', 'SIP', 'BMTC', 'BEST', 'DMRC', 'IGL', 'MGL', 'BBMP',
};
