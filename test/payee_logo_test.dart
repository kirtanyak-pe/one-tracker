import 'dart:io';
import 'dart:typed_data';

import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/ui/components.dart';
import 'package:auto_split/ui/payee_logo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/onyx.dart';

/// A real 1x1 PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Enriched _pay(String body, {Source source = Source.sms, String sender = 'VM-HDFCBK'}) {
  final txns = ingest(const [], [
    RawMessage(source: source, sourceId: 'x', sender: sender, body: body, at: DateTime(2026, 10, 6)),
  ]).txns;
  return enrich(txns).items.single;
}

void main() {
  group('PayeeBrands.forText', () {
    const cases = {
      'Swiggy': 'in.swiggy.android',
      'SWIGGY*INSTAMART': 'in.swiggy.android',
      'Zomato Ltd': 'com.application.zomato',
      'blinkit.payu': 'com.grofers.customerapp',
      'Grofers India': 'com.grofers.customerapp',
      'Zepto': 'com.zeptoconsumerapp',
      'Big Basket': 'com.bigbasket.mobileapp',
      'Amazon Seller Services': 'in.amazon.mShop.android.shopping',
      'Amazon Pay': 'in.amazon.mShop.android.shopping',
      'Flipkart Internet': 'com.flipkart.android',
      'Uber India': 'com.ubercab',
      'Ola': 'com.olacabs.customer',
      'IRCTC': 'cris.org.in.prs.ima',
      'BookMyShow': 'com.bt.bms',
      'Netflix': 'com.netflix.mediaclient',
      'Google Play': 'com.android.vending',
      'Google Pay': 'com.google.android.apps.nbu.paisa.user',
      'PhonePe': 'com.phonepe.app',
      'Paytm Payments Bank': 'net.one97.paytm',
      'CRED': 'com.dreamplug.androidapp',
      'Bharti Airtel': 'com.myairtelapp',
      'Reliance Jio': 'com.jio.myjio',
      'JioMart': 'com.jpl.jiomart',
      'Zerodha Broking': 'com.zerodha.kite3',
      'HDFC Bank Credit Card': 'com.snapwork.hdfc',
    };
    cases.forEach((text, package) {
      test('$text -> $package', () => expect(PayeeBrands.forText(text).first, package));
    });

    test('people and unknown shops get nothing', () {
      for (final text in [
        'Ramesh Kumar',
        'Lola Montez',
        'Olaf',
        'Kuber Stores',
        'Navi Mumbai Traders',
        '',
        'Rahul S',
      ]) {
        expect(PayeeBrands.forText(text), isEmpty, reason: text);
      }
    });
  });

  group('PayeeBrands.forEnriched', () {
    test('matches the UPI id name, not the handle', () {
      final swiggy = _pay('Rs.250 debited from A/c XX4821 to VPA swiggy@icici');
      expect(PayeeBrands.forEnriched(swiggy), ['in.swiggy.android']);
      // "@paytm" is the person's wallet handle, not the merchant.
      final person = _pay('Rs.250 debited from A/c XX4821 to VPA rahul.sharma@paytm');
      expect(PayeeBrands.forEnriched(person), isEmpty);
    });

    test('payment-app badge only for notifications from a known payment app', () {
      const gpay = 'com.google.android.apps.nbu.paisa.user';
      final fromGpay = _pay('Paid Rs.250 to Zomato', source: Source.notification, sender: gpay);
      expect(PayeeBrands.paymentApp(fromGpay.txn), gpay);
      expect(PayeeBrands.wanted(fromGpay), ['com.application.zomato', gpay]);

      final sms = _pay('Rs.250 debited from A/c XX4821 to VPA zomato@icici');
      expect(PayeeBrands.paymentApp(sms.txn), isNull);

      final smsApp = _pay(
        'Rs.250 debited from A/c XX4821 to VPA zomato@icici',
        source: Source.notification,
        sender: 'com.google.android.apps.messaging',
      );
      expect(PayeeBrands.paymentApp(smsApp.txn), isNull);
    });
  });

  test('every package is declared in AndroidManifest <queries>', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final missing = allLogoPackages.where((p) => !manifest.contains('<package android:name="$p"')).toList();
    expect(missing, isEmpty);
    expect(allLogoPackages.length, greaterThan(50));
  });

  group('PayeeAvatar', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      OApp(
        title: 'test',
        mode: OThemeMode.light,
        home: Center(child: child),
      ),
    );

    tearDown(() {
      PayeeLogos.enabled = true;
      PayeeLogos.fetcher = null;
      PayeeLogos.instance.reset();
    });

    testWidgets('falls back to the category icon when logos are off (web/tests)', (tester) async {
      PayeeLogos.enabled = false;
      final e = _pay('Rs.250 debited from A/c XX4821 to VPA swiggy@icici');
      await pump(tester, PayeeAvatar(e, size: 44));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(e.category.icon), findsOneWidget);
    });

    testWidgets('by name falls back to initials', (tester) async {
      PayeeLogos.enabled = false;
      await pump(tester, const PayeeAvatar.name('Rahul Sharma'));
      expect(find.text('RS'), findsOneWidget);
      expect(find.byType(Avatar), findsOneWidget);
    });

    testWidgets('unknown payee keeps the fallback even when the channel is on', (tester) async {
      PayeeLogos.enabled = true;
      var calls = 0;
      PayeeLogos.fetcher = (p) async {
        calls++;
        return {};
      };
      final e = _pay('Rs.250 debited from A/c XX4821 to VPA ramesh.kumar@oksbi');
      await pump(tester, PayeeAvatar(e));
      await tester.pump();
      expect(calls, 0);
      expect(find.byIcon(e.category.icon), findsOneWidget);
    });

    testWidgets('shows the real logo once its icon arrives; one batched request', (tester) async {
      PayeeLogos.enabled = true;
      final asked = <List<String>>[];
      PayeeLogos.fetcher = (packages) async {
        asked.add(packages);
        return {'in.swiggy.android': _png};
      };
      final a = _pay('Rs.250 debited from A/c XX4821 to VPA swiggy@icici');
      final b = _pay('Rs.99 debited from A/c XX4821 to VPA swiggy@icici');
      await pump(tester, Column(children: [PayeeAvatar(a), PayeeAvatar(b)]));
      // Fallback until the icon is in.
      expect(find.byIcon(a.category.icon), findsNWidgets(2));
      await tester.pump();
      await tester.pump();
      expect(asked, hasLength(1));
      expect(asked.single, ['in.swiggy.android']);
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.byIcon(a.category.icon), findsNothing);
    });

    testWidgets('a notification from a payment app adds its icon as a corner badge', (tester) async {
      PayeeLogos.enabled = true;
      const gpay = 'com.google.android.apps.nbu.paisa.user';
      PayeeLogos.fetcher = (_) async => {'com.application.zomato': _png, gpay: Uint8List.fromList(_png)};
      final e = _pay('Paid Rs.250 to Zomato', source: Source.notification, sender: gpay);
      await pump(tester, PayeeAvatar(e));
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('unknown payee paid through a payment app: fallback icon + badge', (tester) async {
      PayeeLogos.enabled = true;
      const phonepe = 'com.phonepe.app';
      PayeeLogos.fetcher = (_) async => {phonepe: _png};
      final e = _pay('Paid Rs.250 to Ramesh Kumar', source: Source.notification, sender: phonepe);
      await pump(tester, PayeeAvatar(e));
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(e.category.icon), findsOneWidget);
    });
  });
}
