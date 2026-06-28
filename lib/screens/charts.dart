import 'dart:math' as math;
import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../src/money_fmt.dart';
import '../src/spend_analytics.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';

/// Series colour for a slice/stack index — single source of truth (the design-system ramp).
Color colorAt(int i) => AppColors.seriesAt(i);

/// Donut + legend for a list of [Slice]s. Tapping a slice or its legend row calls [onTap].
class DonutBreakdown extends StatefulWidget {
  final List<Slice> slices;
  final String centerLabel;
  final Decimal centerValue;
  final void Function(Slice slice)? onTap;
  const DonutBreakdown({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
    this.onTap,
  });
  @override
  State<DonutBreakdown> createState() => _DonutBreakdownState();
}

class _DonutBreakdownState extends State<DonutBreakdown> {
  static const double _hole = 64;
  int _touched = -1;
  int _lastTouched = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.slices.isEmpty) {
      return const EmptyState(icon: Icons.donut_large, title: 'No spending yet.');
    }
    return Column(children: [
      SizedBox(
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: _hole,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(touchCallback: (event, resp) {
              final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
              if (i >= 0) _lastTouched = i;
              if (event is FlTapUpEvent) {
                final pick = _lastTouched;
                _lastTouched = -1;
                setState(() => _touched = -1);
                if (pick >= 0 && pick < widget.slices.length) widget.onTap?.call(widget.slices[pick]);
                return;
              }
              setState(() => _touched = i);
            }),
            sections: [
              for (var i = 0; i < widget.slices.length; i++)
                PieChartSectionData(
                  value: widget.slices[i].amount.toDouble(),
                  color: colorAt(i),
                  radius: _touched == i ? 30 : 24,
                  showTitle: widget.slices[i].pct >= 0.08,
                  title: '${(widget.slices[i].pct * 100).round()}%',
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textInverse),
                ),
            ],
          )),
          SizedBox(
            width: 2 * _hole - 14,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.centerLabel.toUpperCase(), style: AppType.sectionLabel),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, child: Text(inr(widget.centerValue), style: AppType.title)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: AppSpacing.md),
      ...widget.slices.asMap().entries.map((e) => LabelledRow(
            dot: colorAt(e.key),
            label: e.value.label,
            pct: e.value.pct,
            value: inr(e.value.amount),
            trailingChevron: widget.onTap != null,
            onTap: widget.onTap == null ? null : () => widget.onTap!(e.value),
          )),
    ]);
  }
}

/// Stacked bar chart: one bar per month, each split by account/merchant. Legend lists the series.
class StackedMonthlyBars extends StatelessWidget {
  final MonthlyStacks data;
  const StackedMonthlyBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    // exact per-month totals (Decimal, never a float) for the tooltip + axis scaling
    final monthTotals = [for (final m in data.values) m.fold(Decimal.zero, (a, b) => a + b)];
    final dataMax = monthTotals.fold(0.0, (mx, t) => math.max(mx, t.toDouble()));
    final step = _niceStep(dataMax <= 0 ? 1 : dataMax / 4);
    final maxY = dataMax <= 0 ? step : step * ((dataMax / step).ceil() + (dataMax % step == 0 ? 1 : 0));
    final single = data.months.length == 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 240,
        child: BarChart(BarChartData(
          maxY: maxY,
          alignment: single ? BarChartAlignment.center : BarChartAlignment.spaceAround,
          groupsSpace: 28,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceHigh,
              getTooltipItem: (group, gi, rod, ri) {
                final m = group.x;
                final lines = <TextSpan>[];
                for (var a = 0; a < data.accounts.length; a++) {
                  final v = data.values[m][a];
                  if (v == Decimal.zero) continue;
                  lines.add(TextSpan(
                    text: '\n${data.accounts[a]}  ${inr(v)}',
                    style: TextStyle(color: colorAt(a), fontSize: 11, fontWeight: FontWeight.w600),
                  ));
                }
                return BarTooltipItem(
                  inr(monthTotals[m]),
                  const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  children: lines,
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: step,
                getTitlesWidget: (v, meta) =>
                    v >= meta.max ? const SizedBox.shrink() : Text(_short(v), style: AppType.caption),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(data.months[i], style: AppType.caption.copyWith(color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var m = 0; m < data.months.length; m++)
              BarChartGroupData(x: m, barRods: [_stackRod(data.values[m], single)]),
          ],
        )),
      ),
      const SizedBox(height: AppSpacing.lg),
      ...data.accounts.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colorAt(e.key), shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.sm),
              Text(e.value, style: AppType.caption.copyWith(color: AppColors.textSecondary)),
            ]),
          )),
    ]);
  }

  BarChartRodData _stackRod(List<Decimal> perAccount, bool single) {
    final stack = <BarChartRodStackItem>[];
    double from = 0;
    for (var a = 0; a < perAccount.length; a++) {
      final to = from + perAccount[a].toDouble();
      if (to > from) stack.add(BarChartRodStackItem(from, to, colorAt(a)));
      from = to;
    }
    return BarChartRodData(toY: from, width: single ? 48 : 22, borderRadius: BorderRadius.circular(4), rodStackItems: stack);
  }

  /// Round a rough axis step to a 'nice' 1/2/2.5/5 × 10ⁿ value, so ticks land on clean rupee amounts.
  static double _niceStep(double rough) {
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    final nice = norm <= 1 ? 1.0 : norm <= 2 ? 2.0 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5.0 : 10.0;
    return nice * mag;
  }

  /// Compact ₹ axis label using the SAME lakh/crore cut-points as inr() (so 1,00,000 reads 1L not 100k).
  static String _short(double v) {
    if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(v % 1e7 == 0 ? 0 : 1)}Cr';
    if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(v % 1e5 == 0 ? 0 : 1)}L';
    if (v >= 1e3) {
      final k = v / 1e3;
      return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
    }
    return v.toStringAsFixed(0);
  }
}
