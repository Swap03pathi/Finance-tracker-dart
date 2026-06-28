import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../src/money_fmt.dart';
import '../src/reconcile.dart';
import '../src/spend_analytics.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'category_detail_screen.dart';
import 'category_picker.dart';
import 'charts.dart';
import 'transactions_screen.dart';

/// Home (doc 01 §5): the three headline numbers + a category-spend donut that drills down
/// category → platform → per-account / month-by-month. Data comes from the server, aggregated on-device.
class DashboardScreen extends StatefulWidget {
  final SyncService sync;

  /// Bumped by the host shell after a scan/sync so the dashboard reloads its data.
  final int refreshTick;
  const DashboardScreen({super.key, required this.sync, this.refreshTick = 0});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  SpendData? _spend;
  List<String> _uncategorised = const [];
  ReconciliationResult? _recon;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshTick != widget.refreshTick) _load(); // host scanned/synced → refresh
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
      // expense merchants with no category yet → prompt the user to tag them
      final uncats = <String>{};
      for (final e in entries) {
        final m = (e['merchantText'] as String?)?.trim();
        if (e['direction'] == 'EXPENSE' && e['categoryId'] == null && m != null && m.isNotEmpty) uncats.add(m);
      }
      if (mounted) {
        setState(() {
          _data = d;
          _spend = SpendData(expenseTxns(entries), lineLabel);
          _uncategorised = uncats.toList()..sort();
          _recon = reconcile(entries); // balance check (silent until balanceAfter is on /entries)
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Prompt for a category for [merchant], remember it, and refresh.
  Future<void> _assign(String merchant) async {
    final id = await pickCategory(context, widget.sync, merchant: merchant);
    if (id == null || !mounted) return;
    setState(() => _data = null); // show the spinner while we recategorise + re-sync
    await widget.sync.assignCategory(merchant, id);
    await _load();
  }

  Decimal _dec(dynamic s) => Decimal.tryParse('$s') ?? Decimal.zero;

  void _openTransactions() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionsScreen(sync: widget.sync)));

  @override
  Widget build(BuildContext context) {
    // Body only — the HomeShell provides the Scaffold, app bar (with the hamburger menu) and drawer.
    if (_error != null) {
      return Padding(
        padding: AppSpacing.screen,
        child: EmptyState(icon: Icons.error_outline, title: 'Could not load', subtitle: _error, tint: AppColors.negative),
      );
    }
    if (_data == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: _content(context, _data!));
  }

  Widget _content(BuildContext context, Map<String, dynamic> d) {
    final period = (d['period'] as Map?) ?? const {};
    final balances = (d['balances'] as List?) ?? const [];
    final cats = byCategory(_spend!.txns);
    final recon = _recon;
    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (period['isThin'] == true) ...[
          AttentionBanner(
            icon: Icons.info_outline,
            color: AppColors.warning,
            child: Text('Showing ${period['label'] ?? 'since you installed'}. Your full picture builds as you go.',
                style: AppType.body),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── balance reconciliation: unexplained gaps need a look ──
        if (recon != null && recon.hasGaps) ...[
          _needsReviewCard(recon),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── merchants needing a category ──
        if (_uncategorised.isNotEmpty) ...[
          _needsCategoryCard(),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── headline numbers ──
        Row(children: [
          Expanded(child: StatTile(label: 'Income', value: inr(_dec(d['income'])), color: AppColors.positive)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: StatTile(
                label: 'Expenses', value: inr(_dec(d['expenses'])), color: AppColors.negative, onTap: _openTransactions),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        StatTile(label: 'Savings', value: inr(_dec(d['savings'])), color: AppColors.primary, emphasize: true),
        const SizedBox(height: AppSpacing.xl),

        // ── category donut (tap → drill-down) ──
        const SectionHeader('Spending by category', caption: 'Tap a category to see platforms, accounts and months.'),
        SectionCard(
          child: DonutBreakdown(
            slices: cats,
            centerLabel: 'Spent',
            centerValue: _dec(d['expenses']),
            onTap: (s) {
              final cid = int.tryParse(s.key);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    CategoryDetailScreen(data: _spend!, categoryId: cid == -1 ? null : cid, categoryLabel: s.label),
              ));
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── account balances (snapshot) ──
        const SectionHeader('Account balances',
            caption: 'Latest balance per account from your SMS — a snapshot, not part of income − expenses.'),
        SectionCard(
          child: balances.isEmpty
              ? const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No balance-bearing messages yet.')
              : Column(
                  children: balances
                      .map((b) => LabelledRow(label: '${b['label'] ?? b['lineId']}', value: inr(_dec(b['balance']))))
                      .toList(),
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openTransactions,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('View all transactions'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// DF-3: per-account balance gaps that don't reconcile (Slice-aware — a flag, never a hard error).
  Widget _needsReviewCard(ReconciliationResult recon) {
    return AttentionBanner(
      icon: Icons.fact_check_outlined,
      color: AppColors.warning,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(recon.headline ?? 'Needs review', style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text('A transaction may be missing or mis-read — or it could be un-messaged activity (e.g. interest).',
            style: AppType.caption),
        const SizedBox(height: AppSpacing.sm),
        ...recon.accountsNeedingReview.map((a) => LabelledRow(
              label: a.lineLabel,
              value: inr(a.totalUnexplained),
              valueColor: AppColors.warning,
            )),
      ]),
    );
  }

  Widget _needsCategoryCard() {
    return AttentionBanner(
      icon: Icons.label_important_outline,
      color: AppColors.warning,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_uncategorised.length} merchant${_uncategorised.length == 1 ? '' : 's'} need a category',
            style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text('Tap to assign — your choice is remembered for next time.', style: AppType.caption),
        const SizedBox(height: AppSpacing.xs),
        ..._uncategorised.map((m) => LabelledRow(
              label: m,
              trailingChevron: true,
              onTap: () => _assign(m),
            )),
      ]),
    );
  }
}
