import 'package:auto_split/engine/classify.dart';
import 'package:auto_split/engine/ingest.dart';
import 'package:auto_split/engine/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'engine_bench_test.dart' show heavyYear, ms;

void main() {
  test('hot spots', () {
    final msgs = heavyYear();
    final txns = ingest(const [], msgs).txns;
    final tParse = ms(() {
      for (final m in msgs) {
        parseMessage(m.body);
      }
    });
    final tKind = ms(() => txns.forEach(counterpartyKind));
    final tCat = ms(() {
      for (final t in txns) {
        categoryFromKeywords("${t.counterparty} ${t.vpa}");
      }
    });
    final tKey = ms(() => txns.forEach(payeeKey));
    // ignore: avoid_print
    print('parse=${tParse}ms counterpartyKind=${tKind}ms categoryFromKeywords=${tCat}ms payeeKey=${tKey}ms');
  });
}
