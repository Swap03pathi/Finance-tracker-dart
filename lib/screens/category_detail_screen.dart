import 'package:flutter/material.dart';
import '../src/spend_analytics.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
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
    final monthly = monthlyByMerchantInCategory(data.txns, categoryId);

    return Scaffold(
      appBar: AppBar(title: Text(categoryLabel)),
      body: ListView(padding: AppSpacing.screen, children: [
        SectionHeader('Where your $categoryLabel spend went',
            caption: 'Tap a platform for per-account and month-by-month detail.'),
        SectionCard(
          child: DonutBreakdown(
            slices: platforms,
            centerLabel: categoryLabel,
            centerValue: totalOf(inCat),
            onTap: (s) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlatformDetailScreen(data: data, categoryId: categoryId, merchant: s.label),
            )),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeader('Month by month',
            caption: 'Each bar is a month; segments show which platform you spent on.'),
        SectionCard(
          child: monthly.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart,
                  title: 'Not enough history yet.',
                  subtitle: 'Spend across a couple of months to see the trend.')
              : StackedMonthlyBars(data: monthly),
        ),
      ]),
    );
  }
}
