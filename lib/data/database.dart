import 'package:drift/drift.dart';

part 'database.g.dart';

/// Local device store (doc 07 §3). Offline-first: parse + store locally ALWAYS; sync drains separately.
/// Raw bodies are NEVER synced (device-local + user's Drive in Phase 9).

/// Raw SMS — device-local only, never synced. Backed up to the user's Drive (Phase 9).
class LocalRawMessages extends Table {
  TextColumn get messageId => text()();
  TextColumn get sender => text()();
  TextColumn get body => text()();
  IntColumn get smsTimeMs => integer()();
  BoolColumn get processed => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {messageId};
}

/// Trusted templates pulled from the shared server library → instant offline local parse.
class LocalTemplateCache extends Table {
  TextColumn get fingerprint => text()();
  TextColumn get issuer => text().nullable()();
  TextColumn get regex => text()();
  TextColumn get slotMap => text()(); // JSON
  TextColumn get trustState => text()();
  @override
  Set<Column> get primaryKey => {fingerprint};
}

/// Durable offline queue: `pending_sync` (parsed, awaiting POST /entries) and `pending_parse`
/// (unknown template, awaiting server induction). Survives restart; retry/backoff via nextAttemptMs.
class LocalOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // 'pending_sync' | 'pending_parse'
  TextColumn get payload => text()(); // JSON
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptMs => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

/// Key/value device state: last-sync cursor, backfill checkpoint, own-node registry mirror.
class LocalState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [LocalRawMessages, LocalTemplateCache, LocalOutbox, LocalState])
class LocalDb extends _$LocalDb {
  LocalDb(super.e);

  @override
  int get schemaVersion => 1;

  // ── raw ────────────────────────────────────────────────────────────────────
  Future<void> putRaw(LocalRawMessagesCompanion row) =>
      into(localRawMessages).insertOnConflictUpdate(row);
  Future<void> markProcessed(String messageId) => (update(localRawMessages)
        ..where((t) => t.messageId.equals(messageId)))
      .write(const LocalRawMessagesCompanion(processed: Value(true)));

  // ── template cache ───────────────────────────────────────────────────────────
  Future<void> upsertTemplate(LocalTemplateCacheCompanion t) =>
      into(localTemplateCache).insertOnConflictUpdate(t);
  Future<LocalTemplateCacheData?> templateFor(String fingerprint) =>
      (select(localTemplateCache)..where((t) => t.fingerprint.equals(fingerprint)))
          .getSingleOrNull();

  // ── outbox ─────────────────────────────────────────────────────────────────
  Future<void> enqueue(LocalOutboxCompanion job) => into(localOutbox).insertOnConflictUpdate(job);
  Future<List<LocalOutboxData>> dueJobs(String kind, int nowMs) =>
      (select(localOutbox)..where((j) => j.kind.equals(kind) & j.nextAttemptMs.isSmallerOrEqualValue(nowMs)))
          .get();
  Future<void> dequeue(String id) => (delete(localOutbox)..where((j) => j.id.equals(id))).go();
  Future<void> backoff(String id, int attempts, int nextAttemptMs) =>
      (update(localOutbox)..where((j) => j.id.equals(id)))
          .write(LocalOutboxCompanion(attempts: Value(attempts), nextAttemptMs: Value(nextAttemptMs)));

  // ── state ────────────────────────────────────────────────────────────────────
  Future<void> setState(String key, String value) =>
      into(localState).insertOnConflictUpdate(LocalStateCompanion(key: Value(key), value: Value(value)));
  Future<String?> getState(String key) async =>
      (await (select(localState)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;
}
