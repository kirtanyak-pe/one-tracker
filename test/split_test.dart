import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/split/split_models.dart';
import 'package:auto_split/split/split_service.dart';
import 'package:auto_split/split/suggest.dart';
import 'package:auto_split/splitwise/models.dart';
import 'package:auto_split/splitwise/split_math.dart';
import 'package:auto_split/splitwise/splitwise_api.dart';
import 'package:flutter_test/flutter_test.dart';

const _you = SwUser(id: 1, firstName: 'You');
const _aarav = SwUser(id: 2, firstName: 'Aarav', lastName: 'Mehta');
const _meera = SwUser(id: 3, firstName: 'Meera', lastName: 'Iyer');
const _flat = SwGroup(id: 101, name: 'Flatmates', members: [_you, _aarav, _meera]);

/// Records what would be sent to Splitwise.
class _FakeApi extends DemoSplitwiseApi {
  final calls = <String>[];
  List<ExpenseShare>? shares;
  int? sharedGroupId;

  @override
  bool get isDemo => false;

  @override
  Future<void> createGroupExpense({
    required int groupId,
    required int costMinor,
    required String description,
    required String currency,
  }) async =>
      calls.add('group $groupId $costMinor $description $currency');

  @override
  Future<void> createSharedExpense({
    required List<ExpenseShare> shares,
    required int costMinor,
    required String description,
    required String currency,
    int groupId = 0,
  }) async {
    this.shares = shares;
    sharedGroupId = groupId;
    calls.add('shared $costMinor $description');
  }
}

var _n = 0;
RawMessage _sms(DateTime at, String body) =>
    RawMessage(source: Source.sms, sourceId: '${_n++}', sender: 'VM-HDFCBK', body: body, at: at);

void main() {
  final prompt = SplitPrompt(txnId: 't1', amountMinor: 45000, payee: 'Swiggy', at: DateTime(2026, 10, 13));

  group('targets', () {
    test('group target splits among its members', () {
      final t = SplitTarget.group(_flat);
      expect(t.people, 3);
      expect(t.shareOf(45000), 15000);
      expect(t.label, 'Flatmates');
    });

    test('friends target counts you in', () {
      final t = SplitTarget.friends([_aarav, _meera]);
      expect(t.people, 3);
      expect(t.label, 'Aarav, Meera');
    });

    test('round-trips and compares', () {
      final t = SplitTarget.friends([_aarav, _meera]);
      final back = SplitTarget.fromJson(t.toJson());
      expect(back.sameAs(t), isTrue);
      expect(back.sameAs(SplitTarget.group(_flat)), isFalse);
      expect(SplitTarget.friends([_meera, _aarav]).sameAs(t), isTrue);
    });
  });

  group('splitting', () {
    test('group: one split-equally expense on the group', () async {
      final api = _FakeApi();
      final record = await splitOnSplitwise(
        api: api,
        target: SplitTarget.group(_flat),
        myUserId: 1,
        prompt: prompt,
        currency: 'INR',
      );
      expect(api.calls, ['group 101 45000 Swiggy INR']);
      expect(record.label, 'Flatmates');
      expect(record.demo, isFalse);
    });

    test('friends: you paid, everyone owes an equal part', () async {
      final api = _FakeApi();
      await splitOnSplitwise(
        api: api,
        target: SplitTarget.friends([_aarav, _meera]),
        myUserId: 1,
        prompt: prompt,
        currency: 'INR',
      );
      expect(api.shares!.map((s) => s.userId), [1, 2, 3]);
      expect(api.shares!.map((s) => s.paidMinor), [45000, 0, 0]);
      expect(api.shares!.map((s) => s.owedMinor), [15000, 15000, 15000]);
    });

    test('demo mode is marked', () async {
      final record = await splitOnSplitwise(
        api: DemoSplitwiseApi(),
        target: SplitTarget.group(_flat),
        myUserId: 1,
        prompt: prompt,
        currency: 'INR',
      );
      expect(record.demo, isTrue);
    });

    test('leftover paise go one each so shares add up', () {
      final shares = equalSplit(payerId: 1, participantIds: [2, 3], totalMinor: 10000);
      expect(shares.map((s) => s.owedMinor), [3334, 3333, 3333]);
    });

    test('a 200 with errors is still a failure', () {
      expect(errorMessage({}), isNull);
      expect(errorMessage({'base': ['Invalid group']}), 'Invalid group');
    });
  });

  group('suggestions', () {
    final now = DateTime(2026, 10, 13, 20);
    final ledger = enrich(ingest(const [], [
      _sms(now.subtract(const Duration(minutes: 2)), 'Rs.450 debited from A/c XX4821 to VPA swiggy@icici'),
      _sms(now.subtract(const Duration(minutes: 5)), 'Rs.60 debited from A/c XX4821 to VPA chai@ybl'),
      _sms(now.subtract(const Duration(hours: 3)), 'Rs.900 debited from A/c XX4821 to VPA zomato@hdfc'),
      _sms(now.subtract(const Duration(minutes: 1)), 'Rs.5000 debited from A/c XX4821 - Self Transfer'),
      _sms(now.subtract(const Duration(minutes: 1)), 'Rs.800 credited to A/c XX4821 from VPA aarav@okaxis'),
    ]).txns);

    test('candidates: real spending above the minimum, newest first', () {
      final c = splitCandidates(ledger.items, handled: {}, settings: const SplitSettings());
      expect(c.map((e) => e.payee), ['Swiggy', 'Zomato']);
    });

    test('handled payments are left out', () {
      final swiggy = ledger.items.firstWhere((e) => e.payee == 'Swiggy').txn.id;
      final c = splitCandidates(ledger.items, handled: {swiggy}, settings: const SplitSettings());
      expect(c.map((e) => e.payee), ['Zomato']);
    });

    test('popup only for fresh payments', () {
      final pick = popupFor(ledger.items, handled: {}, settings: const SplitSettings(), now: now);
      expect(pick!.payee, 'Swiggy');
      final later = popupFor(ledger.items, handled: {}, settings: const SplitSettings(), now: now.add(const Duration(hours: 1)));
      expect(later, isNull);
    });

    test('popup can be switched off', () {
      expect(popupFor(ledger.items, handled: {}, settings: const SplitSettings(popup: false), now: now), isNull);
    });
  });
}
