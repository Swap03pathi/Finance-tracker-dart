import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../src/money_fmt.dart';
import '../src/spend_analytics.dart';

/// A stable, colour-blind-friendly palette. Index by slice position so the same bucket keeps its colour.
const spendPalette = <Color>[
  Color(0xFF7C9EFF), // indigo
  Color(0xFFFF8FA3), // rose
  Color(0xFF5BD1B7), // teal
  Color(0xFFFFC861), // amber
  Color(0xFFB28DFF), // violet
  Color(0xFF7ED957), // green
  Color(0xFFFF9F68), // orange
  Color(0xFF63C7FF), // sky
];
Color colorAt(int i) => spendPalette[i % spendPalette.length];

/// Donut + legend for a list of [Slice]s. Tapping a slice or its legend row calls [onTap].
/// [centerLabel]/[centerValue] fill the hole (e.g. "Spent" / "₹16,670").
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
  int _touched = -1;
  int _lastTouched = -1; // last slice under the finger, used to navigate on tap-up

  @override
  Widget build(BuildContext context) {
    if (widget.slices.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No spending yet.')));
    }
    return Column(children: [
      SizedBox(
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 64,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(touchCallback: (event, resp) {
              // Track the slice currently under the finger. On lift fl_chart reports a null section,
              // so we navigate using the LAST highlighted slice — making the donut itself tappable.
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
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
            ],
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.centerLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(inr(widget.centerValue), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      ...widget.slices.asMap().entries.map((e) => _legendRow(e.key, e.value)),
    ]);
  }

  Widget _legendRow(int i, Slice s) => InkWell(
        onTap: widget.onTap == null ? null : () => widget.onTap!(s),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: colorAt(i), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Text(s.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
            Text('${(s.pct * 100).round()}%', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(width: 12),
            Text(inr(s.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if (widget.onTap != null)
              const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.chevron_right, size: 18, color: Colors.grey)),
          ]),
        ),
      );
}

/// Stacked bar chart: one bar per month, each split by account. Legend lists accounts with their colour.
class StackedMonthlyBars extends StatelessWidget {
  final MonthlyStacks data;
  const StackedMonthlyBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    double maxY = 0;
    for (final month in data.values) {
      final sum = month.fold(Decimal.zero, (a, b) => a + b).toDouble();
      if (sum > maxY) maxY = sum;
    }
    maxY = maxY == 0 ? 1 : maxY * 1.15;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 240,
        child: BarChart(BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                inr(Decimal.parse(rod.toY.toStringAsFixed(2))),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) =>
                    v == meta.max ? const SizedBox.shrink() : Text(_short(v), style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(data.months[i], style: const TextStyle(fontSize: 10)));
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var m = 0; m < data.months.length; m++)
              BarChartGroupData(x: m, barRods: [_stackRod(data.values[m])]),
          ],
        )),
      ),
      const SizedBox(height: 16),
      ...data.accounts.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: colorAt(e.key), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(e.value, style: const TextStyle(fontSize: 13)),
            ]),
          )),
    ]);
  }

  BarChartRodData _stackRod(List<Decimal> perAccount) {
    final stack = <BarChartRodStackItem>[];
    double from = 0;
    for (var a = 0; a < perAccount.length; a++) {
      final to = from + perAccount[a].toDouble();
      if (to > from) stack.add(BarChartRodStackItem(from, to, colorAt(a)));
      from = to;
    }
    return BarChartRodData(toY: from, width: 22, borderRadius: BorderRadius.circular(4), rodStackItems: stack);
  }

  static String _short(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}
