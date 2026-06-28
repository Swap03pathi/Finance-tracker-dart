import '../data/database.dart';
import '../pipeline/ingest.dart';
import 'sync_client.dart';

class SyncReport {
  final int synced;
  final int induced;
  final String? error;
  const SyncReport({this.synced = 0, this.induced = 0, this.error});
}

/// Orchestrates the device↔server loop (doc 03 §8): pilot dev-auth, drain the outbox, induce unknown
/// shapes (redacted skeleton only), pull + apply templates, and re-parse anything newly covered.
class SyncService {
  final LocalDb db;
  final SyncClient client;
  SyncService(this.db, this.client);

  /// A stable per-device key (also the id-gen namespace). The server maps it to a user.
  /// DEV: defaults to a shared key so the ingestion portal and the emulator see the SAME data.
  /// (A real per-device/random key returns with Google Sign-In in Phase 8.)
  static const devSharedKey = 'finman-dev-shared';
  Future<String> deviceKey() async {
    var k = await db.getState('deviceKey');
    if (k == null) {
      k = devSharedKey;
      await db.setState('deviceKey', k);
    }
    return k;
  }

  Future<void> ensureAuth() async {
    if (client.token != null) return;
    final saved = await db.getState('sessionToken');
    if (saved != null) {
      client.setToken(saved);
      return;
    }
    await client.authDev(await deviceKey());
    await db.setState('sessionToken', client.token!);
  }

  /// Full sync pass. Safe to call repeatedly (idempotent ids).
  Future<SyncReport> runSync() async {
    try {
      await ensureAuth();
      final userId = await deviceKey();
      await client.pullTemplates(db);
      await reprocessUnparsed(db, userId); // apply templates we already have
      final synced1 = await client.drainSync(db);
      final induced = await client.drainInduce(db); // caches newly-induced templates
      await reprocessUnparsed(db, userId); // apply the just-induced templates
      final synced2 = await client.drainSync(db);
      return SyncReport(synced: synced1 + synced2, induced: induced);
    } catch (e) {
      return SyncReport(error: e.toString());
    }
  }

  /// The three headline numbers from the server (system of record aggregation).
  Future<Map<String, dynamic>> fetchDashboard() async {
    await ensureAuth();
    return client.fetchDashboard();
  }

  Future<List<dynamic>> fetchEntries() async {
    await ensureAuth();
    return client.fetchEntries();
  }

  Future<List<dynamic>> fetchBreakdown(String by) async {
    await ensureAuth();
    return client.fetchBreakdown(by);
  }
}
