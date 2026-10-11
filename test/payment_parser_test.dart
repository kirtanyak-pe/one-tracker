import 'package:auto_split/detection/detected_payment.dart';
import 'package:auto_split/detection/payment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePayment picks up debits', () {
    final cases = <String, (int, String?)>{
      'Rs.450.00 debited from A/c XX1234 on 11-10-26 to VPA swiggy@icici UPI Ref 528193':
          (45000, 'Swiggy'),
      'INR 1,250.00 spent on HDFC Bank Card XX1234 at AMAZON PAY on 2026-10-11':
          (125000, 'Amazon Pay'),
      'Paid ₹200 to Rahul Sharma': (20000, 'Rahul Sharma'),
      '₹89.5 paid to Blinkit via UPI': (8950, 'Blinkit'),
      'Sent Rs 1500 to Meera Iyer. UPI Ref 12345': (150000, 'Meera Iyer'),
      'Payment of INR 300 to Zomato was successful': (30000, 'Zomato'),
      'Rs 999 debited from your account': (99900, null),
    };
    cases.forEach((text, expected) {
      test(text, () {
        final parsed = parsePayment(text);
        expect(parsed, isNotNull);
        expect(parsed!.amountMinor, expected.$1);
        expect(parsed.merchant, expected.$2);
      });
    });
  });

  group('parsePayment ignores non-payments', () {
    for (final text in [
      'Rs 500 credited to your A/c XX1234 by Aarav',
      'You received ₹500 from Aarav',
      '123456 is your OTP for payment of Rs 450 at Swiggy',
      'Kabir requested ₹250 from you',
      'Payment of Rs 4,000 due on 15 Oct for your credit card',
      'Rs 199 will be debited on 12 Oct for Netflix autopay',
      'Your refund of Rs 300 has been processed',
      'Meeting moved to 4 pm',
      'Paid for your order — thanks!',
    ]) {
      test(text, () => expect(parsePayment(text), isNull));
    }
  });

  group('isDuplicate', () {
    final earlier = DetectedPayment(
      id: 'a',
      amountMinor: 45000,
      merchant: 'Swiggy',
      sourceApp: 'com.phonepe.app',
      detectedAt: DateTime(2026, 10, 11, 12, 0),
    );

    test('same amount within two minutes is a duplicate', () {
      expect(
        isDuplicate(const ParsedPayment(45000, null), DateTime(2026, 10, 11, 12, 1), [earlier]),
        isTrue,
      );
    });

    test('same amount later is a new payment', () {
      expect(
        isDuplicate(const ParsedPayment(45000, null), DateTime(2026, 10, 11, 12, 5), [earlier]),
        isFalse,
      );
    });

    test('different amount is a new payment', () {
      expect(
        isDuplicate(const ParsedPayment(45100, null), DateTime(2026, 10, 11, 12, 1), [earlier]),
        isFalse,
      );
    });
  });
}
