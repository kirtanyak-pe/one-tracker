import 'dart:convert';

import 'package:auto_split/app_controller.dart';
import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/split/group_link.dart';
import 'package:auto_split/split/pending_actions.dart';
import 'package:auto_split/split/split_models.dart';
import 'package:auto_split/split/suggest.dart';
import 'package:auto_split/storage/app_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

var _n = 0;
RawMessage _sms(DateTime at, String body) =>
    RawMessage(source: Source.sms, sourceId: '${_n++}', sender: 'VM-HDFCBK', body: body, at: at);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 13, 20);
  final ledger = enrich(ingest(const [], [
    _sms(now.subtract(const Duration(minutes: 2)), 'Rs.450 debited from A/c XX4821 to VPA swiggy@icici'),
    _sms(now.subtract(const Duration(minutes: 5)), 'Rs.60 debited from A/c XX4821 to VPA chai@ybl'),
    _sms(now.subtract(const Duration(hours: 3)), 'Rs.900 debited from A/c XX4821 to VPA zomato@hdfc'),
    _sms(now.subtract(const Duration(minutes: 1)), 'Rs.5000 debited from A/c XX4821 - Self Transfer'),
    _sms(now.subtract(const Duration(minutes: 1)), 'Rs.800 credited to A/c XX4821 from VPA aarav@okaxis'),
  ]).txns);
  Enriched byPayee(String p) => ledger.items.firstWhere((e) => e.payee == p);

  group('candidates', () {
    test('real spending above the minimum, newest first', () {
      final c = splitCandidates(ledger.items, handled: {}, settings: const SplitSettings());
      expect(c.map((e) => e.payee), ['Swiggy', 'Zomato']);
    });

    test('handled payments are left out', () {
      final c = splitCandidates(ledger.items, handled: {byPayee('Swiggy').txn.id}, settings: const SplitSettings());
      expect(c.map((e) => e.payee), ['Zomato']);
    });

    test('the minimum is respected', () {
      final c = splitCandidates(ledger.items, handled: {}, settings: const SplitSettings(minMinor: 50000));
      expect(c.map((e) => e.payee), ['Zomato']);
      final any = splitCandidates(ledger.items, handled: {}, settings: const SplitSettings(minMinor: 0));
      expect(any.map((e) => e.payee), contains('Chai'));
    });

    test('notification only for fresh payments', () {
      final pick = notifyFor(ledger.items, handled: {}, settings: const SplitSettings(), now: now);
      expect(pick!.payee, 'Swiggy');
      expect(notifyFor(ledger.items, handled: {}, settings: const SplitSettings(), now: now.add(const Duration(hours: 1))), isNull);
    });

    test('notifications can be switched off', () {
      expect(notifyFor(ledger.items, handled: {}, settings: const SplitSettings(notify: false), now: now), isNull);
    });
  });

  group('SplitSettings', () {
    test('reads the old "popup" key', () {
      expect(SplitSettings.fromJson({'popup': false, 'minMinor': 50000}).notify, isFalse);
      expect(SplitSettings.fromJson({'popup': true}).notify, isTrue);
      expect(SplitSettings.fromJson({'notify': false, 'popup': true}).notify, isFalse);
      final empty = SplitSettings.fromJson({});
      expect((empty.notify, empty.minMinor, empty.groupId), (true, 10000, null));
    });

    test('round-trips with a group; clearing drops it', () {
      final s = const SplitSettings().withGroup(12345678, '  Flatmates ');
      final back = SplitSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect((back.groupId, back.groupName), (12345678, 'Flatmates'));
      expect(s.copyWith(minMinor: 0).groupId, 12345678, reason: 'other edits keep the group');
      final cleared = s.withGroup(null, 'ignored');
      expect((cleared.groupId, cleared.groupName), (null, null));
      expect(cleared.toJson().containsKey('groupId'), isFalse);
    });
  });

  group('group link', () {
    test('finds the id', () {
      expect(parseGroupId('https://secure.splitwise.com/#/groups/12345678'), 12345678);
      expect(parseGroupId('  https://secure.splitwise.com/#/groups/12345678/expenses '), 12345678);
      expect(parseGroupId('https://secure.splitwise.com/groups/42?x=1'), 42);
      expect(parseGroupId('12345678'), 12345678);
    });

    test('no id', () {
      expect(parseGroupId(''), isNull);
      expect(parseGroupId('https://secure.splitwise.com/#/friends/9'), isNull);
      expect(parseGroupId('Flatmates'), isNull);
      expect(parseGroupId('0'), isNull);
    });
  });

  group('pending actions', () {
    final swiggy = byPayee('Swiggy');
    final t0 = DateTime(2026, 10, 13, 20, 5);
    Enriched? lookup(String id) => ledger.items.where((e) => e.txn.id == id).firstOrNull;

    test('parses what the channel sends', () {
      final a = PendingSplitAction.tryParse({'txnId': 'x', 'action': 'notExpense', 'at': 1760000000000})!;
      expect((a.txnId, a.action), ('x', SplitAction.notExpense));
      expect(a.at.millisecondsSinceEpoch, 1760000000000);
      expect(PendingSplitAction.tryParse({'txnId': 'x', 'action': 'nope'}), isNull);
      expect(PendingSplitAction.tryParse('junk'), isNull);
      expect(PendingSplitAction.parseAll([{'txnId': 'x', 'action': 'skip', 'at': 1}, 5]), hasLength(1));
    });

    test('split records it (at the time of the tap), skip and not-expense hide it', () {
      final out = applySplitActions(
        [
          PendingSplitAction(txnId: swiggy.txn.id, action: SplitAction.split, at: t0),
          PendingSplitAction(txnId: byPayee('Zomato').txn.id, action: SplitAction.skip, at: t0),
          PendingSplitAction(txnId: byPayee('Chai').txn.id, action: SplitAction.notExpense, at: t0),
        ],
        records: {},
        skipped: {},
        lookup: lookup,
        groupName: 'Flatmates',
      );
      final r = out.records[swiggy.txn.id]!;
      expect((r.label, r.amountMinor, r.description, r.at), ('Flatmates', 45000, 'Swiggy', t0));
      expect(out.skipped, {byPayee('Zomato').txn.id, byPayee('Chai').txn.id});
      expect(out.notExpense, {byPayee('Chai').txn.id});
      expect(out.changed, isTrue);
    });

    test('unknown payments are ignored; a skip never undoes a split', () {
      final none = applySplitActions(
        [PendingSplitAction(txnId: 'gone', action: SplitAction.split, at: t0)],
        records: {},
        skipped: {},
        lookup: lookup,
      );
      expect(none.records, isEmpty);
      expect(none.skipped, isEmpty);
      expect(none.changed, isFalse);

      final out = applySplitActions(
        [
          PendingSplitAction(txnId: swiggy.txn.id, action: SplitAction.split, at: t0),
          PendingSplitAction(txnId: swiggy.txn.id, action: SplitAction.skip, at: t0),
        ],
        records: {},
        skipped: {},
        lookup: lookup,
      );
      expect(out.records.keys, [swiggy.txn.id]);
      expect(out.skipped, isEmpty);
    });
  });

  group('records', () {
    test('old JSON still reads (demo flag ignored)', () {
      final r = SplitRecord.fromJson({
        'txnId': 't',
        'label': 'Flatmates',
        'amountMinor': 100,
        'description': 'Tea',
        'at': '2026-10-13T10:00:00.000',
        'demo': false,
      });
      expect(r.label, 'Flatmates');
      expect(r.toJson().containsKey('demo'), isFalse);
    });
  });

  group('storage and controller', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      SharedPreferences.setMockInitialValues({});
    });

    test('migration: old demo records dropped, old group becomes the default, old keys removed', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setString(
        'split_records_v1',
        jsonEncode([
          {'txnId': 'a', 'label': 'Flatmates', 'amountMinor': 100, 'description': 'A', 'at': '2026-10-01T10:00:00.000'},
          {'txnId': 'b', 'label': 'Demo', 'amountMinor': 100, 'description': 'B', 'at': '2026-10-01T10:00:00.000', 'demo': true},
        ]),
      );
      await prefs.setString('split_settings_v1', jsonEncode({'popup': false, 'minMinor': 50000}));
      await prefs.setString(
        'split_target_v1',
        jsonEncode({'kind': 'group', 'groupId': 777, 'friendIds': [], 'label': 'Trip', 'people': 4}),
      );
      await prefs.setString('sw_groups_v1', '[]');
      final store = AppStore();
      await store.migrateSplitwise();
      expect((await store.readSplitRecords()).keys, ['a']);
      final s = await store.readSplitSettings();
      expect((s.notify, s.minMinor, s.groupId, s.groupName), (false, 50000, 777, 'Trip'));
      expect(await prefs.getString('split_target_v1'), isNull);
      expect(await prefs.getString('sw_groups_v1'), isNull);
    });

    test('openInSplitwise records, skip / undo / not-expense move payments between lists', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final app = AppController(AppStore());
      await app.init();
      final todo = app.splitTodo;
      expect(todo.length, greaterThan(2), reason: 'sample payments are above the minimum');
      final first = todo[0].txn.id, second = todo[1].txn.id, third = todo[2].txn.id;

      await app.openInSplitwise(first);
      expect(app.splitRecords[first]!.description, todo[0].payee);
      expect(app.splitTodo.any((e) => e.txn.id == first), isFalse);

      await app.skipSplit(second);
      expect(app.splitTodo.any((e) => e.txn.id == second), isFalse);
      expect(app.splitRecords.containsKey(second), isFalse);

      await app.undoSplit(first);
      await app.undoSplit(second);
      expect(app.splitTodo.map((e) => e.txn.id), containsAll([first, second]));

      await app.markNotExpense(third);
      expect(app.find(third)!.kind, TxnKind.notExpense);
      expect(app.splitTodo.any((e) => e.txn.id == third), isFalse);

      // Persisted: a fresh controller sees the same state.
      await app.openInSplitwise(first);
      final again = AppController(AppStore());
      await again.init();
      expect(again.splitRecords.keys, [first]);
    });
  });
}
