import 'package:auto_split/engine/classify.dart';
import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/summary.dart';
import 'package:auto_split/model/category.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/sources/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 11, 12);

RawMessage _sms(String id, String body, {int minutes = 0, Source source = Source.sms}) => RawMessage(
      source: source,
      sourceId: id,
      sender: 'VM-HDFCBK',
      body: body,
      at: _t0.add(Duration(minutes: minutes)),
    );

List<Txn> _ingest(List<RawMessage> messages) => ingest(const [], messages).txns;

Enriched _one(Ledger ledger, String id) => ledger.items.firstWhere((e) => e.txn.id == id);

void main() {
  group('categories', () {
    test('merchant keywords', () {
      expect(categoryFromKeywords('Swiggy'), Category.food);
      expect(categoryFromKeywords('UBER INDIA'), Category.transport);
      expect(categoryFromKeywords('Apollo Pharmacy'), Category.health);
      expect(categoryFromKeywords('Myntra Designs'), Category.shopping);
    });

    test('short keywords only match whole words', () {
      expect(categoryFromKeywords('Motorola Store'), isNot(Category.transport));
      expect(categoryFromKeywords('Police canteen'), isNot(Category.bills));
    });

    test('people vs merchants', () {
      final txns = _ingest([
        _sms('1', 'Rs.800.00 debited from A/c XX4821 to VPA meera.iyer@okaxis'),
        _sms('2', 'Rs.320.00 debited from A/c XX4821 to VPA paytmqr28100505@paytm', minutes: 10),
      ]);
      expect(counterpartyKind(txns[0]), CounterpartyKind.person);
      expect(counterpartyKind(txns[1]), CounterpartyKind.merchant);
      final ledger = enrich(txns);
      expect(_one(ledger, 'sms-1').category, Category.people);
      expect(_one(ledger, 'sms-1').tags, contains('Meera Iyer'));
    });
  });

  group('self transfers', () {
    test('debit + matching credit on two of your accounts', () {
      final ledger = enrich(_ingest([
        _sms('d', 'Rs.15000.00 debited from A/c XX4821 to IMPS Ref 1'),
        _sms('c', 'Your A/c XX7712 credited by Rs.15,000.00 on IMPS. Ref 2', minutes: 2),
      ]));
      expect(_one(ledger, 'sms-d').kind, TxnKind.selfTransfer);
      expect(_one(ledger, 'sms-c').kind, TxnKind.selfTransfer);
      expect(ledger.ownAccounts, {'4821', '7712'});
    });

    test('same amount on the same account is not a self transfer', () {
      final ledger = enrich(_ingest([
        _sms('d', 'Rs.500.00 debited from A/c XX4821 to VPA rahul@okaxis'),
        _sms('c', 'Rs.500.00 credited to A/c XX4821 from VPA rahul@okaxis', minutes: 5),
      ]));
      expect(_one(ledger, 'sms-d').kind, TxnKind.expense);
      expect(_one(ledger, 'sms-c').kind, TxnKind.income);
    });

    test('far apart in time is not a pair', () {
      final ledger = enrich(_ingest([
        _sms('d', 'Rs.15000.00 debited from A/c XX4821 Ref 1'),
        _sms('c', 'Your A/c XX7712 credited by Rs.15,000.00. Ref 2', minutes: 90),
      ]));
      expect(_one(ledger, 'sms-d').kind, TxnKind.expense);
    });

    test('sent to another of your accounts', () {
      final ledger = enrich(_ingest([
        _sms('a', 'Rs.100 debited from A/c XX7712 to VPA x@ybl'),
        _sms('b', 'Rs.3000.00 debited from A/c XX4821 to A/c XX7712 NEFT', minutes: 600),
      ]));
      expect(_one(ledger, 'sms-b').kind, TxnKind.selfTransfer);
      expect(_one(ledger, 'sms-b').reason, contains('7712'));
    });

    test('paid to your own name', () {
      final txns = _ingest([_sms('1', 'Rs.5000 debited from A/c XX4821 (UPI/P2A/1234/KIRTANYA K)')]);
      expect(enrich(txns).items.single.kind, TxnKind.expense);
      final ledger = enrich(txns, profile: const Profile(name: 'Kirtanya Kumar'));
      expect(ledger.items.single.kind, TxnKind.selfTransfer);
    });

    test('bank says self transfer', () {
      final ledger = enrich(_ingest([_sms('1', 'Rs.5000 debited from A/c XX4821 - Self Transfer')]));
      expect(ledger.items.single.kind, TxnKind.selfTransfer);
    });

    test('name matching', () {
      expect(nameMatches('Kirtanya K', 'KIRTANYA KUMAR'), isTrue);
      expect(nameMatches('Kirtanya K', 'Kirtanya'), isTrue);
      expect(nameMatches('Kirtanya K', 'Kirtanya Sharma'), isFalse);
      expect(nameMatches('Kirtanya K', 'Rahul K'), isFalse);
      expect(nameMatches('', 'Rahul'), isFalse);
    });
  });

  group('non-expenses', () {
    test('credit card bill is excluded', () {
      final ledger = enrich(_ingest([
        _sms('1', 'Rs.12500.00 debited from A/c XX4821 towards your Credit Card bill payment XX9034'),
      ]));
      expect(ledger.items.single.kind, TxnKind.notExpense);
    });

    test('card bill paid through CRED is excluded', () {
      final ledger = enrich(_ingest([
        _sms('1', 'Rs.24516.85 debited from A/c XX4821 to ICICI Bank Cred. UPI Ref 6281'),
        _sms('2', 'Rs.3000 debited from A/c XX4821 to VPA cred.club@axisb', minutes: 60),
        _sms('3', 'Rs.300 debited from A/c XX4821 to VPA credible.store@ybl', minutes: 120),
      ]));
      expect(_one(ledger, 'sms-1').kind, TxnKind.notExpense);
      expect(_one(ledger, 'sms-2').kind, TxnKind.notExpense);
      expect(_one(ledger, 'sms-3').kind, TxnKind.expense);
    });

    test('user override wins', () {
      final txns = _ingest([_sms('1', 'Rs.800.00 debited from A/c XX4821 to VPA meera.iyer@okaxis')]);
      final marked = [txns.single.copyWith(kindOverride: TxnKind.notExpense)];
      expect(enrich(marked).items.single.kind, TxnKind.notExpense);
    });

    test('payee rule applies to every payment to that payee', () {
      final txns = _ingest([
        _sms('1', 'Rs.18000.00 debited from A/c XX4821 to VPA ramesh.kumar@oksbi'),
        _sms('2', 'Rs.18000.00 debited from A/c XX4821 to VPA ramesh.kumar@oksbi', minutes: 60 * 24 * 30),
      ]);
      final rule = PayeeRule(key: payeeKey(txns.first), label: 'Ramesh Kumar', category: Category.bills);
      final ledger = enrich(txns, rules: {rule.key: rule});
      expect(ledger.items.map((e) => e.category), everyElement(Category.bills));
      expect(ledger.items.map((e) => e.needsReview), everyElement(isFalse));
    });
  });

  test('QR merchants get their own payee key', () {
    final txns = _ingest([
      _sms('1', 'Rs.320 debited from A/c XX4821 to VPA paytmqr28100505@paytm'),
      _sms('2', 'Rs.90 debited from A/c XX4821 to VPA paytmqr99887766@paytm', minutes: 30),
    ]);
    expect(txns[0].counterparty, txns[1].counterparty);
    expect(payeeKey(txns[0]), isNot(payeeKey(txns[1])));
  });

  group('big-payment check', () {
    List<Txn> payments() => _ingest([
          _sms('small', 'Rs.4999 debited from A/c XX4821 to VPA meera.iyer@okaxis'),
          _sms('edge', 'Rs.5000 debited from A/c XX4821 to VPA swiggy@icici', minutes: 10),
          _sms('big', 'Rs.5001 debited from A/c XX4821 to VPA swiggy@icici', minutes: 20),
          _sms('in', 'Rs.9000 credited to A/c XX4821 from VPA aarav@okaxis', minutes: 30),
        ]);

    test('everything is an expense, only > ₹5,000 asks', () {
      final ledger = enrich(payments());
      expect(_one(ledger, 'sms-small').kind, TxnKind.expense);
      expect(_one(ledger, 'sms-small').needsReview, isFalse);
      expect(_one(ledger, 'sms-edge').needsReview, isFalse);
      expect(_one(ledger, 'sms-big').needsReview, isTrue);
      expect(_one(ledger, 'sms-in').needsReview, isFalse);
    });

    test('threshold is adjustable and can be off', () {
      expect(_one(enrich(payments(), profile: const Profile(reviewAboveMinor: 200000)), 'sms-small').needsReview,
          isTrue);
      expect(enrich(payments(), profile: const Profile(reviewAboveMinor: null)).items.where((e) => e.needsReview),
          isEmpty);
    });

    test('older profiles without the setting default to ₹5,000', () {
      expect(Profile.fromJson({'name': 'A'}).reviewAboveMinor, 500000);
      expect(Profile.fromJson(const Profile(reviewAboveMinor: null).toJson()).reviewAboveMinor, isNull);
    });
  });

  group('ingest', () {
    test('UPI app notification + bank SMS become one transaction', () {
      final result = ingest(const [], [
        _sms('n1', 'Paid ₹450 to Swiggy', source: Source.notification),
        _sms('s1', 'Rs.450.00 debited from A/c XX4821 to VPA swiggy@icici UPI Ref 5281', minutes: 1),
      ]);
      expect(result.txns, hasLength(1));
      expect(result.txns.single.account, '4821');
      expect(result.txns.single.counterparty, 'Swiggy');
    });

    test('re-scanning the same SMS adds nothing', () {
      final first = ingest(const [], [_sms('s1', 'Rs.450 debited from A/c XX4821 to VPA swiggy@icici')]);
      final again = ingest(first.txns, [_sms('s1', 'Rs.450 debited from A/c XX4821 to VPA swiggy@icici')]);
      expect(again.added, 0);
      expect(again.txns, hasLength(1));
    });

    test('two real ₹100 payments a minute apart are kept', () {
      final result = ingest(const [], [
        _sms('s1', 'Rs.100 debited from A/c XX4821 to VPA chai@ybl Ref 111111'),
        _sms('s2', 'Rs.100 debited from A/c XX4821 to VPA chai@ybl Ref 222222', minutes: 1),
      ]);
      expect(result.txns, hasLength(2));
    });
  });

  test('sample month end to end', () {
    final now = DateTime(2026, 10, 25, 22);
    final txns = ingest(const [], sampleMessages(now)).txns;
    final ledger = enrich(txns);
    final month = summarize(ledger, now);

    String kindOf(String payee) => ledger.items.firstWhere((e) => e.payee == payee).kind.name;
    expect(kindOf('Swiggy'), 'expense');
    expect(kindOf('Acme Tech Pvt Ltd'), 'income');
    expect(ledger.items.where((e) => e.kind == TxnKind.selfTransfer), hasLength(3));
    expect(ledger.items.where((e) => e.kind == TxnKind.notExpense), hasLength(1)); // card bill
    expect(txns.any((t) => t.raw!.contains('OTP')), isFalse);
    expect(month.byCategory.first.category, isNotNull);
    expect(month.spentMinor, greaterThan(0));
    // Only expenses above ₹5,000 are asked about.
    expect(ledger.items.where((e) => e.needsReview).map((e) => e.payee), ['Ramesh Kumar']);
  });
}
