import 'dart:convert';
import 'package:finman_engine/finman_engine.dart' show categoryForMerchant;
import '../data/category_store.dart';
import '../data/database.dart';
import '../device/notify.dart';
import '../pipeline/ingest.dart';
import 'sync_client.dart';

class SyncReport {
  final int synced;
  final int induced;
  final List<String> uncategorised; // distinct expense merchants with no category yet
  final String? error;
  const SyncReport({this.synced = 0, this.induced = 0, this.uncategorised = const [], this.error});
}

/// Bumped when the on-device category rules change, to trigger a one-time recategorise of existing
/// entries (e.g. unknown merchants that used to default to Miscellaneous now become Uncategorised).
const _recatVersion = '2';

/// Orchestrates the device↔server loop (doc 03 §8): pilot dev-auth, drain the outbox, induce unknown
/// shapes (redacted skeleton only), pull + apply templates, re-parse anything newly covered, and
/// surface merchants that still need a category (prompt: push + in-app popup).
class SyncService {
  final LocalDb db;
  final SyncClient client;
  final CategoryStore categories;
  SyncService(this.db, this.client, this.categories);

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
      var synced2 = await client.drainSync(db);

      // one-time migration: re-derive categories for existing entries under the current rules
      if (await db.getState('recatVersion') != _recatVersion) {
        await recategorizeAll(db, userId);
        synced2 += await client.drainSync(db);
        await db.setState('recatVersion', _recatVersion);
      }

      final uncategorised = await _detectAndNotify();
      return SyncReport(synced: synced1 + synced2, induced: induced, uncategorised: uncategorised);
    } catch (e) {
      return SyncReport(error: e.toString());
    }
  }

  /// Distinct expense merchants on the server that still have no category. Fires a push notification
  /// once per never-before-seen such merchant (tracked in local state so we don't re-notify).
  Future<List<String>> _detectAndNotify() async {
    final entries = await client.fetchEntries();
    final merchants = <String>{};
    for (final e in entries) {
      final m = (e['merchantText'] as String?)?.trim();
      if (e['direction'] == 'EXPENSE' && m != null && m.isNotEmpty && categoryForMerchant(m) == null) {
        merchants.add(m);
      }
    }
    final notified = ((jsonDecode(await db.getState('notifiedMerchants') ?? '[]')) as List).cast<String>().toSet();
    for (final m in merchants) {
      if (notified.add(m)) await Notify.newMerchant(m);
    }
    await db.setState('notifiedMerchants', jsonEncode(notified.toList()));
    return merchants.toList()..sort();
  }

  /// Remember a merchant → category choice, then push the new category onto every matching entry.
  Future<void> assignCategory(String merchant, int categoryId) async {
    await categories.setOverride(merchant, categoryId);
    await ensureAuth();
    final userId = await deviceKey();
    await recategorizeAll(db, userId);
    await client.drainSync(db);
  }

  /// Add a new custom category (used by the picker's "Add new category"). Returns its id.
  Future<int> addCustomCategory(String name) => categories.addCustom(name);

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
