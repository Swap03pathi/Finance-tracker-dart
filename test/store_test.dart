import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finman_engine/data/database.dart';

/// Local store (3.C) — exercised against a real in-memory sqlite (NativeDatabase.memory()).
void main() {
  late LocalDb db;
  setUp(() => db = LocalDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('raw store + markProcessed (raw is device-local, never synced)', () async {
    await db.putRaw(LocalRawMessagesCompanion.insert(
        messageId: 'm1', sender: 'VM-HDFCBK', body: 'Rs 450 spent', smsTimeMs: 1));
    await db.markProcessed('m1');
    final row = await (db.select(db.localRawMessages)..where((t) => t.messageId.equals('m1'))).getSingle();
    expect(row.processed, isTrue);
  });

  test('template cache upsert + fetch', () async {
    await db.upsertTemplate(LocalTemplateCacheCompanion.insert(
        fingerprint: 'fp1', regex: r'^x$', slotMap: '{}', trustState: 'trusted', issuer: const Value('HDFCBK')));
    final t = await db.templateFor('fp1');
    expect(t, isNotNull);
    expect(t!.regex, r'^x$');
  });

  test('outbox enqueue / due / dequeue + backoff', () async {
    await db.enqueue(LocalOutboxCompanion.insert(id: 'j1', kind: 'pending_sync', payload: '{}'));
    expect((await db.dueJobs('pending_sync', 1000)).length, 1);
    await db.backoff('j1', 1, 999999); // pushed into the future
    expect((await db.dueJobs('pending_sync', 1000)).isEmpty, isTrue);
    await db.dequeue('j1');
    expect((await db.dueJobs('pending_sync', 9999999)).isEmpty, isTrue);
  });

  test('state get/set (sync cursor, checkpoint)', () async {
    await db.setState('cursor', '42');
    expect(await db.getState('cursor'), '42');
    await db.setState('cursor', '43');
    expect(await db.getState('cursor'), '43');
  });
}
