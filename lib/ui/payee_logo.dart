import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../engine/enrich.dart';
import '../model/category.dart';
import '../model/transaction.dart';
import 'components.dart';

import 'package:onyx/onyx.dart';

/// Real logos without bundling or downloading any: the launcher icon of the
/// merchant's (or payment app's) app, if it is installed on this phone.
///
/// [PayeeBrands] decides which package a payee maps to (pure, testable);
/// [PayeeLogos] fetches and caches the icons through the native channel;
/// [PayeeAvatar] draws them.

/// One merchant: a pattern over the normalised payee text, and the package(s)
/// whose icon is its logo (first installed wins).
class _Brand {
  _Brand(String pattern, this.packages) : re = RegExp(pattern);

  final RegExp re;
  final List<String> packages;
}

/// Merchant keywords -> app packages. Order matters: first match wins, so
/// specific names come before general ones ("google play" before "google").
///
/// Every package here must also be listed in AndroidManifest.xml `<queries>`
/// (test/payee_logo_test.dart checks that). Entries marked `unsure` are from
/// memory and harmless if wrong: a package that isn't installed just means
/// no logo.
final _brands = <_Brand>[
  // Food and groceries
  _Brand(r'\b(swiggy|instamart)', ['in.swiggy.android']),
  _Brand(r'\bzomato', ['com.application.zomato']),
  _Brand(r'\b(blinkit|grofers)', ['com.grofers.customerapp']),
  _Brand(r'\bzepto', ['com.zeptoconsumerapp']),
  _Brand(r'\bbig ?basket', ['com.bigbasket.mobileapp']),
  _Brand(r'\bjio ?mart', ['com.jpl.jiomart']),
  _Brand(r'\bd ?mart', ['com.dmartindia.customerapp', 'in.dmart.ready']), // unsure
  _Brand(r'\blicious', ['com.licious']),
  _Brand(r'^district( app| by zomato)?$', ['in.district.app', 'com.zomato.district']), // unsure
  _Brand(r'\bdomino', ['com.Dominos']), // unsure
  // Shopping
  _Brand(r'\bamazon prime|\bprime video', ['com.amazon.avod.thirdpartyclient']),
  _Brand(r'\bkindle', ['com.amazon.kindle']),
  _Brand(r'\bamazon', ['in.amazon.mShop.android.shopping', 'com.amazon.mShop.android.shopping']),
  _Brand(r'\bflipkart', ['com.flipkart.android']),
  _Brand(r'\bmyntra', ['com.myntra.android']),
  _Brand(r'\bajio', ['com.ril.ajio']),
  _Brand(r'\bnykaa', ['com.fsn.nykaa']),
  _Brand(r'\bmeesho', ['com.meesho.supply']),
  _Brand(r'\btata ?cliq', ['com.tul.tatacliq']),
  _Brand(r'\btata neu\b', ['com.tatadigital.tcp']),
  _Brand(r'\blenskart', ['com.lenskart.app']),
  // Travel and rides
  _Brand(r'\buber\b', ['com.ubercab']),
  _Brand(r'\bola( cabs| money| consumer)?\b', ['com.olacabs.customer']),
  _Brand(r'\brapido', ['com.rapido.passenger']),
  _Brand(r'\bnamma yatri', ['in.juspay.nammayatri']),
  _Brand(r'\birctc', ['cris.org.in.prs.ima']),
  _Brand(r'\bmake ?my ?trip', ['com.makemytrip']),
  _Brand(r'\bgoibibo', ['com.goibibo']),
  _Brand(r'\bred ?bus', ['in.redbus.android']),
  _Brand(r'\bixigo', ['com.ixigo.train.ixitrain', 'com.ixigo']), // unsure
  _Brand(r'\bcleartrip', ['com.cleartrip.android']),
  _Brand(r'\bairbnb', ['com.airbnb.android']),
  // Entertainment and subscriptions
  _Brand(r'\bbook ?my ?show', ['com.bt.bms']),
  _Brand(r'\bnetflix', ['com.netflix.mediaclient']),
  _Brand(r'\bspotify', ['com.spotify.music']),
  _Brand(r'\b(jio ?)?hotstar', ['in.startv.hotstar']),
  _Brand(r'\bsony ?liv', ['com.sonyliv']),
  _Brand(r'\bzee ?5', ['com.graymatrix.did']),
  _Brand(r'\bjio ?(cinema|saavn)', ['com.jio.media.ondemand', 'com.jio.media.jiobeats']),
  _Brand(r'\byou ?tube', ['com.google.android.youtube']),
  _Brand(r'\bgoogle play', ['com.android.vending']),
  _Brand(r'\bgoogle one', ['com.google.android.apps.subscriptions.red']),
  _Brand(r'\b(chat ?gpt|openai)', ['com.openai.chatgpt']),
  _Brand(r'\banthropic', ['com.anthropic.claude']),
  _Brand(r'\blinkedin', ['com.linkedin.android']),
  // Telecom
  _Brand(r'\bairtel', ['com.myairtelapp']),
  _Brand(r'\bjio\b', ['com.jio.myjio']),
  _Brand(r'\bvodafone', ['com.mventus.selfcare.activity']), // unsure
  // Payment apps and wallets
  _Brand(r'\bphone ?pe\b', ['com.phonepe.app']),
  _Brand(r'\b(google ?pay|gpay)\b', ['com.google.android.apps.nbu.paisa.user']),
  _Brand(r'\bpaytm', ['net.one97.paytm']),
  _Brand(r'\bcred\b|\bcred club', ['com.dreamplug.androidapp']),
  _Brand(r'\bbhim\b', ['in.org.npci.upiapp']),
  _Brand(r'\bmobikwik', ['com.mobikwik_new']),
  _Brand(r'\bfreecharge', ['com.freecharge.android']),
  _Brand(r'\bbharat ?pe\b', ['com.bharatpe.app', 'com.bharatpe.bharatpe']), // unsure
  _Brand(r'\bnavi (technologies|finserv|app|upi|mutual)', ['com.naviapp']),
  _Brand(r'\bsuper ?money', ['money.super.payments']), // unsure
  // Money, investing
  _Brand(r'\bzerodha', ['com.zerodha.kite3']),
  _Brand(r'\bgroww', ['com.nextbillion.groww']),
  _Brand(r'\bupstox', ['in.upstox.app', 'com.rksv.upstox']), // unsure
  _Brand(r'\bangel (one|broking)', ['com.msf.angelmobile']),
  _Brand(r'\bindmoney', ['in.indwealth']),
  _Brand(r'\bsplitwise', ['com.Splitwise.SplitwiseMobile']),
  _Brand(r'\bhdfc bank', ['com.snapwork.hdfc']),
  _Brand(r'\bicici bank', ['com.csam.icici.bank.imobile']),
  _Brand(r'\baxis bank', ['com.axis.mobile']),
  _Brand(r'\bkotak( mahindra)? bank', ['com.msf.kbank.mobile']),
  _Brand(r'\bidfc( first)? bank', ['com.idfcfirstbank.optimus']), // unsure
  // Health, home, everyday
  _Brand(r'\bpracto', ['com.practo.fabric']),
  _Brand(r'\b(tata )?1 ?mg\b', ['com.aranoah.healthkart.plus']),
  _Brand(r'\bpharm ?easy', ['com.phonegap.rxpal']),
  _Brand(r'\burban ?company|\burbanclap', ['com.urbanclap.urbanclap']),
  _Brand(r'\bdunzo', ['com.dunzo.user']),
  _Brand(r'^porter( logistics)?$', ['com.theporter.android.customerapp']), // unsure
];

