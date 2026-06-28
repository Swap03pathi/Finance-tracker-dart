import 'package:decimal/decimal.dart';
import 'categories.dart';

/// One spendable transaction, reduced to what the drill-down needs. Built from a server `/entries` row.
class Txn {
  final String lineId;
  final int? categoryId;
  final String merchant; // 'Unknown' when the SMS had no payee
  final Decimal amount; // rupees, exact (never a float — doc 07 §15)
  final DateTime time;
  final String direction;
  final bool counted;

  Txn({
    required this.lineId,
    required this.categoryId,
    required this.merchant,
    required this.amount,
    required this.time,
    required this.direction,
    required this.counted,
  });

  static Txn fromJson(Map<String, dynamic> j) => Txn(
        lineId: '${j['lineId']}',
        categoryId: j['categoryId'] as int?,
        merchant: (j['merchantText'] as String?)?.trim().isNotEmpty == true
            ? (j['merchantText'] as String).trim()
            : 'Unknown',
        amount: Decimal.tryParse('${j['amountEffective']}') ?? Decimal.zero,
        time: DateTime.tryParse('${j['txnTime']}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        direction: '${j['direction']}',
        counted: j['isCounted'] == true,
      );
}

/// The spend dataset threaded through the drill-down screens: every counted expense + the
/// human-readable label for each account line (so screens never re-fetch or show a raw UUID).
class SpendData {
  final List<Txn> txns;
  final Map<String, String> lineLabel;
  const SpendData(this.txns, this.lineLabel);
  String labelFor(String lineId) => lineLabel[lineId] ?? 'Account';
}

/// A weighted slice for a donut / list: a labelled bucket, its total, and its share of the parent total.
class Slice {
  final String key; // categoryId or merchant or lineId
  final String label;
  final Decimal amount;
  final double pct; // 0..1 of the parent total
  const Slice({required this.key, required this.label, required this.amount, required this.pct});
}

/// Stacked-bar data: months on X, one stack segment per account, [values] indexed [month][account].
class MonthlyStacks {
  final List<String> months; // x-axis labels, chronological, e.g. "Jun '26"
  final List<String> accounts; // legend + stack order
  final List<List<Decimal>> values; // values[monthIdx][accountIdx]
  const MonthlyStacks({required this.months, required this.accounts, required this.values});
  bool get isEmpty => months.isEmpty;
}

/// The counted EXPENSE rows (the only thing that drives spend breakdowns — doc 07 §15: transfers,
/// top-ups, income, holds etc. never count). Income/movement is filtered out here.
List<Txn> expenseTxns(List<dynamic> entries) => entries
    .map((e) => Txn.fromJson(e as Map<String, dynamic>))
    .where((t) => t.direction == 'EXPENSE' && t.counted)
    .toList();

List<Slice> _slices(Iterable<Txn> txns, String Function(Txn) keyOf, String Function(Txn) labelOf) {
  final sums = <String, Decimal>{};
  final labels = <String, String>{};
  var total = Decimal.zero;
  for (final t in txns) {
    final k = keyOf(t);
    sums[k] = (sums[k] ?? Decimal.zero) + t.amount;
    labels[k] = labelOf(t);
    total += t.amount;
  }
  final out = sums.entries
      .map((e) => Slice(
            key: e.key,
            label: labels[e.key]!,
            amount: e.value,
            pct: total == Decimal.zero ? 0 : (e.value / total).toDouble(),
          ))
      .toList()
    // amount desc, then label asc — the SAME comparator the monthly stacks use, so a donut and the
    // stacked bar beneath it always assign colours in the same order (even on equal totals).
    ..sort((a, b) {
      final c = b.amount.compareTo(a.amount);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  return out;
}

/// L1 — category-wise spend.
List<Slice> byCategory(List<Txn> txns) =>
    _slices(txns, (t) => '${t.categoryId ?? -1}', (t) => categoryName(t.categoryId));

/// L2 — within one category, spend by platform/merchant.
List<Slice> byMerchantInCategory(List<Txn> txns, int? categoryId) =>
    _slices(txns.where((t) => t.categoryId == categoryId), (t) => t.merchant, (t) => t.merchant);

/// L3a — within one platform, spend by account (line). [label] maps lineId → "HDFCBK ••1234".
List<Slice> byAccountForMerchant(List<Txn> txns, String merchant, String Function(String) label) =>
    _slices(txns.where((t) => t.merchant == merchant), (t) => t.lineId, (t) => label(t.lineId));

Decimal totalOf(Iterable<Txn> txns) =>
    txns.fold(Decimal.zero, (a, t) => a + t.amount);

/// Month-by-month spend, each bar stacked by some key (account, merchant, …). Generic so the same
/// stacked-bar widget serves both the platform view (stack by account) and the category view (stack
/// by merchant). [keyOf] picks the stack dimension; [labelOf] turns a key into a legend label.
MonthlyStacks _monthlyStacks(List<Txn> rows, String Function(Txn) keyOf, String Function(String) labelOf) {
  if (rows.isEmpty) return const MonthlyStacks(months: [], accounts: [], values: []);

  String mkey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  const mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final monthKeys = rows.map((t) => mkey(t.time)).toSet().toList()..sort();
  // order the stack series by total spend (desc) so the colours line up with the donut above it,
  // with a label tiebreak for deterministic ordering when totals are equal
  final seriesTotal = <String, Decimal>{};
  for (final t in rows) {
    seriesTotal[keyOf(t)] = (seriesTotal[keyOf(t)] ?? Decimal.zero) + t.amount;
  }
  final seriesKeys = seriesTotal.keys.toList()
    ..sort((a, b) {
      final c = seriesTotal[b]!.compareTo(seriesTotal[a]!);
      return c != 0 ? c : labelOf(a).compareTo(labelOf(b));
    });

  final values = [
    for (final mk in monthKeys)
      [
        for (final s in seriesKeys)
          rows
              .where((t) => mkey(t.time) == mk && keyOf(t) == s)
              .fold(Decimal.zero, (a, t) => a + t.amount),
      ],
  ];

  final monthLabels = monthKeys.map((mk) {
    final p = mk.split('-');
    return "${mon[int.parse(p[1])]} '${p[0].substring(2)}";
  }).toList();

  return MonthlyStacks(months: monthLabels, accounts: seriesKeys.map(labelOf).toList(), values: values);
}

/// L3b — within one platform, month-by-month spend stacked by account.
MonthlyStacks monthlyByAccountForMerchant(List<Txn> txns, String merchant, String Function(String) label) =>
    _monthlyStacks(txns.where((t) => t.merchant == merchant).toList(), (t) => t.lineId, label);

/// L2b — within one category, month-by-month spend stacked by platform/merchant.
MonthlyStacks monthlyByMerchantInCategory(List<Txn> txns, int? categoryId) =>
    _monthlyStacks(txns.where((t) => t.categoryId == categoryId).toList(), (t) => t.merchant, (m) => m);
