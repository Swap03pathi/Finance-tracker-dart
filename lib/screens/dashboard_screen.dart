import 'package:flutter/material.dart';
import '../sync/sync_service.dart';

/// The three headline numbers (doc 01 §5) — income · expenses · savings + balances, period-honest.
/// Data comes from the server (system of record); the device renders it.
class DashboardScreen extends StatefulWidget {
  final SyncService sync;
  const DashboardScreen({super.key, required this.sync});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.sync.fetchDashboard();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [Padding(padding: const EdgeInsets.all(20), child: Text('Error: $_error'))])
            : _data == null
                ? const Center(child: CircularProgressIndicator())
                : _content(context, _data!),
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> d) {
    final period = (d['period'] as Map?) ?? const {};
    final balances = (d['balances'] as List?) ?? const [];
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
        _big('Expenses', d['expenses'], Colors.redAccent),
        _big('Savings', d['savings'], Colors.lightBlueAccent),
        const SizedBox(height: 24),
        Text('Balances', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (balances.isEmpty) const Text('No balance-bearing messages yet.'),
        ...balances.map((b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text('${b['lineId']}', overflow: TextOverflow.ellipsis)),
                Text('₹${b['balance']}'),
              ]),
            )),
      ],
    );
  }

  Widget _big(String label, dynamic amount, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text('₹${amount ?? '0.00'}', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}