/// Apps whose notifications announce a payment (UPI, wallets, banks). Their
/// icon is shown as a small badge on the payee avatar. Also listed in
/// `<queries>`. Not included: SMS apps, whose notification is only a carrier
/// for a bank SMS.
const paymentAppPackages = <String>{
  'com.google.android.apps.nbu.paisa.user', // Google Pay
  'com.phonepe.app',
  'net.one97.paytm',
  'in.org.npci.upiapp', // BHIM
  'com.dreamplug.androidapp', // CRED
  'in.amazon.mShop.android.shopping', // Amazon Pay lives in the shopping app
  'com.whatsapp',
  'com.mobikwik_new',
  'com.freecharge.android',
  'com.bharatpe.app', // unsure
  'com.naviapp',
  'money.super.payments', // unsure
  'com.epifi.paisa', // Fi, unsure
  'com.snapwork.hdfc', // HDFC Bank
  'com.csam.icici.bank.imobile', // ICICI iMobile
  'com.sbi.lotusintouch', // SBI YONO
  'com.axis.mobile',
  'com.msf.kbank.mobile', // Kotak
  'com.idfcfirstbank.optimus', // unsure
  'com.yesbank', // unsure
  'com.bankofbaroda.mconnect',
  'com.canarabank.mobility', // unsure
  'com.fedmobile', // Federal Bank, unsure
};

/// Every package the app may ask for.
final Set<String> allLogoPackages = {for (final b in _brands) ...b.packages, ...paymentAppPackages};

