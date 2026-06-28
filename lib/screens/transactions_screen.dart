import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:finman_engine/finman_engine.dart' show categoryName;
import '../src/money_fmt.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'category_picker.dart';

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

  /// Tap a transaction to (re)assign its merchant's category; the choice is remembered.
  Future<void> _changeCategory(String merchant) async {
    final id = await pickCategory(context, widget.sync, merchant: merchant);
    if (id == null || !mounted) return;
    setState(() => _rows = null);
    await widget.sync.assignCategory(merchant, id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: _error != null
          ? Padding(
              padding: AppSpacing.screen,
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Error: $_error',
                tint: AppColors.negative,
              ),
            )
          : _rows == null
              ? const Center(child: CircularProgressIndicator())
              : _rows!.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.receipt_long,
                        title: 'No transactions yet',
                        subtitle: 'Sync after capturing some SMS.',
                      ),
                    )
                  : RefreshIndicator(onRefresh: _load, child: _list(_rows!)),
    );
  }

  Widget _list(List<dynamic> rows) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(left: 64),
        child: Divider(height: 1),
      ),
      itemBuilder: (_, i) {
        final r = rows[i] as Map<String, dynamic>;
        final dir = r['direction'] as String;
        final counted = r['isCounted'] == true;
        final isIn = dir == 'INCOME';
        final isMove = dir == 'TRANSFER' || dir == 'TOPUP';
        final color = isMove ? AppColors.neutral : (isIn ? AppColors.positive : AppColors.negative);
        final when = r['txnTime'] != null ? (r['txnTime'] as String).split('T').first : '';
        final amt = Decimal.tryParse('${r['amountEffective']}') ?? Decimal.zero;
        final trailing = isMove ? inr(amt) : inrSigned(amt, positive: isIn);
        final merchant = (r['merchantText'] as String?)?.trim();
        final catId = r['categoryId'] as int?;
        final canTag = !isIn && !isMove && merchant != null && merchant.isNotEmpty;
        final meta = '${catId == null ? 'Tap to categorise' : categoryName(catId)} · ${r['modality']} · $when';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isMove ? Icons.swap_horiz : (isIn ? Icons.south_west : Icons.north_east),
              size: 18,
              color: color,
            ),
          ),
          title: Text(merchant ?? dir, style: AppType.body),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta, style: AppType.caption),
                if (!counted)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Not counted',
                        style: AppType.caption.copyWith(color: AppColors.neutral),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: Text(trailing, style: AppType.moneyRow.copyWith(color: color)),
          onTap: canTag ? () => _changeCategory(merchant) : null,
        );
      },
    );
  }
}
