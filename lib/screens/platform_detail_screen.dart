import 'package:flutter/material.dart';
import '../src/money_fmt.dart';
import '../src/spend_analytics.dart';
import 'charts.dart';

/// L3 — one platform inside one category: spend split by account, plus month-by-month spend as a
/// stacked bar chart (X = month, Y = ₹, each bar stacked by the account that paid).
class PlatformDetailScreen extends StatelessWidget {
  final SpendData data;
  final int? categoryId;
  final String merchant;
  const PlatformDetailScreen({super.key, required this.data, required this.categoryId, required this.merchant});

  @override
  Widget build(BuildContext context) {
    final inCat = data.txns.where((t) => t.categoryId == categoryId).toList();
    final byAccount = byAccountForMerchant(inCat, merchant, data.labelFor);
    final monthly = monthlyByAccountForMerchant(inCat, merchant, data.labelFor);
    final total = totalOf(inCat.where((t) => t.merchant == merchant));

    return Scaffold(
      appBar: AppBar(title: Text(merchant)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Total spent here', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        Text(inr(total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        Text('By account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...byAccount.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colorAt(e.key), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value.label, overflow: TextOverflow.ellipsis)),
                Text(inr(e.value.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            )),
        const SizedBox(height: 28),

        Text('Month by month', style: Theme.of(context).textTheme.titleMedium),
        const Text('Each bar is a month; segments show which account paid.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        if (monthly.isEmpty) const Text('Not enough history yet.') else StackedMonthlyBars(data: monthly),
        const SizedBox(height: 24),
      ]),
    );
  }
}
