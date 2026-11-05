import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/parser.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 10, 11, 12);

RawMessage _note(String pkg, String body, {String id = 'n1'}) =>
    RawMessage(source: Source.notification, sourceId: id, sender: pkg, body: body, at: _t0);

Txn _stored(String pkg, String body, {bool reviewed = false, List<String> tags = const []}) => Txn(
  id: 'notification-$pkg',
  source: Source.notification,
  direction: Direction.debit,
  amountMinor: 62500,
  at: _t0,
  raw: body,
  sender: pkg,
  reviewed: reviewed,
  userTags: tags,
);

const _chat = 'reach us\n💬 Chat: payment of ₹625 sent to support';

void main() {
  group('chat apps are not payments', () {
    test('WhatsApp chat text with an amount is rejected', () {
      expect(notificationMayBePayment('com.whatsapp', _chat), isFalse);
      expect(ingest(const [], [_note('com.whatsapp', _chat)]).txns, isEmpty);
    });

    test('Telegram, Gmail and friends are rejected even with a payment phrase', () {
      for (final pkg in ['org.telegram.messenger', 'com.google.android.gm', 'com.instagram.android', 'com.Slack']) {
        final r = ingest(const [], [_note(pkg, 'Rahul\nYou paid ₹250 to Ravi', id: pkg)]);
        expect(r.txns, isEmpty, reason: pkg);
      }
    });

    test('real WhatsApp Pay notifications still count', () {
      for (final body in [
        'WhatsApp\nYou paid ₹250 to Ravi',
        'Ravi\nRavi Kumar sent you ₹100',
        'Payment of ₹300 successful',
      ]) {
        expect(notificationMayBePayment('com.whatsapp', body), isTrue, reason: body);
      }
      final r = ingest(const [], [_note('com.whatsapp', 'WhatsApp\nYou paid ₹250 to Ravi')]);
      expect(r.txns.single.amountMinor, 25000);
    });
  });

  group('payment apps and the SMS app still parse', () {
    test('GPay, PhonePe and bank app notifications', () {
      for (final pkg in ['com.google.android.apps.nbu.paisa.user', 'com.phonepe.app', 'com.snapwork.hdfc']) {
        final r = ingest(const [], [_note(pkg, 'Paid ₹450 to Swiggy', id: pkg)]);
        expect(r.txns, hasLength(1), reason: pkg);
      }
    });

    test('bank SMS arriving via the SMS app notification', () {
      final r = ingest(const [], [
        _note(
          'com.google.android.apps.messaging',
          'VM-HDFCBK\nRs.450.00 debited from A/c XX4821 to VPA swiggy@icici UPI Ref 528193004411',
        ),
      ]);
      expect(r.txns.single.account, '4821');
    });
  });

  group('reparse drops old bad notification payments', () {
    test('rejected ones go, edited ones stay, good ones stay', () {
      final bad = _stored('com.whatsapp', _chat);
      final reviewed = _stored('com.telegram', _chat, reviewed: true);
      final tagged = _stored('com.google.android.gm', _chat, tags: const ['Mine']);
      final good = _stored('com.google.android.apps.nbu.paisa.user', 'Paid ₹625 to Swiggy');
      final kept = reparseAll([bad, reviewed, tagged, good]);
      expect(kept.map((t) => t.sender), [reviewed.sender, tagged.sender, good.sender]);
      expect(isRejectedNotification(bad), isTrue);
      expect(isUserEdited(bad), isFalse);
    });
  });
}
