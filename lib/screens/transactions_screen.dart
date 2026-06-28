import 'package:flutter/material.dart';
import 'package:finman_engine/finman_engine.dart' show categoryName;
import '../sync/sync_service.dart';

/// The ledger (doc 05 §S2): every synced transaction, honest + chronological, so the headline numbers
/// are explainable. Each row shows merchant, amount, direction, category and date.
class TransactionsScreen extends StatefulWidget {
  final SyncService sync;
  const TransactionsScreen({super.key, required this.sync});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<dynamic>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.sync.fetchEntries();
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(20), child: Text('Error: $_error'))
          : _rows == null
              ? const Center(child: CircularProgressIndicator())
              : _rows!.isEmpty
                  ? const Center(child: Text('No transactions yet — sync after capturing some SMS.'))
                  : RefreshIndicator(onRefresh: _load, child: _list(_rows!)),
    );
  }

  Widget _list(List<dynamic> rows) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = rows[i] as Map<String, dynamic>;
        final dir = r['direction'] as String;
        final counted = r['isCounted'] == true;
        final isIn = dir == 'INCOME';
        final isMove = dir == 'TRANSFER' || dir == 'TOPUP';
        final color = isMove ? Colors.grey : (isIn ? Colors.greenAccent : Colors.redAccent);
        final sign = isMove ? '' : (isIn ? '+' : '−');
        final when = r['txnTime'] != null ? (r['txnTime'] as String).split('T').first : '';
        return ListTile(
          leading: Icon(isMove ? Icons.swap_horiz : (isIn ? Icons.south_west : Icons.north_east), color: color),
          title: Text(r['merchantText'] ?? dir),
          subtitle: Text('${categoryName(r['categoryId'] as int?)} · ${r['modality']} · $when'
              '${counted ? '' : ' · not counted'}'),
          trailing: Text('$sign₹${r['amountEffective']}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        );
      },
    );
  }
}
