import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:finman_engine/finman_engine.dart' show primeConfig;
import 'data/database.dart';
import 'pipeline/ingest.dart';
import 'device/sms_channel.dart';
import 'device/db_open.dart';

/// Load the doc 07 §6 rule data from bundled assets into the (Flutter-free) engine config cache.
Future<void> _primeConfigFromAssets() async {
  const names = [
    'gate-rules.json',
    'sender-normalisation.json',
    'psp-suffixes.json',
    'own-node-senders.json',
    'merchant-vpa-dictionary.json',
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

/// Minimal device-core screen for Phase 4 dogfooding: grant SMS, catch-up sweep, live capture, and
/// show local counts. (The dashboard UI proper is a later phase.) userId is a placeholder until
/// Google sign-in (Phase 8); sync is wired in SyncClient and exercised in Phase 4.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const _userId = 'local-user'; // until Google sign-in (Phase 8)
  final _sms = SmsChannel();
  LocalDb? _db;
  String _status = 'starting…';
  int _raw = 0, _pendingSync = 0, _pendingParse = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = await openDeviceDb();
    _db = db;
    _sms.onSms = _ingest; // real-time capture while foregrounded
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
    await ingestSms(_db!,
        userId: _userId, sender: m.sender, body: m.body, smsTimeMs: m.timeMs, messageId: m.messageId);
    await _refresh();
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
          FilledButton(onPressed: _db == null ? null : _sweep, child: const Text('Scan inbox')),
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
