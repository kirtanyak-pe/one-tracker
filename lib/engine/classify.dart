import '../model/category.dart';
import '../model/transaction.dart';

/// Stable key for a payee, so rules survive "SWIGGY" vs "Swiggy Ltd" vs
/// "swiggy@icici".
String payeeKey(Txn t) {
  final handle = t.vpa?.split('@').first;
  // QR codes and phone-number UPI ids are unique; their display names
  // ("Paytm QR merchant") are not.
  if (handle != null && RegExp(r'\d{6,}').hasMatch(handle)) return 'vpa:$handle';
  final base = (t.counterparty ?? handle ?? '').toLowerCase();
  return base
      .replaceAll(RegExp(r'\b(pvt|private|ltd|limited|india|llp|inc|co)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

const _merchantWords = [
  'pvt', 'ltd', 'limited', 'llp', 'store', 'stores', 'mart', 'foods', 'food',
  'services', 'enterprises', 'restaurant', 'cafe', 'traders', 'retail',
  'technologies', 'solutions', 'shop', 'medical', 'pharmacy', 'hospital',
  'bakery', 'kitchen', 'hotel', 'petroleum', 'fuels', 'motors', 'agency',
  'industries', 'payments', 'online', 'digital', 'super', 'market', 'bazaar',
];

final _merchantVpa = RegExp(
  r'paytmqr|bharatpe|razorpay|rzp|^cf\.|pinelabs|mswipe|merchant|ezetap|'
  r'gpay-|yespay|^q\d|payu|cashfree|billdesk|ccavenue|\.mer@|ibkpos',
);

/// Merchant, person, or can't tell.
CounterpartyKind counterpartyKind(Txn t) {
  if (t.kindHint != null) return t.kindHint!;
  final name = (t.counterparty ?? '').toLowerCase();
  final vpa = t.vpa ?? '';
  if (categoryFromKeywords('$name ${vpa.split('@').first}') != null) {
    return CounterpartyKind.merchant;
  }
  if (_merchantVpa.hasMatch(vpa)) return CounterpartyKind.merchant;
  if (RegExp(r'^\d{10}@').hasMatch(vpa)) return CounterpartyKind.person;
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.any(_merchantWords.contains)) return CounterpartyKind.merchant;
  // Two or three plain words reads like a name: "Rahul Sharma", "Meera K".
  if (words.length >= 2 && words.length <= 3 && words.every((w) => RegExp(r'^[a-z]+$').hasMatch(w))) {
    return CounterpartyKind.person;
  }
  return CounterpartyKind.unknown;
}

const _keywords = <Category, List<String>>{
  Category.food: [
    'swiggy', 'zomato', 'domino', 'pizza', 'mcdonald', 'kfc', 'burger', 'starbucks',
    'cafe', 'coffee', 'chai', 'restaurant', 'biryani', 'eatfit', 'box8', 'faasos',
    'haldiram', 'bakery', 'third wave', 'blue tokai', 'dunkin', 'subway', 'eatclub',
    'chaayos', 'barbeque', 'kitchen', 'dhaba', 'food',
  ],
  Category.groceries: [
    'blinkit', 'zepto', 'bigbasket', 'instamart', 'dmart', 'jiomart', 'grofers',
    'reliance fresh', 'nature basket', 'milkbasket', 'dunzo', 'country delight',
    'licious', 'supermarket', 'kirana', 'more retail', 'spar', 'freshtohome',
  ],
  Category.transport: [
    'uber', 'ola', 'rapido', 'metro', 'fastag', 'petrol', 'fuel', 'hpcl', 'bpcl',
    'indian oil', 'iocl', 'shell', 'parking', 'namma yatri', 'blusmart', 'bmtc',
    'best bus', 'toll',
  ],
  Category.shopping: [
    'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'croma', 'decathlon',
    'ikea', 'tata cliq', 'lenskart', 'zara', 'uniqlo', 'reliance digital',
    'reliance trends', 'westside', 'pantaloons', 'snapdeal', 'firstcry', 'h&m',
  ],
  Category.bills: [
    'airtel', 'jio', 'vodafone', 'bsnl', 'electricity', 'bescom', 'tata power',
    'adani', 'mahanagar gas', 'indane', 'bharat gas', 'broadband', 'act fibernet',
    'recharge', 'insurance', 'lic', 'postpaid', 'dth', 'tata play', 'water bill',
    'maintenance', 'rent', 'nobroker', 'cred', 'bill',
  ],
  Category.entertainment: [
    'netflix', 'spotify', 'prime video', 'hotstar', 'bookmyshow', 'pvr', 'inox',
    'youtube', 'apple music', 'steam', 'playstation', 'sonyliv', 'zee5', 'jiocinema',
    'district', 'paytm insider',
  ],
  Category.health: [
    'apollo', 'pharmeasy', '1mg', 'netmeds', 'medplus', 'hospital', 'clinic',
    'pharmacy', 'practo', 'cult.fit', 'cultfit', 'gym', 'diagnostic', 'medical',
    'healthkart',
  ],
  Category.travel: [
    'makemytrip', 'goibibo', 'irctc', 'indigo', 'air india', 'vistara', 'akasa',
    'spicejet', 'cleartrip', 'oyo', 'airbnb', 'booking.com', 'yatra', 'redbus',
    'ixigo', 'agoda', 'zostel',
  ],
};

/// Built once: short words must match whole ("ola" ≠ "motorola", "lic" ≠
/// "police"), longer ones as substrings.
final _matchers = [
  for (final entry in _keywords.entries)
    for (final word in entry.value)
      (
        category: entry.key,
        word: word,
        whole: word.length <= 4 ? RegExp('[^a-z]${RegExp.escape(word)}[^a-z]') : null,
      ),
];

/// Category from merchant words, or null if nothing matched.
Category? categoryFromKeywords(String text) {
  final hay = ' ${text.toLowerCase()} ';
  for (final m in _matchers) {
    if (m.whole != null ? m.whole!.hasMatch(hay) : hay.contains(m.word)) return m.category;
  }
  return null;
}

/// Category before any user rule or override.
Category autoCategory(Txn t, {required bool atm}) {
  if (t.direction == Direction.credit) return Category.income;
  if (atm) return Category.cash;
  final keyword = categoryFromKeywords('${t.counterparty ?? ''} ${t.vpa?.split('@').first ?? ''}');
  if (keyword != null) return keyword;
  if (counterpartyKind(t) == CounterpartyKind.person) return Category.people;
  return Category.other;
}
