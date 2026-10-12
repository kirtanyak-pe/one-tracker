import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/model/transaction.dart';
import 'package:auto_split/sources/sms_id.dart';
import 'package:auto_split/sources/sms_source.dart';
import 'package:flutter_test/flutter_test.dart';

const body = 'Rs.450.00 debited from A/c XX4821 to VPA swiggy@icici UPI Ref 528193004411';

void main() {
  test('content id is stable and specific', () {
    expect(smsContentId('VM-HDFCBK', body), smsContentId('vm-hdfcbk', '  $body '));
    expect(smsContentId('VM-HDFCBK', body), isNot(smsContentId('VM-HDFCBK', body.replaceAll('450', '451'))));
    expect(smsContentId('VM-HDFCBK', body), hasLength(17));
  });

  test('live copy and later inbox copy are one payment', () {
    final at = DateTime(2026, 10, 13, 13, 5);
    final live = SmsSource.liveMessage(sender: 'VM-HDFCBK', body: body, at: at);
    final first = ingest(const [], [live]);
    expect(first.addedIds, hasLength(1));

    // The inbox scan stamps its own (slightly different) receive time.
    final inbox = RawMessage(
      source: Source.sms,
      sourceId: smsContentId('VM-HDFCBK', body),
      sender: 'VM-HDFCBK',
      body: body,
      at: at.add(const Duration(seconds: 3)),
    );
    final again = ingest(first.txns, [inbox]);
    expect(again.added, 0);
    expect(again.txns, hasLength(1));
  });

  test('payments stored under old inbox ids are not duplicated', () {
    final at = DateTime(2026, 10, 13, 13, 5);
    final old = ingest(const [], [
      RawMessage(source: Source.sms, sourceId: '4711', sender: 'VM-HDFCBK', body: body, at: at),
    ]);
    final rescanned = ingest(old.txns, [SmsSource.liveMessage(sender: 'VM-HDFCBK', body: body, at: at)]);
    expect(rescanned.added, 0);
  });

  test('the same text days apart is two payments (e.g. a monthly bill)', () {
    const bill = 'Rs.649.00 debited from A/c XX4821 to VPA netflix.upi@icici';
    final a = ingest(const [], [
      RawMessage(source: Source.sms, sourceId: 'a', sender: 'VM-HDFCBK', body: bill, at: DateTime(2026, 9, 4)),
    ]);
    final b = ingest(a.txns, [
      RawMessage(source: Source.sms, sourceId: 'b', sender: 'VM-HDFCBK', body: bill, at: DateTime(2026, 10, 4)),
    ]);
    expect(b.added, 1);
  });
}
