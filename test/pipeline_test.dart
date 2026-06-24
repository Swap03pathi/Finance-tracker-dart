import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:finman_engine/finman_engine.dart';
import 'package:finman_engine/data/database.dart';
import 'package:finman_engine/pipeline/ingest.dart';

/// Ingestion pipeline end-to-end against a real in-memory sqlite (3.D).
void main() {
  late LocalDb db;
  setUp(() => db = LocalDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  final tv = jsonDecode(File('golden-vectors/template-vectors.json').readAsStringSync())['vectors'] as List;
  final hdfc1 = tv[0]['body'] as String;
  final regex = tv[0]['regex'] as String;
  const bigMs = 9999999999999;

  Future<void> seedTemplate() => db.upsertTemplate(LocalTemplateCacheCompanion.insert(
      fingerprint: fingerprint(hdfc1), regex: regex, slotMap: '{}', trustState: 'trusted', issuer: const Value('HDFCBK')));

  test('HIT: known template -> pending_sync entry with correct classified fields', () async {
    await seedTemplate();
    final r = await ingestSms(db, userId: 'u1', sender: 'VM-HDFCBK', body: hdfc1, smsTimeMs: 1717322400000, messageId: 'm1');
    expect(r.outcome, 'synced_queued');
    final jobs = await db.dueJobs('pending_sync', bigMs);
    expect(jobs.length, 1);
    final e = jsonDecode(jobs.first.payload);
    expect(e['direction'], 'EXPENSE');
    expect(e['modality'], 'actual');
    expect(e['amountCaptured'], '450.00');
    expect(e['balanceAfter'], '12000.00');
    expect(e['merchantText'], 'Zomato');
    expect(e['hint']['issuer'], 'HDFCBK');
    expect(e['hint']['last4'], '1234');
    expect(e.containsKey('body'), isFalse); // NO raw text in the synced payload
  });

  test('MISS: novel shape -> pending_parse carries ONLY the redacted skeleton', () async {
    final r = await ingestSms(db,
        userId: 'u1',
        sender: 'VX-ICICIB',
        body: 'Rs.999.00 spent at Uber via UPI from a/c **5555 on 09-06-26. Avl Bal Rs.4,000.00',
        smsTimeMs: 1717322400000,
        messageId: 'm2');
    expect(r.outcome, 'parse_queued');
    final jobs = await db.dueJobs('pending_parse', bigMs);
    expect(jobs.length, 1);
    final p = jsonDecode(jobs.first.payload);
    expect(p['skeleton'], contains('§AMT§'));
    expect(p['skeleton'], isNot(contains('999')));
    expect(p['skeleton'], isNot(contains('Uber')));
    expect(RegExp(r'\d{3,}').hasMatch(p['skeleton'] as String), isFalse); // zero leaks
  });

  test('DROP: OTP gated out, nothing queued', () async {
    final r = await ingestSms(db, userId: 'u1', sender: 'VM-HDFCBK', body: 'Your OTP is 432189, do not share', smsTimeMs: 1, messageId: 'm3');
    expect(r.outcome, 'dropped');
    expect((await db.dueJobs('pending_sync', bigMs)).isEmpty, isTrue);
  });

  test('idempotent: re-ingest same SMS -> same entry id, one outbox row', () async {
    await seedTemplate();
    final r1 = await ingestSms(db, userId: 'u1', sender: 'VM-HDFCBK', body: hdfc1, smsTimeMs: 1717322400000, messageId: 'm1');
    final r2 = await ingestSms(db, userId: 'u1', sender: 'VM-HDFCBK', body: hdfc1, smsTimeMs: 1717322405000, messageId: 'm1');
    expect(r1.entryId, r2.entryId);
    expect((await db.dueJobs('pending_sync', bigMs)).length, 1);
  });
}
