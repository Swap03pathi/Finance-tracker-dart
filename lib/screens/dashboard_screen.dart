import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../src/money_fmt.dart';
import '../src/spend_analytics.dart';
import '../sync/sync_service.dart';
import 'category_detail_screen.dart';
import 'charts.dart';
import 'transactions_screen.dart';

/// Home (doc 01 §5): the three headline numbers + a category-spend donut that drills down
/// category → platform → per-account / month-by-month. Data comes from the server, aggregated on-device.
class DashboardScreen extends StatefulWidget {
  final SyncService sync;
  const DashboardScreen({super.key, required this.sync});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  SpendData? _spend;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.sync.fetchDashboard();
      final entries = await widget.sync.fetchEntries();
      // Account labels: seed from the dashboard balances (always labelled), then let any per-entry
      // lineLabel (newer server) override. Either way the drill-down never shows a raw UUID.
      final lineLabel = <String, String>{};
      for (final b in (d['balances'] as List? ?? const [])) {
        if (b['label'] != null) lineLabel['${b['lineId']}'] = '${b['label']}';
      }
      for (final e in entries) {
        if (e['lineLabel'] != null) lineLabel['${e['lineId']}'] = '${e['lineLabel']}';
      }
      if (mounted) {
        setState(() {
          _data = d;
          _spend = SpendData(expenseTxns(entries), lineLabel);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Decimal _dec(dynamic s) => Decimal.tryParse('$s') ?? Decimal.zero;

  void _openTransactions() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionsScreen(sync: widget.sync)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [
        IconButton(icon: const Icon(Icons.receipt_long), tooltip: 'Transactions', onPressed: _openTransactions),
      ]),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(20), child: Text('Error: $_error'))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _content(context, _data!)),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> d) {
    final period = (d['period'] as Map?) ?? const {};
    final balances = (d['balances'] as List?) ?? const [];
    final cats = byCategory(_spend!.txns);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (period['isThin'] == true)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text('Showing ${period['label'] ?? 'since you installed'}. Your full picture builds as you go.')),
            ]),
          ),

        // ── headline numbers as cards ──
        Row(children: [
          _stat('Income', _dec(d['income']), const Color(0xFF7ED957)),
          const SizedBox(width: 10),
          _stat('Expenses', _dec(d['expenses']), const Color(0xFFFF8FA3), onTap: _openTransactions),
        ]),
        const SizedBox(height: 10),
        _stat('Savings', _dec(d['savings']), const Color(0xFF63C7FF), wide: true),
        const SizedBox(height: 24),

        // ── category donut (tap → drill-down) ──
        Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
        const Text('Tap a category to see platforms, accounts and months.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        DonutBreakdown(
          slices: cats,
          centerLabel: 'Spent',
          centerValue: _dec(d['expenses']),
          onTap: (s) {
            final cid = int.tryParse(s.key);
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryDetailScreen(data: _spend!, categoryId: cid == -1 ? null : cid, categoryLabel: s.label),
            ));
          },
        ),
        const SizedBox(height: 24),

        // ── account balances (snapshot) ──
        Text('Account balances', style: Theme.of(context).textTheme.titleMedium),
        const Text('Latest balance per account from your SMS — a snapshot, not part of income − expenses.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        if (balances.isEmpty) const Text('No balance-bearing messages yet.'),
        ...balances.map((b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text('${b['label'] ?? b['lineId']}', overflow: TextOverflow.ellipsis)),
                Text(inr(_dec(b['balance'])), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            )),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _openTransactions,
          icon: const Icon(Icons.receipt_long),
          label: const Text('View all transactions'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _stat(String label, Decimal amount, Color color, {bool wide = false, VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          if (onTap != null) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right, size: 14, color: Colors.grey)),
        ]),
        const SizedBox(height: 6),
        FittedBox(child: Text(inr(amount), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color))),
      ]),
    );
    final tappable = onTap == null ? card : InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: card);
    return wide ? SizedBox(width: double.infinity, child: tappable) : Expanded(child: tappable);
  }
}
