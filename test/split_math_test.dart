import 'package:auto_split/splitwise/split_math.dart';
import 'package:flutter_test/flutter_test.dart';

const me = 1, aarav = 2, meera = 3, kabir = 4;

List<int> owed(SplitResult r) => r.shares.map((s) => s.owedMinor).toList();
int total(SplitResult r) => r.shares.fold(0, (a, s) => a + s.owedMinor);

void main() {
  group('equal', () {
    test('only the members you tick', () {
      final r = computeShares(totalMinor: 90000, participantIds: [me, aarav], mode: SplitMode.equal, payerId: me);
      expect(owed(r), [45000, 45000]);
      expect(r.shares.first.paidMinor, 90000);
    });

    test('paise left over still adds up', () {
      final r = computeShares(totalMinor: 10000, participantIds: [me, aarav, meera], mode: SplitMode.equal, payerId: me);
      expect(owed(r), [3334, 3333, 3333]);
      expect(total(r), 10000);
    });
  });

  group('exact amounts', () {
    test('must add up to the total', () {
      final ok = computeShares(
        totalMinor: 100000,
        participantIds: [me, aarav],
        mode: SplitMode.exact,
        payerId: me,
        values: {me: 30000, aarav: 70000},
      );
      expect(owed(ok), [30000, 70000]);
      final short = computeShares(
        totalMinor: 100000,
        participantIds: [me, aarav],
        mode: SplitMode.exact,
        payerId: me,
        values: {me: 30000, aarav: 65000},
      );
      expect(short.error, '₹50 left to assign');
      final over = computeShares(
        totalMinor: 100000,
        participantIds: [me, aarav],
        mode: SplitMode.exact,
        payerId: me,
        values: {me: 30000, aarav: 72050},
      );
      expect(over.error, '₹20.50 over the total');
    });
  });

  group('percentages', () {
    test('40 / 30 / 30', () {
      final r = computeShares(
        totalMinor: 1800000,
        participantIds: [me, aarav, meera],
        mode: SplitMode.percent,
        payerId: me,
        values: {me: 4000, aarav: 3000, meera: 3000},
      );
      expect(owed(r), [720000, 540000, 540000]);
    });

    test('rounding never loses a paisa', () {
      final r = computeShares(
        totalMinor: 99999,
        participantIds: [me, aarav, meera],
        mode: SplitMode.percent,
        payerId: me,
        values: {me: 3333, aarav: 3333, meera: 3334},
      );
      expect(total(r), 99999);
    });

    test('must make 100%', () {
      final r = computeShares(
        totalMinor: 100000,
        participantIds: [me, aarav],
        mode: SplitMode.percent,
        payerId: me,
        values: {me: 5000, aarav: 4550},
      );
      expect(r.error, 'Adds up to 95.5%, needs 100%');
    });
  });

  group('shares', () {
    test('2 : 1 : 1', () {
      final r = computeShares(
        totalMinor: 100000,
        participantIds: [me, aarav, meera],
        mode: SplitMode.shares,
        payerId: me,
        values: {me: 2, aarav: 1, meera: 1},
      );
      expect(owed(r), [50000, 25000, 25000]);
    });

    test('a zero share owes nothing', () {
      final r = computeShares(
        totalMinor: 30000,
        participantIds: [me, aarav, meera],
        mode: SplitMode.shares,
        payerId: me,
        values: {me: 1, aarav: 1, meera: 0},
      );
      expect(owed(r), [15000, 15000, 0]);
    });

    test('needs at least one share', () {
      final r = computeShares(totalMinor: 30000, participantIds: [me], mode: SplitMode.shares, payerId: me);
      expect(r.error, 'Give someone at least 1 share');
    });
  });

  group('adjustment', () {
    test('equal split, then +₹100 for Aarav', () {
      final r = computeShares(
        totalMinor: 90000,
        participantIds: [me, aarav, meera],
        mode: SplitMode.adjust,
        payerId: me,
        values: {aarav: 10000},
      );
      // ₹800 left after the ₹100 goes 3 ways; the spare paisa goes first.
      expect(owed(r), [26667, 36667, 26666]);
      expect(total(r), 90000);
    });

    test("can't push anyone below zero", () {
      final r = computeShares(
        totalMinor: 10000,
        participantIds: [me, aarav],
        mode: SplitMode.adjust,
        payerId: me,
        values: {aarav: -12000},
      );
      expect(r.error, "Someone's share went below ₹0");
    });
  });

  group('who paid', () {
    test('someone else paid; you owe your part', () {
      final r = computeShares(totalMinor: 60000, participantIds: [me, aarav], mode: SplitMode.equal, payerId: aarav);
      final aaravShare = r.shares.firstWhere((s) => s.userId == aarav);
      expect(aaravShare.paidMinor, 60000);
      expect(r.shares.firstWhere((s) => s.userId == me).paidMinor, 0);
      expect(r.owedBy(me), 30000);
    });

    test('you paid for others only — you still appear as payer', () {
      final r = computeShares(totalMinor: 60000, participantIds: [aarav, kabir], mode: SplitMode.equal, payerId: me);
      expect(r.shares.map((s) => s.userId), [aarav, kabir, me]);
      expect(r.owedBy(me), 0);
      expect(r.shares.last.paidMinor, 60000);
      expect(total(r), 60000);
    });
  });

  test('nobody picked', () {
    expect(
      computeShares(totalMinor: 100, participantIds: [], mode: SplitMode.equal, payerId: me).error,
      'Pick at least one person',
    );
  });

  test('which modes can be a default', () {
    expect(SplitMode.values.where((m) => m.scales), [SplitMode.equal, SplitMode.percent, SplitMode.shares]);
  });
}
