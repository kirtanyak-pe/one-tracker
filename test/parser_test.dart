import 'package:auto_split/engine/parser.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('debits', () {
    test('UPI to merchant VPA', () {
      final p = parseMessage(
          'Rs.450.00 debited from A/c XX4821 on 11-10-26 to VPA swiggy@icici UPI Ref 528193004411')!;
      expect(p.direction, Direction.debit);
      expect(p.amountMinor, 45000);
      expect(p.counterparty, 'Swiggy');
      expect(p.vpa, 'swiggy@icici');
      expect(p.account, '4821');
      expect(p.ref, '528193004411');
    });

    test('card spend at merchant', () {
      final p = parseMessage('INR 3,499.00 spent on ICICI Bank Card XX9034 at MYNTRA DESIGNS PVT LTD on 10-Oct-26.')!;
      expect(p.amountMinor, 349900);
      expect(p.counterparty, 'Myntra Designs Pvt Ltd');
      expect(p.account, '9034');
    });

    test('bank UPI string names a person and marks P2A', () {
      final p = parseMessage(
          'Rs.2000.00 debited from A/c XX4821 to VPA 9876543210@ybl (UPI/P2A/528193004520/RAHUL SHARMA). Ref 528193004520')!;
      expect(p.counterparty, 'Rahul Sharma');
      expect(p.kindHint, CounterpartyKind.person);
    });

    test('person name from VPA handle', () {
      final p = parseMessage('Rs.800.00 debited from A/c XX4821 to VPA meera.iyer@okaxis UPI Ref 528193004700')!;
      expect(p.counterparty, 'Meera Iyer');
    });

    test('SBI style without currency before amount', () {
      final p = parseMessage('Dear UPI user A/C X7712 debited by 250.0 on date 11Oct26 trf to RAVI KUMAR Refno 628100223344')!;
      expect(p.amountMinor, 25000);
      expect(p.counterparty, 'Ravi Kumar');
      expect(p.account, '7712');
    });

    test('account to account picks up both accounts', () {
      final p = parseMessage('Rs.15000.00 debited from A/c XX4821 to A/c XX7712 IMPS Ref 628193004001')!;
      expect(p.account, '4821');
      expect(p.otherAccount, '7712');
      expect(p.counterparty, isNull);
    });

    test('app notification', () {
      final p = parseMessage('Paid ₹200 to Rahul Sharma\nUPI transaction ID 528193')!;
      expect(p.direction, Direction.debit);
      expect(p.counterparty, 'Rahul Sharma');
    });

    test('ATM withdrawal', () {
      final p = parseMessage('Rs 2000 withdrawn at SBI ATM from A/c XX7712 on date. Avl Bal Rs 31,220.')!;
      expect(p.amountMinor, 200000);
      expect(p.atm, isTrue);
    });

    test('self transfer wording', () {
      expect(parseMessage('Rs.5000 debited from A/c XX4821 - Self Transfer. Ref 5281')!.selfHint, isTrue);
    });
  });

  group('credits', () {
    test('salary by NEFT skips the rail name', () {
      final p = parseMessage(
          'Your A/c XX4821 is credited with INR 85,000.00 by NEFT from ACME TECH PVT LTD. Ref N2810040017')!;
      expect(p.direction, Direction.credit);
      expect(p.amountMinor, 8500000);
      expect(p.counterparty, 'Acme Tech Pvt Ltd');
    });

    test('UPI from friend', () {
      final p = parseMessage('Rs.450.00 credited to A/c XX4821 from VPA aarav.mehta@okaxis UPI Ref 528193005000')!;
      expect(p.direction, Direction.credit);
      expect(p.counterparty, 'Aarav Mehta');
    });

    test('debit that mentions "credited to" is still a debit', () {
      final p = parseMessage('Rs 450 debited from A/c XX12 and credited to VPA zomato@hdfc')!;
      expect(p.direction, Direction.debit);
      expect(p.counterparty, 'Zomato');
    });

    test('"credited by Rs…" is not a payee called Rs', () {
      final p = parseMessage('Your A/c XX7712 credited by Rs.15,000.00 on IMPS from A/c XX4821. Ref 6281')!;
      expect(p.counterparty, isNull);
      expect(p.otherAccount, '4821');
    });

    test('refund', () {
      final p = parseMessage('Refund of Rs 499 credited to your A/c XX4821 from AMAZON')!;
      expect(p.direction, Direction.credit);
      expect(p.refund, isTrue);
    });
  });

  group('ignores', () {
    for (final text in [
      '482913 is your OTP for payment of Rs 1,999 at AMAZON. Do not share.',
      'Kabir requested ₹250 from you on Google Pay',
      'Your credit card bill of Rs 12,500 is due on 15 Oct. Minimum amount due Rs 625',
      'Rs 199 will be debited on 12 Oct for Netflix autopay',
      'Transaction of Rs 500 at ZOMATO failed. Amount will not be debited',
      'Get a pre-approved loan of Rs 5,00,000 today!',
      'Meeting moved to 4 pm',
    ]) {
      test(text, () => expect(parseMessage(text), isNull));
    }
  });

  test('keeps acronyms in shouty names', () {
    expect(tidyName('SBI ATM'), 'SBI ATM');
    expect(tidyName('ICICI BANK CRED'), 'ICICI Bank Cred');
    expect(tidyName('UBER INDIA'), 'Uber India');
  });

  test('nameFromVpa', () {
    expect(nameFromVpa('rahul.sharma@okaxis'), 'Rahul Sharma');
    expect(nameFromVpa('9876543210@ybl'), '9876543210');
    expect(nameFromVpa('paytmqr28100505@paytm'), 'Paytm QR merchant');
    expect(nameFromVpa('blinkit.payu@hdfcbank'), 'Blinkit');
    expect(nameFromVpa('netflix.upi@icici'), 'Netflix');
    expect(nameFromVpa('quickbites@ybl'), 'Quickbites');
  });
}
