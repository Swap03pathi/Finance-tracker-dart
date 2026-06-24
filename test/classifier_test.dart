import 'package:test/test.dart';
import 'package:finman_engine/finman_engine.dart';

/// Device-side classification + idempotency parity with the TS engine (matrix F/G/H/MULTI keys).
void main() {
  group('modality (F)', () {
    test('MOD-02 future', () => expect(classifyModality('Rs 5,000 will be debited on 5th for SIP'), Modality.future));
    test('MOD-04 failed', () => expect(classifyModality('Txn of Rs 1,200 declined, could not be processed'), Modality.failed));
    test('MOD-05 hold', () => expect(classifyModality('Rs 3,000 blocked for hotel booking'), Modality.hold));
    test('MOD-06 mandate', () => expect(classifyModality('Mandate created for Rs 2,000/month at Netflix'), Modality.mandate));
    test('MOD-01 actual', () => expect(classifyModality('Rs 1,200 debited for purchase at Amazon'), Modality.actual));
  });

  group('money-type (G)', () {
    test('TYPE-03 own-node Paytm', () => expect(isSeededOwnNode('PAYTM'), isTrue));
    test('TYPE-02 expense', () => expect(classifyMoneyType(direction: 'out', counterpartyIsOwnNode: false), Direction.EXPENSE));
    test('TYPE-03 transfer', () => expect(classifyMoneyType(direction: 'out', counterpartyIsOwnNode: true), Direction.TRANSFER));
    test('verbDirection', () {
      expect(verbDirection('Rs 450 spent at Zomato'), 'out');
      expect(verbDirection('Rs 65,000 credited by salary'), 'in');
    });
  });

  group('counted', () {
    test('transfer not counted', () => expect(computeIsCounted(Direction.TRANSFER, Modality.actual), isFalse));
    test('future not counted', () => expect(computeIsCounted(Direction.EXPENSE, Modality.future), isFalse));
    test('actual expense counted', () => expect(computeIsCounted(Direction.EXPENSE, Modality.actual), isTrue));
  });

  group('idempotency (H)', () {
    test('extractReference', () {
      expect(extractReference('Rs 450 spent. UPI Ref no 412345678901'), '412345678901');
      expect(extractReference('no reference here'), isNull);
    });
    test('DUP-01 same ref -> same id', () {
      String id(int t) => logicalEntryId(userId: 'u1', lineKey: 'HDFCBK|1234', direction: 'EXPENSE', amountPaise: 45000, epochSec: t, reference: 'R1');
      expect(id(100), id(118));
    });
    test('DUP-07 different ref -> different id', () {
      String id(String r) => logicalEntryId(userId: 'u1', lineKey: 'HDFCBK|1234', direction: 'EXPENSE', amountPaise: 5000, epochSec: 100, reference: r);
      expect(id('R1'), isNot(id('R2')));
    });
  });

  group('multipart (E)', () {
    test('MULTI-02 reassembles out of order', () {
      final r = reassemble([
        const SmsPart(refId: 'r1', partIndex: 2, totalParts: 2, text: 'world'),
        const SmsPart(refId: 'r1', partIndex: 1, totalParts: 2, text: 'hello '),
      ]);
      expect(r.complete, isTrue);
      expect(r.body, 'hello world');
    });
    test('MULTI-03 missing part flagged, no half-parse', () {
      final r = reassemble([const SmsPart(refId: 'r1', partIndex: 1, totalParts: 2, text: 'hi')]);
      expect(r.complete, isFalse);
      expect(r.body, isNull);
      expect(r.missing, [2]);
    });
  });
}
