import 'dart:convert';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finman_engine/data/database.dart';
import 'package:finman_engine/sync/sync_client.dart';
import 'package:drift/drift.dart' show Value;

/// Sync client (3.E) — verified against an in-process mock server (deterministic). A live smoke test
/// against http://18.206.195.183 is run separately in CI/bash.
void main() {
  late LocalDb db;
  setUp(() => db = LocalDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('drainSync posts the outbox to /v1/entries and clears it on success', () async {
    await db.enqueue(LocalOutboxCompanion.insert(
        id: 'e1', kind: 'pending_sync', payload: jsonEncode({'id': 'e1', 'direction': 'EXPENSE'})));
    Map<String, dynamic>? posted;
    final mock = MockClient((req) async {
      expect(req.headers['authorization'], 'Bearer tok');
      posted = jsonDecode(req.body);
      return http.Response('{"upserted":1,"ids":["e1"]}', 201);
    });
    final c = SyncClient('http://mock', client: mock)..setToken('tok');
    final n = await c.drainSync(db, nowMs: 9999999999999);
    expect(n, 1);
    expect(posted!['entries'][0]['id'], 'e1');
    expect((await db.dueJobs('pending_sync', 9999999999999)).isEmpty, isTrue); // cleared
  });

  test('drainSync backs off (keeps job) on server error', () async {
    await db.enqueue(LocalOutboxCompanion.insert(id: 'e2', kind: 'pending_sync', payload: '{}'));
    final mock = MockClient((req) async => http.Response('boom', 500));
    final c = SyncClient('http://mock', client: mock)..setToken('t');
    expect(await c.drainSync(db, nowMs: 1000), 0);
    final j = (await db.dueJobs('pending_sync', 9999999999999)).single;
    expect(j.attempts, 1); // retained, retried later
  });

  test('pullTemplates caches trusted templates locally', () async {
    final mock = MockClient((req) async =>
        http.Response('[{"fingerprint":"fp1","issuer":"HDFCBK","regex":"^x\$","slotMap":{},"trustState":"trusted"}]', 200));
    final c = SyncClient('http://mock', client: mock)..setToken('t');
    expect(await c.pullTemplates(db), 1);
    expect((await db.templateFor('fp1'))!.regex, r'^x$');
  });

  test('drainInduce sends ONLY the redacted skeleton and caches the template', () async {
    await db.enqueue(LocalOutboxCompanion.insert(
        id: 'parse:fp9', kind: 'pending_parse', payload: jsonEncode({'skeleton': '§AMT§ debited at §MERCHANT§', 'fingerprint': 'fp9', 'issuer': 'HDFCBK'})));
    String? sentBody;
    final mock = MockClient((req) async {
      sentBody = req.body;
      return http.Response('{"fingerprint":"fp9","issuer":"HDFCBK","regex":"^y\$","slotMap":{},"trustState":"trusted"}', 201);
    });
    final c = SyncClient('http://mock', client: mock)..setToken('t');
    expect(await c.drainInduce(db, nowMs: 9999999999999), 1);
    expect(sentBody, contains('§AMT§'));
    expect(RegExp(r'\d{3,}').hasMatch(sentBody!), isFalse); // never any raw value
    expect((await db.templateFor('fp9'))!.trustState, 'trusted');
  });
}
