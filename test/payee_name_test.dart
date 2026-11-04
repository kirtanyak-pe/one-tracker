import 'dart:convert';

import 'package:auto_split/app_controller.dart';
import 'package:auto_split/engine/classify.dart';
import 'package:auto_split/engine/enrich.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/model/category.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/split/pending_actions.dart';
import 'package:auto_split/split/split_models.dart';
import 'package:auto_split/split/suggest.dart';
import 'package:auto_split/storage/app_store.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _t0 = DateTime(2026, 10, 11, 12);
var _n = 0;

RawMessage _sms(String body, {int minutes = 0, DateTime? at}) => RawMessage(
      source: Source.sms,
      sourceId: 'p${_n++}',
      sender: 'VM-HDFCBK',
      body: body,
      at: at ?? _t0.add(Duration(minutes: minutes)),
    );

const _ramesh = 'Rs.4000.00 debited from A/c XX4821 to VPA ramesh.kumar@oksbi';

List<Txn> _twoToRamesh() => ingest(const [], [
      _sms(_ramesh),
      _sms(_ramesh, minutes: 60 * 24 * 30),
      _sms('Rs.250.00 debited from A/c XX4821 to VPA swiggy@icici', minutes: 5),
    ]).txns;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PayeeRule', () {
    test('old rules without name/tags still load', () {
      final r = PayeeRule.fromJson({'key': 'swiggy', 'label': 'Swiggy', 'category': 'food', 'kind': null});
      expect(r.name, isNull);
      expect(r.tags, isEmpty);
      expect(r.category, Category.food);
      expect(r.hasClassification, isTrue);
      expect(r.isEmpty, isFalse);
    });

    test('name and tags round-trip; blank name is none; plain rules stay compact', () {
      const r = PayeeRule(key: 'rameshkumar', label: 'Ramesh Kumar', name: 'Maid', tags: ['Home', 'Monthly']);
      final back = PayeeRule.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.name, 'Maid');
      expect(back.tags, ['Home', 'Monthly']);
      expect(PayeeRule.fromJson({'key': 'k', 'label': 'K', 'name': '  '}).name, isNull);
      const plain = PayeeRule(key: 'k', label: 'K', category: Category.food);
      expect(plain.toJson().containsKey('name'), isFalse);
      expect(plain.toJson().containsKey('tags'), isFalse);
    });

    test('copyWith clears and keeps', () {
      const r = PayeeRule(key: 'k', label: 'K', name: 'Maid', tags: ['a'], category: Category.bills);
      expect(r.copyWith(clearName: true).name, isNull);
      expect(r.copyWith(clearName: true).tags, ['a']);
      expect(r.copyWith(clearCategory: true, clearName: true, tags: []).isEmpty, isTrue);
    });
  });

  group('enrich', () {
    test('rule name replaces the payee on every payment; bank name kept', () {
      final txns = _twoToRamesh();
      final key = payeeKey(txns.first);
      final ledger = enrich(txns, rules: {key: PayeeRule(key: key, label: 'Ramesh Kumar', name: 'Maid')});
      final maid = ledger.items.where((e) => e.payee == 'Maid').toList();
      expect(maid, hasLength(2));
      expect(maid.map((e) => e.originalPayee), everyElement('Ramesh Kumar'));
      expect(maid.map((e) => e.renamed), everyElement(isTrue));
      final swiggy = ledger.items.firstWhere((e) => e.payee == 'Swiggy');
      expect((swiggy.originalPayee, swiggy.renamed), ('Swiggy', false));
    });

    test('tags = payee name, rule tags, payment tags, keyword-rule tags', () {
      final txns = [_twoToRamesh().first.copyWith(userTags: ['One-off'])];
      final key = payeeKey(txns.first);
      final ledger = enrich(txns, rules: {
        key: PayeeRule(key: key, label: 'Ramesh Kumar', name: 'Maid', tags: ['Home']),
      });
      final e = ledger.items.single;
      expect(e.tags, ['Maid', 'Home', 'One-off']);
      expect(e.ruleTags, ['Home']);
      expect(e.userTags, ['Home', 'One-off']);
    });

    test('rule tags alone do not rename; name alone adds no tags', () {
      final txns = _twoToRamesh();
      final key = payeeKey(txns.first);
      final tagged = enrich(txns, rules: {key: PayeeRule(key: key, label: 'Ramesh Kumar', tags: ['Home'])});
      expect(tagged.items.first.payee, 'Ramesh Kumar');
      expect(tagged.items.first.tags, ['Ramesh Kumar', 'Home']);
      final named = enrich(txns, rules: {key: PayeeRule(key: key, label: 'Ramesh Kumar', name: 'Maid')});
      expect(named.items.first.tags, ['Maid']);
    });

    test('a renamed Blinkit-style payee groups under the new name', () {
      final txns = ingest(const [], [
        _sms('Rs.300.00 debited from A/c XX4821 to VPA paytmqr28100505@paytm'),
        _sms('Rs.90.00 debited from A/c XX4821 to VPA paytmqr99887766@paytm', minutes: 30),
      ]).txns;
      final key = payeeKey(txns.first);
      final ledger = enrich(txns, rules: {key: PayeeRule(key: key, label: 'x', name: 'Blinkit')});
      expect(ledger.items.map((e) => e.payee).toSet().length, 2, reason: 'QR payees have their own keys');
      expect(ledger.items.where((e) => e.payee == 'Blinkit'), hasLength(1));
    });
  });

  group('splitwise and notification use the renamed payee', () {
    final fresh = DateTime(2026, 10, 11, 12, 10);
    Ledger renamedLedger() {
      final txns = _twoToRamesh();
      final key = payeeKey(txns.first);
      return enrich(txns, rules: {key: PayeeRule(key: key, label: 'Ramesh Kumar', name: 'Maid')});
    }

    test('notification pick carries the name the notification is built from', () {
      final pick = notifyFor(
        renamedLedger().items,
        handled: {},
        settings: const SplitSettings(),
        now: fresh,
      );
      expect(pick!.payee, 'Maid');
    });

    test('split description (from a notification action) is the renamed payee', () {
      final ledger = renamedLedger();
      final id = ledger.items.firstWhere((e) => e.payee == 'Maid').txn.id;
      final result = applySplitActions(
        [PendingSplitAction(txnId: id, action: SplitAction.split, at: fresh)],
        records: {},
        skipped: {},
        lookup: (i) => ledger.items.where((e) => e.txn.id == i).firstOrNull,
      );
      expect(result.records[id]!.description, 'Maid');
    });
  });

  group('controller', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<(AppController, AppStore)> open() async {
      final store = AppStore();
      final app = AppController(store);
      await app.init();
      return (app, store);
    }

    /// A payee with more than one payment in the sample data.
    Enriched repeated(AppController app) {
      final counts = <String, int>{};
      for (final e in app.ledger.items) {
        final k = payeeKey(e.txn);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      return app.ledger.items.firstWhere((e) => counts[payeeKey(e.txn)]! > 1 && payeeKey(e.txn).isNotEmpty);
    }

    test('rename applies to past payments, persists, and flows into the Splitwise record', () async {
      final (app, store) = await open();
      final e = repeated(app);
      final key = payeeKey(e.txn);
      final original = e.originalPayee;
      await app.renamePayee(e, '  Maid ');

      final same = app.ledger.items.where((x) => payeeKey(x.txn) == key).toList();
      expect(same.length, greaterThan(1));
      expect(same.map((x) => x.payee), everyElement('Maid'));
      expect(same.map((x) => x.originalPayee), everyElement(original));
      expect(app.knownNames, ['Maid']);

      expect((await store.readRules())[key]!.name, 'Maid');
      final reopened = AppController(store);
      await reopened.init();
      expect(reopened.find(e.txn.id)!.payee, 'Maid');

      await app.openInSplitwise(e.txn.id);
      expect(app.splitRecords[e.txn.id]!.description, 'Maid');
    });

    test('clearing the name (blank or the bank name) goes back and drops an empty rule', () async {
      final (app, store) = await open();
      final e = repeated(app);
      final key = payeeKey(e.txn);
      await app.renamePayee(e, 'Cook');
      expect(app.find(e.txn.id)!.payee, 'Cook');
      await app.renamePayee(app.find(e.txn.id)!, '   ');
      expect(app.find(e.txn.id)!.payee, e.originalPayee);
      expect(app.rules.containsKey(key), isFalse);
      expect((await store.readRules()).containsKey(key), isFalse);

      await app.renamePayee(e, 'Cook');
      await app.renamePayee(app.find(e.txn.id)!, e.originalPayee);
      expect(app.find(e.txn.id)!.renamed, isFalse);
    });

    test('rename keeps the rule\'s category and "Same for all" toggles keep the name and tags', () async {
      final (app, _) = await open();
      final e = repeated(app);
      final key = payeeKey(e.txn);
      await app.renamePayee(e, 'Maid');
      await app.addTag(e.txn, 'Home');
      await app.setCategory(e.txn, Category.bills);
      await app.rememberFor(app.find(e.txn.id)!);
      expect(app.rules[key]!.category, Category.bills);
      expect(app.rules[key]!.name, 'Maid');
      expect(app.rules[key]!.tags, ['Home']);
      await app.forgetClassification(key);
      expect(app.rules[key]!.hasClassification, isFalse);
      expect(app.rules[key]!.name, 'Maid');
      expect(app.rules[key]!.tags, ['Home']);
    });

    test('tag defaults to the whole payee; off keeps it on one payment', () async {
      final (app, store) = await open();
      final e = repeated(app);
      final key = payeeKey(e.txn);
      final all = app.ledger.items.where((x) => payeeKey(x.txn) == key).toList();

      await app.addTag(e.txn, ' Home ');
      expect(app.ledger.items.where((x) => payeeKey(x.txn) == key).every((x) => x.tags.contains('Home')), isTrue);
      expect((await store.readRules())[key]!.tags, ['Home']);
      expect(app.find(e.txn.id)!.txn.userTags, isEmpty);

      await app.addTag(all.first.txn, 'Once', forPayee: false);
      expect(app.find(all.first.txn.id)!.tags, contains('Once'));
      expect(app.find(all.last.txn.id)!.tags, isNot(contains('Once')));
      expect(app.knownTags, containsAll(['Home', 'Once']));

      // Search/filters read Enriched.tags, so both are found.
      expect(app.ledger.items.where((x) => x.tags.contains('Home')).length, all.length);
    });

    test('removing a payee tag takes it off every payment; a payment tag only that one', () async {
      final (app, _) = await open();
      final e = repeated(app);
      final key = payeeKey(e.txn);
      await app.addTag(e.txn, 'Home');
      await app.addTag(e.txn, 'Once', forPayee: false);
      await app.removeTag(app.find(e.txn.id)!.txn, 'Home');
      expect(app.ledger.items.where((x) => payeeKey(x.txn) == key).any((x) => x.tags.contains('Home')), isFalse);
      expect(app.rules.containsKey(key), isFalse, reason: 'an empty rule is dropped');
      await app.removeTag(app.find(e.txn.id)!.txn, 'Once');
      expect(app.find(e.txn.id)!.tags, isNot(contains('Once')));
    });
  });
}