/// Payee text -> app packages (pure).
abstract final class PayeeBrands {
  static final _clean = RegExp(r'[^a-z0-9]+');
  static final _memo = <String, List<String>>{};

  /// "Swiggy*Instamart" -> "swiggy instamart".
  static String normalise(String s) => s.toLowerCase().replaceAll(_clean, ' ').trim();

  /// Packages for one piece of text, best first; empty if it's no known brand.
  static List<String> forText(String text) {
    final n = normalise(text);
    if (n.isEmpty) return const [];
    return _memo.putIfAbsent(n, () {
      for (final b in _brands) {
        if (b.re.hasMatch(n)) return b.packages;
      }
      return const [];
    });
  }

  /// Packages for a payment: payee, then the written counterparty, then the
  /// UPI id's name part. The handle after "@" ("@paytm", "@ybl") is the
  /// user's bank/app, not the merchant, so it is ignored.
  static List<String> forEnriched(Enriched e) {
    final vpa = e.txn.vpa;
    for (final field in [e.payee, e.txn.counterparty, if (vpa != null) vpa.split('@').first]) {
      if (field == null) continue;
      final found = forText(field);
      if (found.isNotEmpty) return found;
    }
    return const [];
  }

  /// The payment app that announced a notification-sourced payment (null for
  /// SMS and anything else).
  static String? paymentApp(Txn t) {
    if (t.source != Source.notification) return null;
    final s = t.sender;
    return s != null && paymentAppPackages.contains(s) ? s : null;
  }

  /// All packages worth fetching for [e].
  static Iterable<String> wanted(Enriched e) sync* {
    yield* forEnriched(e);
    final app = paymentApp(e.txn);
    if (app != null) yield app;
  }
}

/// Fetches icons from Android (which also keeps them on disk), remembers them
/// for the session and tells listeners when new ones arrive.
class PayeeLogos extends ChangeNotifier {
  PayeeLogos();

  static final instance = PayeeLogos();

  /// Off on the web and other platforms: avatars fall back to icons.
  static bool enabled = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Replaces the native call (tests).
  @visibleForTesting
  static Future<Map<String, Uint8List>> Function(List<String> packages)? fetcher;

  static const _channel = MethodChannel('auto_spend/sms');
  static const _pixels = 160;

  final _loaded = <String, Uint8List>{};
  final _asked = <String>{};
  final _pending = <String>{};
  bool _scheduled = false;

  Uint8List? bytes(String package) => _loaded[package];

  /// First installed package of [candidates] whose icon is loaded.
  Uint8List? firstLoaded(Iterable<String> candidates) {
    for (final p in candidates) {
      final b = _loaded[p];
      if (b != null) return b;
    }
    return null;
  }

  /// Queues [packages] for the next batch: everything asked for during one
  /// frame goes to Android in a single call, and each package only once.
  void request(Iterable<String> packages) {
    if (!enabled) return;
    for (final p in packages) {
      if (_asked.add(p)) _pending.add(p);
    }
    if (_pending.isNotEmpty && !_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_flush);
    }
  }

  /// Warms the cache for the payments most likely to be on screen.
  void prefetch(Iterable<Enriched> items) {
    if (!enabled) return;
    request([for (final e in items) ...PayeeBrands.wanted(e)]);
  }

  Future<void> _flush() async {
    _scheduled = false;
    final batch = _pending.toList();
    _pending.clear();
    if (batch.isEmpty) return;
    try {
      final got = await (fetcher ?? _fromAndroid)(batch);
      if (got.isNotEmpty) {
        _loaded.addAll(got);
        notifyListeners();
      }
    } on MissingPluginException {
      // No native side (tests, web): stay on the fallback look.
    } on PlatformException {
      _asked.removeAll(batch); // try again on a later build
    }
  }

  static Future<Map<String, Uint8List>> _fromAndroid(List<String> packages) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('appIcons', {'packages': packages, 'size': _pixels});
    return {
      for (final e in (raw ?? const {}).entries)
        if (e.key is String && e.value is Uint8List) e.key! as String: e.value! as Uint8List,
    };
  }

  /// Forgets everything (tests).
  @visibleForTesting
  void reset() {
    _loaded.clear();
    _asked.clear();
    _pending.clear();
  }
}

/// One phone contact that has a photo.
typedef PhoneContact = ({int id, String name, List<String> phones});

/// What a payment says about who was paid: 10-digit numbers (from the UPI id
/// or the counterparty) and names as the bank wrote them. [loose] allows a
/// one-word name to match (People payments and names picked by hand).
typedef ContactQuery = ({List<String> phones, List<String> names, bool loose});

