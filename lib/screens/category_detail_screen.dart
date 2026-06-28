import 'package:flutter/material.dart';
import '../src/spend_analytics.dart';
import 'charts.dart';
import 'platform_detail_screen.dart';

/// L2 — one category (e.g. Food): a donut of that category's spend split by platform/merchant.
/// Tap a platform to drill into per-account + month-by-month detail.
class CategoryDetailScreen extends StatelessWidget {
  final SpendData data;
  final int? categoryId;
  final String categoryLabel;
  const CategoryDetailScreen({super.key, required this.data, required this.categoryId, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    final inCat = data.txns.where((t) => t.categoryId == categoryId).toList();
    final platforms = byMerchantInCategory(data.txns, categoryId);

    return Scaffold(
      appBar: AppBar(title: Text(categoryLabel)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Where your $categoryLabel spend went', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        DonutBreakdown(
          slices: platforms,
          centerLabel: categoryLabel,
          centerValue: totalOf(inCat),
          onTap: (s) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PlatformDetailScreen(data: data, categoryId: categoryId, merchant: s.label),
          )),
        ),
        const SizedBox(height: 8),
        const Text('Tap a platform for per-account and month-by-month detail.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}
