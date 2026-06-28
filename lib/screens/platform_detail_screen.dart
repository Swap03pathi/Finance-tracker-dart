import 'package:flutter/material.dart';
import '../src/money_fmt.dart';
import '../src/spend_analytics.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
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
      body: ListView(padding: AppSpacing.screen, children: [
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TOTAL SPENT HERE', style: AppType.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            Text(inr(total), style: AppType.display),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeader('By account'),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...byAccount.asMap().entries.map((e) => LabelledRow(
                    dot: colorAt(e.key),
                    label: e.value.label,
                    value: inr(e.value.amount),
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionHeader('Month by month',
            caption: 'Each bar is a month; segments show which account paid.'),
        if (monthly.isEmpty)
          const SectionCard(child: EmptyState(icon: Icons.bar_chart, title: 'Not enough history yet.'))
        else
          SectionCard(child: StackedMonthlyBars(data: monthly)),
        const SizedBox(height: AppSpacing.xl),
      ]),
    );
  }
}