/// Matches payees to contacts — pure, so it is unit-tested.
///
/// A number matches exactly. A name matches when every word the bank wrote is
/// in the contact's name, allowing for banks cutting words short ("RAHUL KUMA")
/// and initials ("R KUMAR"); order, case and punctuation don't matter. A name
/// that fits more than one contact matches none — a wrong face is worse
/// than no face.
abstract final class ContactMatcher {
  static final _number = RegExp(r'(?<!\d)(?:91)?([6-9]\d{9})(?!\d)');
  static final _word = RegExp(r'[a-z]+');

  /// Honorifics and bank filler that are never part of a contact's name.
  static const _filler = {'mr', 'mrs', 'ms', 'miss', 'dr', 'shri', 'smt', 'sri', 'to', 'by', 'upi', 'vpa', 'from'};

  static String? phoneIn(String? text) => text == null ? null : _number.firstMatch(text)?.group(1);

  static List<String> words(String name) => [
    for (final m in _word.allMatches(name.toLowerCase()))
      if (!_filler.contains(m[0])) m[0]!,
  ];

  static int? match(ContactQuery q, List<PhoneContact> contacts) {
    for (final phone in q.phones) {
      final hits = {
        for (final c in contacts)
          if (c.phones.contains(phone)) c.id,
      };
      if (hits.length == 1) return hits.first;
    }
    for (final name in q.names) {
      final want = words(name);
      final full = want.where((w) => w.length > 1).toList();
      if (full.isEmpty || (!q.loose && want.length < 2)) continue;
      int? found;
      var count = 0;
      for (final c in contacts) {
        if (_fits(want, words(c.name))) {
          found = c.id;
          if (++count > 1) break;
        }
      }
      if (count == 1) return found;
    }
    return null;
  }

  /// Every wanted word is used by a different word of the contact's name:
  /// equal, its start (cut short, 3+ letters) or its initial.
  static bool _fits(List<String> want, List<String> have) {
    if (have.isEmpty) return false;
    final free = [...have];
    // Full words first, so an initial can't take the word a full one needs.
    for (final w in [...want]..sort((a, b) => b.length.compareTo(a.length))) {
      final i = free.indexWhere(
        (h) => h == w || (w.length >= 3 && h.startsWith(w)) || (w.length == 1 && h.startsWith(w)),
      );
      if (i < 0) return false;
      free.removeAt(i);
    }
    return true;
  }
}

/// Photos of people you pay, from the phone's contacts (read on the phone,
/// never sent anywhere). The contact list is read once; payees are matched
/// here ([ContactMatcher]) and only matched photos are loaded. Brands never
/// get one.
class ContactPhotos extends ChangeNotifier {
  static final instance = ContactPhotos();

  static bool enabled = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _channel = MethodChannel('auto_spend/sms');

  List<PhoneContact>? _contacts;
  bool _indexing = false;
  final _ids = <String, int?>{};
  final _photos = <int, Uint8List>{};
  final _asked = <int>{};
  final _pending = <int>{};
  bool _scheduled = false;

  /// What to look up for a payment; null for merchants.
  static ContactQuery? queryFor(Enriched e) {
    if (PayeeBrands.forEnriched(e).isNotEmpty) return null;
    final t = e.txn;
    final phones = {?ContactMatcher.phoneIn(t.vpa?.split('@').first), ?ContactMatcher.phoneIn(t.counterparty)}.toList();
    final names = {
      for (final n in [e.payee, t.counterparty])
        if (n != null && n.trim().isNotEmpty && ContactMatcher.phoneIn(n) == null) n.trim(),
    }.toList();
    if (phones.isEmpty && names.isEmpty) return null;
    return (phones: phones, names: names, loose: e.category == Category.people);
  }

  /// What to look up for a name alone (top payees); null for merchants.
  static ContactQuery? queryForName(String name) => PayeeBrands.forText(name).isEmpty && name.trim().isNotEmpty
      ? (phones: const [], names: [name.trim()], loose: false)
      : null;

  /// The photo for [q], once the contacts are read and it matched one.
  Uint8List? photoFor(ContactQuery q) {
    if (!enabled) return null;
    final contacts = _contacts;
    if (contacts == null) {
      _readIndex();
      return null;
    }
    final key = '${q.phones.join(',')}|${q.names.join('|')}|${q.loose}';
    final id = _ids.putIfAbsent(key, () => ContactMatcher.match(q, contacts));
    if (id == null) return null;
    final photo = _photos[id];
    if (photo == null) _request(id);
    return photo;
  }

