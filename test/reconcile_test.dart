import 'package:decimal/decimal.dart';
import 'package:finman_engine/src/reconcile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> e({
  required String id,
  String line = 'L1',
  String label = 'HDFCBK ••1234',
  required String dir,
  required String amt,
  String? bal,
  required String t,
}) =>
    {
      'id': id,
      'lineId': line,
      'lineLabel': label,
      'direction': dir,
      'amountEffective': amt,
      'balanceAfter': bal,
      'txnTime': t,
    };

void main() {
  test('a clean account reconciles with no gaps', () {
    final r = reconcile([
      e(id: '1', dir: 'INCOME', amt: '65000', bal: '65000', t: '2026-06-01T10:00:00Z'),
      e(id: '2', dir: 'EXPENSE', amt: '1000', bal: '64000', t: '2026-06-02T10:00:00Z'),
    ]);
    expect(r.hasGaps, isFalse);
    expect(r.headline, isNull);
    expect(r.accounts.single.reconciles, isTrue);
  });

  test('off-by-₹1000: a debit larger than the parsed amount is flagged (not absorbed)', () {
    // balance fell 10000 → 6000 (−4000) but the message says ₹3000 → ₹1000 unexplained
    final r = reconcile([
      e(id: '1', dir: 'EXPENSE', amt: '500', bal: '10000', t: '2026-06-01T10:00:00Z'),
      e(id: '2', dir: 'EXPENSE', amt: '3000', bal: '6000', t: '2026-06-02T10:00:00Z'),
    ]);
    expect(r.hasGaps, isTrue);
    final gap = r.accountsNeedingReview.single.gaps.single;
    expect(gap.reason, GapReason.unexplainedDelta);
    expect(gap.unexplained, Decimal.parse('-1000'));
    expect(gap.magnitude, Decimal.parse('1000'));
    expect(r.totalUnexplained, Decimal.parse('1000'));
    expect(r.headline, contains('₹1,000'));
  });

  test('Slice silent interest: an un-messaged credit is flagged for review, never errored', () {
    // balance only fell 150 on a ₹200 spend → ₹50 credited with no SMS (daily interest)
    final r = reconcile([
      e(id: '1', line: 'S1', label: 'SLICE ••9000', dir: 'EXPENSE', amt: '100', bal: '5000', t: '2026-06-01T10:00:00Z'),
      e(id: '2', line: 'S1', label: 'SLICE ••9000', dir: 'EXPENSE', amt: '200', bal: '4850', t: '2026-06-02T10:00:00Z'),
    ]);
    expect(r.hasGaps, isTrue);
    final gap = r.accounts.single.gaps.single;
    expect(gap.reason, GapReason.silentCredit);
    expect(gap.unexplained, Decimal.parse('50'));
    expect(gap.humanReason, contains('likely interest'));
  });

  test('an unsigned transfer that moves the balance is flagged as unknown-direction', () {
    final r = reconcile([
      e(id: '1', line: 'T1', dir: 'EXPENSE', amt: '100', bal: '8000', t: '2026-06-01T10:00:00Z'),
      e(id: '2', line: 'T1', dir: 'TRANSFER', amt: '500', bal: '7500', t: '2026-06-02T10:00:00Z'),
    ]);
    expect(r.hasGaps, isTrue);
    expect(r.accounts.single.gaps.single.reason, GapReason.unknownDirection);
  });

  test('entries without a balance are skipped (no crash, no false gaps)', () {
    final r = reconcile([
      e(id: '1', dir: 'EXPENSE', amt: '100', bal: null, t: '2026-06-01T10:00:00Z'),
      e(id: '2', dir: 'EXPENSE', amt: '200', bal: null, t: '2026-06-02T10:00:00Z'),
    ]);
    expect(r.hasGaps, isFalse);
    expect(r.accounts, isEmpty);
  });
}
