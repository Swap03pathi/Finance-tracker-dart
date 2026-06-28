import 'package:decimal/decimal.dart';
import 'package:finman_engine/src/money_fmt.dart';
import 'package:finman_engine/src/spend_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);

Map<String, dynamic> row({
  required String line,
  int? cat,
  String? merchant,
  required String amt,
  required String time,
  String dir = 'EXPENSE',
  bool counted = true,
}) =>
    {
      'lineId': line,
      'lineLabel': line == 'L1' ? 'HDFCBK ••1234' : 'SBIINB ••3456',
      'categoryId': cat,
      'merchantText': merchant,
      'amountEffective': amt,
      'txnTime': time,
      'direction': dir,
      'isCounted': counted,
    };

void main() {
  group('inr money formatting', () {
    test('Indian grouping and dropping .00', () {
      expect(inr(d('65000')), '₹65,000');
      expect(inr(d('100000')), '₹1,00,000');
      expect(inr(d('12470.00')), '₹12,470');
      expect(inr(d('245678.50')), '₹2,45,678.50');
      expect(inr(d('450')), '₹450');
      expect(inr(d('0')), '₹0');
    });
    test('signed', () {
      expect(inrSigned(d('65000'), positive: true), '+₹65,000');
      expect(inrSigned(d('450'), positive: false), '−₹450');
    });
  });

  group('drill-down aggregation', () {
    final entries = <dynamic>[
      row(line: 'L1', cat: 1, merchant: 'Zomato', amt: '450', time: '2026-06-10T10:00:00Z'),
      row(line: 'L1', cat: 1, merchant: 'Zomato', amt: '550', time: '2026-05-09T10:00:00Z'),
      row(line: 'L2', cat: 1, merchant: 'Swiggy', amt: '1000', time: '2026-06-12T10:00:00Z'),
      row(line: 'L1', cat: 2, merchant: 'Amazon', amt: '1200', time: '2026-06-12T10:00:00Z'),
      // not counted / non-expense must be excluded
      row(line: 'L1', cat: 1, merchant: 'Zomato', amt: '999', time: '2026-06-12T10:00:00Z', counted: false),
      row(line: 'L2', merchant: null, amt: '65000', time: '2026-06-01T10:00:00Z', dir: 'INCOME'),
    ];
    final txns = expenseTxns(entries);
    String label(String id) => id == 'L1' ? 'HDFCBK ••1234' : 'SBIINB ••3456';

    test('only counted expenses are kept', () {
      expect(txns.length, 4); // the not-counted row and the INCOME row are dropped
    });

    test('L1 byCategory totals + share', () {
      final cats = byCategory(txns);
      expect(cats.first.label, 'Food'); // 450+550+1000 = 2000 > Shopping 1200
      expect(cats.first.amount, d('2000'));
      expect(cats.firstWhere((c) => c.label == 'Shopping').amount, d('1200'));
      // percentages reconcile to 1.0
      final pctSum = cats.fold<double>(0, (a, c) => a + c.pct);
      expect((pctSum - 1.0).abs() < 1e-9, true);
    });

    test('L2 byMerchant within Food', () {
      final m = byMerchantInCategory(txns, 1);
      expect(m.map((s) => s.label).toSet(), {'Zomato', 'Swiggy'});
      expect(m.firstWhere((s) => s.label == 'Zomato').amount, d('1000')); // 450 + 550
    });

    test('L3 byAccount for Zomato spans both months/accounts', () {
      final a = byAccountForMerchant(txns, 'Zomato', label);
      expect(a.length, 1); // both Zomato rows are on L1
      expect(a.first.amount, d('1000'));
    });

    test('L3 monthly stacks: two months, account-keyed', () {
      final ms = monthlyByAccountForMerchant(txns, 'Zomato', label);
      expect(ms.months.length, 2); // May + Jun
      expect(ms.accounts, ['HDFCBK ••1234']);
      // Jun (second month) total = 450
      final junIdx = ms.months.indexWhere((m) => m.startsWith('Jun'));
      expect(ms.values[junIdx][0], d('450'));
    });
  });
}