  /// Contacts access just arrived: read them again for everything on screen.
  void retry() {
    _contacts = null;
    _ids.clear();
    _asked.clear();
    notifyListeners();
  }

  Future<void> _readIndex() async {
    if (_indexing) return;
    _indexing = true;
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('contactIndex');
      _contacts = [
        for (final c in raw ?? const [])
          if (c case {'id': final int id, 'name': final String name, 'phones': final List<Object?> phones})
            (id: id, name: name, phones: phones.whereType<String>().toList()),
      ];
      _ids.clear();
      if (_contacts!.isNotEmpty) notifyListeners();
    } on MissingPluginException {
      _contacts = const []; // No native side (tests, web).
    } on PlatformException {
      // Left unread: the next avatar asks again.
    } finally {
      _indexing = false;
    }
  }

  void _request(int id) {
    if (!_asked.add(id)) return;
    _pending.add(id);
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_flush);
    }
  }

  Future<void> _flush() async {
    _scheduled = false;
    final batch = _pending.toList();
    _pending.clear();
    if (batch.isEmpty) return;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('contactPhotos', {'ids': batch});
      final got = {
        for (final e in (raw ?? const {}).entries)
          if (e.key is int && e.value is Uint8List) e.key! as int: e.value! as Uint8List,
      };
      if (got.isNotEmpty) {
        _photos.addAll(got);
        notifyListeners();
      }
    } on MissingPluginException {
      // No native side (tests, web).
    } on PlatformException {
      _asked.removeAll(batch);
    }
  }
}

/// A payee's avatar: the real logo when its app is installed — full colour, on
/// white, in a circle with a hairline edge — otherwise the quiet fallback
/// (category icon for payments, initials for [PayeeAvatar.name]). People
/// get their contact photo when the phone has one ([ContactPhotos]).
///
/// For payments announced by a payment-app notification, that app's icon sits
/// on the avatar's corner as a badge (the logo itself stays the payee's).
class PayeeAvatar extends StatelessWidget {
  const PayeeAvatar(Enriched this.payment, {super.key, this.size = 44, this.background, this.muted = false})
    : name = null;

  /// By name only (e.g. top payees): initials fallback, no badge.
  const PayeeAvatar.name(String this.name, {super.key, this.size = 40})
    : payment = null,
      background = null,
      muted = false;

  final Enriched? payment;
  final String? name;
  final double size;

  /// Fallback circle colour (default: tray).
  final Color? background;

  /// Fallback icon in the muted colour (excluded payments).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final logos = PayeeLogos.instance;
    final e = payment;
    final candidates = e != null ? PayeeBrands.forEnriched(e) : PayeeBrands.forText(name!);
    final app = e != null ? PayeeBrands.paymentApp(e.txn) : null;
    if (candidates.isNotEmpty || app != null) logos.request([...candidates, ?app]);
    final photos = ContactPhotos.instance;
    final people = !ContactPhotos.enabled
        ? null
        : e != null
        ? ContactPhotos.queryFor(e)
        : ContactPhotos.queryForName(name!);
    if (!PayeeLogos.enabled || (candidates.isEmpty && app == null && people == null)) return _fallback(context);
    return ListenableBuilder(
      listenable: Listenable.merge([logos, photos]),
      builder: (context, _) {
        // Looked up here so a retry (contacts just allowed) looks again.
        final logo = logos.firstLoaded(candidates) ?? (people == null ? null : photos.photoFor(people));
        final badge = app == null ? null : logos.bytes(app);
        if (logo == null && badge == null) return _fallback(context);
        final avatar = logo != null ? _LogoDisc(logo, size) : _fallback(context);
        // The app's own icon is the logo already: no second copy as a badge.
        if (badge == null || identical(badge, logo)) return avatar;
        final badgeSize = size * 0.44;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -badgeSize * 0.12,
                bottom: -badgeSize * 0.12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
                  child: Padding(padding: const EdgeInsets.all(1.5), child: _LogoDisc(badge, badgeSize - 3)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final e = payment;
    if (e == null) return Avatar(name!, size: size);
    final t = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? t.raised, shape: BoxShape.circle),
      child: Icon(e.category.icon, size: size * 0.45, color: muted ? t.inkSoft : t.ink),
    );
  }
}

/// A launcher icon, full colour, clipped to a circle on a white base with a
/// hairline edge so white logos still read on light cards.
class _LogoDisc extends StatelessWidget {
  const _LogoDisc(this.bytes, this.size);

  final Uint8List bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: t.ink.withValues(alpha: 0.12)),
      ),
      child: ClipOval(
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: (size * dpr).round(),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
