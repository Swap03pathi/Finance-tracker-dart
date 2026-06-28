import 'package:flutter/material.dart';
import '../sync/sync_service.dart';
import 'transactions_screen.dart';

/// The three headline numbers (doc 01 §5) — income · expenses · savings — plus a category breakdown,
/// account balances, and a drill-in to the full transaction list. Data comes from the server.
class DashboardScreen extends StatefulWidget {
  final SyncService sync;
  const DashboardScreen({super.key, required this.sync});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  List<dynamic>? _byCategory;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.sync.fetchDashboard();
      final c = await widget.sync.fetchBreakdown('category');
      if (mounted) {
        setState(() {
          _data = d;
          _byCategory = c;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

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
    final cats = (_byCategory ?? const [])..sort((a, b) =>
        (double.tryParse('${b['amount']}') ?? 0).compareTo(double.tryParse('${a['amount']}') ?? 0));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (period['isThin'] == true)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('Showing ${period['label'] ?? 'since you installed'}. Your full picture builds as you go.'),
          ),
        _big('Income', d['income'], Colors.greenAccent),
        GestureDetector(onTap: _openTransactions, child: _big('Expenses', d['expenses'], Colors.redAccent, tap: true)),
        _big('Savings', d['savings'], Colors.lightBlueAccent),
        const SizedBox(height: 24),

        // ── spend by category ──
        Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (cats.isEmpty) const Text('No spending yet.'),
        ...cats.map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${c['label']}'),
                Text('₹${c['amount']}'),
              ]),
            )),
        const SizedBox(height: 24),

        // ── account balances ──
        Text('Account balances', style: Theme.of(context).textTheme.titleMedium),
        const Text('From your latest SMS per account — a snapshot, not part of income − expenses.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        if (balances.isEmpty) const Text('No balance-bearing messages yet.'),
        ...balances.map((b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text('${b['label'] ?? b['lineId']}', overflow: TextOverflow.ellipsis)),
                Text('₹${b['balance']}'),
              ]),
            )),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _openTransactions,
          icon: const Icon(Icons.receipt_long),
          label: const Text('View all transactions'),
        ),
      ],
    );
  }

  Widget _big(String label, dynamic amount, Color color, {bool tap = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            if (tap) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, size: 16)),
          ]),
          Text('₹${amount ?? '0.00'}', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}
