import 'package:auto_split/money.dart';
import 'package:auto_split/splitwise/split_math.dart';
import 'package:auto_split/splitwise/splitwise_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('equalSplit', () {
    test('payer pays all, everyone owes an equal part', () {
      final shares = equalSplit(payerId: 1, participantIds: [2, 3], totalMinor: 45000);
      expect(shares.map((s) => s.userId), [1, 2, 3]);
      expect(shares.map((s) => s.paidMinor), [45000, 0, 0]);
      expect(shares.map((s) => s.owedMinor), [15000, 15000, 15000]);
    });

    test('leftover paise are spread so owed shares add up exactly', () {
      final shares = equalSplit(payerId: 1, participantIds: [2, 3], totalMinor: 10000);
      expect(shares.map((s) => s.owedMinor), [3334, 3333, 3333]);
      expect(shares.fold<int>(0, (sum, s) => sum + s.owedMinor), 10000);
    });

    test('payer listed among participants is not counted twice', () {
      final shares = equalSplit(payerId: 1, participantIds: [1, 2], totalMinor: 5000);
      expect(shares, hasLength(2));
      expect(shares.map((s) => s.owedMinor), [2500, 2500]);
    });
  });

  group('money', () {
    test('parseMinor', () {
      expect(parseMinor('1,250.5'), 125050);
      expect(parseMinor('450'), 45000);
      expect(parseMinor('0.07'), 7);
      expect(parseMinor('0'), isNull);
      expect(parseMinor('12.345'), isNull);
      expect(parseMinor('abc'), isNull);
    });

    test('formatMoney drops .00 only for whole amounts', () {
      expect(formatMoney(45000, 'INR'), '₹450');
      expect(formatMoney(33333, 'INR'), '₹333.33');
      expect(formatMoney(12500000, 'INR'), '₹1,25,000');
    });

    test('minorToDecimal', () {
      expect(minorToDecimal(125050), '1250.50');
      expect(minorToDecimal(7), '0.07');
    });
  });

  group('errorMessage (200 OK can still be a failure)', () {
    test('empty errors means success', () {
      expect(errorMessage({}), isNull);
      expect(errorMessage([]), isNull);
      expect(errorMessage(null), isNull);
    });

    test('nested errors are flattened', () {
      expect(
        errorMessage({'base': ['Cost must be positive'], 'group_id': ['is invalid']}),
        'Cost must be positive is invalid',
      );
    });
  });
}
