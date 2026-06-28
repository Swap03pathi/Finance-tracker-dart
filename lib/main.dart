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
        theme: ThemeData.dark(useMaterial3: true),
        home: const CaptureScreen(),
      );
}

/// Capture screen: grant SMS, catch-up sweep, real-time capture, then sync + view the 3 numbers.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _sms = SmsChannel();
  LocalDb? _db;
  SyncService? _sync;
  String _userId = 'local-user';
  String _status = 'starting…';
  int _raw = 0, _pendingSync = 0, _pendingParse = 0;
  bool _busy = false;

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
    _sync = sync;
    _userId = await sync.deviceKey(); // stable id-gen namespace
    _sms.onSms = _ingest;
    final granted = await _sms.requestPermission();
    setState(() => _status = granted ? 'permission granted' : 'awaiting SMS permission');
    if (granted) await _sweep();
    await _refresh();
  }

  Future<void> _sweep() async {
    final db = _db!;
    final since = int.tryParse(await db.getState('lastProcessedMs') ?? '0') ?? 0;
    final msgs = await _sms.querySweep(since);
    var maxTs = since;
    for (final m in msgs) {
      await _ingest(m);
      if (m.timeMs > maxTs) maxTs = m.timeMs;
    }
    await db.setState('lastProcessedMs', maxTs.toString());
    setState(() => _status = 'swept ${msgs.length} message(s)');
  }

  Future<void> _ingest(SmsMessage m) async {
    await ingestSms(_db!, userId: _userId, sender: m.sender, body: m.body, smsTimeMs: m.timeMs, messageId: m.messageId);
    await _refresh();
  }

  Future<void> _syncAndDashboard() async {
    setState(() => _busy = true);
    final report = await _sync!.runSync();
    await _refresh();
    setState(() {
      _busy = false;
      _status = report.error != null ? 'sync error: ${report.error}' : 'synced ${report.synced}, induced ${report.induced}';
    });
    if (report.error == null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DashboardScreen(sync: _sync!)));
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
      appBar: AppBar(title: const Text('Finman — capture')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_status, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          _row('Raw messages stored (device-local)', _raw),
          _row('Parsed, queued to sync', _pendingSync),
          _row('Unknown shape, awaiting induction', _pendingParse),
          const SizedBox(height: 24),
          Row(children: [
            FilledButton.tonal(onPressed: _db == null || _busy ? null : _sweep, child: const Text('Scan inbox')),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _sync == null || _busy ? null : _syncAndDashboard,
              child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sync & dashboard'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _row(String label, int n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(label)),
          Text('$n', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}
