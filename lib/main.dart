import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:finman_engine/finman_engine.dart' show primeConfig;
import 'data/category_store.dart';
import 'data/database.dart';
import 'pipeline/ingest.dart';
import 'device/notify.dart';
import 'device/sms_channel.dart';
import 'device/db_open.dart';
import 'sync/sync_client.dart';
import 'sync/sync_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'theme/app_theme.dart';
import 'theme/widgets.dart';

/// Pilot server (HTTP, no TLS yet — allowed via network_security_config). Configurable.
const serverBaseUrl = 'http://18.206.195.183';

/// Load the doc 07 §6 rule data from bundled assets into the (Flutter-free) engine config cache.
Future<void> _primeConfigFromAssets() async {
  const names = [
    'gate-rules.json',
    'sender-normalisation.json',
    'own-node-senders.json',
    'merchant-vpa-dictionary.json', // cold-start category hints
  ];
  final loaded = <String, Map<String, dynamic>>{};
  for (final n in names) {
    loaded[n] = jsonDecode(await rootBundle.loadString('config/$n')) as Map<String, dynamic>;
  }
  primeConfig(loaded);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _primeConfigFromAssets();
  await Notify.init(); // local-notification channel + Android 13+ permission
  runApp(const FinmanApp());
}

class FinmanApp extends StatelessWidget {
  const FinmanApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Finman',
        theme: AppTheme.dark,
        home: const HomeShell(),
      );
}

/// App home: the **dashboard** is the first screen. SMS capture, sync and the scan-window control
/// live in the hamburger drawer (doc 03 §2 capture is still device-first; it's just out of the way).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Scan windows offered in the drawer. null = all time.
const _scanWindows = <int?, String>{
  30: 'Last 30 days',
  90: 'Last 3 months',
  180: 'Last 6 months',
  365: 'Last year',
  null: 'All time',
};

class _HomeShellState extends State<HomeShell> {
  final _sms = SmsChannel();
  LocalDb? _db;
  SyncService? _sync;
  String _userId = 'local-user';
  String _status = 'starting…';
  int _raw = 0, _pendingSync = 0, _pendingParse = 0;
  bool _busy = false;
  int? _scanDays = 180; // default scan window
  int _tick = 0; // bumped after a scan/sync to refresh the dashboard

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = await openDeviceDb();
    _db = db;
    final catStore = CategoryStore(db);
    await catStore.load(); // prime saved overrides + custom categories before any ingest
    final sync = SyncService(db, SyncClient(serverBaseUrl), catStore);
    _userId = await sync.deviceKey(); // stable id-gen namespace
    _sms.onSms = _ingest;
    final granted = await _sms.requestPermission();
    // Render the dashboard immediately; it fetches its own data. Scan + sync run in the BACKGROUND so
    // first paint is never blocked on the SMS sweep or the network round-trips.
    if (mounted) setState(() => _sync = sync);
    unawaited(_startupSync(granted));
  }

  Future<void> _startupSync(bool granted) async {
    if (granted) await _scan(initial: true); // incremental: only messages newer than the last checkpoint
    await _runSync(initial: true);
  }

  /// Scan the SMS inbox and ingest anything new (idempotent). The auto/initial scan is INCREMENTAL —
  /// only messages newer than the last-processed checkpoint — so launches don't re-sweep the whole
  /// window every time. A manual "Scan inbox" re-scans the chosen window (to backfill older messages).
  Future<void> _scan({bool initial = false}) async {
    if (_db == null || _busy) return;
    if (mounted) setState(() => _busy = true);
    final db = _db!;
    final checkpoint = int.tryParse(await db.getState('lastProcessedMs') ?? '0') ?? 0;
    final windowFloor = _scanDays == null ? 0 : DateTime.now().millisecondsSinceEpoch - _scanDays! * 86400000;
    final sinceMs = initial ? (checkpoint > windowFloor ? checkpoint : windowFloor) : windowFloor;
    final msgs = await _sms.querySweep(sinceMs);
    var maxTs = checkpoint;
    for (final m in msgs) {
      await ingestSms(_db!, userId: _userId, sender: m.sender, body: m.body, smsTimeMs: m.timeMs, messageId: m.messageId);
      if (m.timeMs > maxTs) maxTs = m.timeMs;
    }
    await db.setState('lastProcessedMs', maxTs.toString());
    await _refresh();
    if (mounted) {
      setState(() {
        _busy = false;
        _status = 'scanned ${msgs.length} message(s)';
      });
    }
  }

  Future<void> _ingest(SmsMessage m) async {
    await ingestSms(_db!, userId: _userId, sender: m.sender, body: m.body, smsTimeMs: m.timeMs, messageId: m.messageId);
    await _refresh();
  }

  Future<void> _runSync({bool initial = false}) async {
    if (_sync == null || _busy) return;
    setState(() => _busy = true);
    final report = await _sync!.runSync();
    await _refresh();
    if (mounted) {
      setState(() {
        _busy = false;
        _status = report.error != null ? 'sync error: ${report.error}' : 'synced ${report.synced}, induced ${report.induced}';
        _tick++; // refresh the dashboard with the latest data
      });
    }
  }

  Future<void> _refresh() async {
    final db = _db!;
    final raw = await db.select(db.localRawMessages).get();
    const big = 1 << 62;
    final ps = await db.dueJobs('pending_sync', big);
    final pp = await db.dueJobs('pending_parse', big);
    if (mounted) {
      setState(() {
        _raw = raw.length;
        _pendingSync = ps.length;
        _pendingParse = pp.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else
          IconButton(icon: const Icon(Icons.sync), tooltip: 'Sync now', onPressed: _sync == null ? null : _runSync),
        IconButton(
          icon: const Icon(Icons.receipt_long),
          tooltip: 'Transactions',
          onPressed: _sync == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionsScreen(sync: _sync!))),
        ),
      ]),
      drawer: _drawer(context),
      body: _sync == null
          ? const Center(child: CircularProgressIndicator())
          : DashboardScreen(sync: _sync!, refreshTick: _tick),
    );
  }

  Widget _drawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg), children: [
          // ── branded header ──
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md)),
              alignment: Alignment.center,
              child: const Icon(Icons.account_balance_wallet, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            const Text('Finman', style: AppType.title),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(_status, style: AppType.caption),
          const SizedBox(height: AppSpacing.lg),

          // ── scan window + actions ──
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                child: Row(children: [
                  const Expanded(child: Text('Scan messages from', style: AppType.body)),
                  const SizedBox(width: AppSpacing.sm),
                  DropdownButton<int?>(
                    value: _scanDays,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: AppColors.surfaceHigh,
                    onChanged: _busy ? null : (v) => setState(() => _scanDays = v),
                    items: [for (final e in _scanWindows.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  ),
                ]),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search),
                title: const Text('Scan inbox'),
                subtitle: Text(_scanWindows[_scanDays]!, style: AppType.caption),
                enabled: !_busy && _db != null,
                onTap: () {
                  Navigator.of(context).pop();
                  _scan();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: const Text('Sync now'),
                enabled: !_busy && _sync != null,
                onTap: () {
                  Navigator.of(context).pop();
                  _runSync();
                },
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── capture status ──
          const SectionHeader('Capture status'),
          SectionCard(
            child: Column(children: [
              _statusRow('Raw messages (device-local)', _raw),
              _statusRow('Parsed, queued to sync', _pendingSync),
              _statusRow('Unknown shape, awaiting induction', _pendingParse),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statusRow(String label, int n) => LabelledRow(
        label: label,
        value: '$n',
        valueColor: n > 0 ? AppColors.primary : AppColors.textTertiary,
      );
}
