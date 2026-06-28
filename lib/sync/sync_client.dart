import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' show Value;
import '../data/database.dart';

/// Sync client (doc 03 §8) — drains the offline outbox to the server, pulls trusted templates, and
/// sends ONLY redacted skeletons for induction. Retryable with exponential backoff. Base URL is
/// configurable (live: http://18.206.195.183; TLS pending a domain).
class SyncClient {
  final String baseUrl;
  final http.Client _http;
  String? _token;

  SyncClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  void setToken(String token) => _token = token;
  String? get token => _token;
  void close() => _http.close();

  /// Pilot dev sign-in: exchange a stable device key for a session JWT (server must have ALLOW_DEV_AUTH).
  Future<void> authDev(String deviceKey) async {
    final res = await _http.post(Uri.parse('$baseUrl/v1/auth/dev'),
        headers: {'content-type': 'application/json'}, body: jsonEncode({'deviceKey': deviceKey}));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('dev auth failed: ${res.statusCode} ${res.body}');
    }
    _token = jsonDecode(res.body)['token'] as String;
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
      };

  /// Verify a Google ID token with the server and store the session JWT.
  Future<void> authGoogle(String idToken) async {
    final res = await _http.post(Uri.parse('$baseUrl/v1/auth/google'),
        headers: {'content-type': 'application/json'}, body: jsonEncode({'idToken': idToken}));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('auth failed: ${res.statusCode} ${res.body}');
    }
    _token = jsonDecode(res.body)['token'] as String;
  }

  /// Drain `pending_sync` → POST /entries (idempotent). Returns how many entries synced.
  Future<int> drainSync(LocalDb db, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final jobs = await db.dueJobs('pending_sync', now);
    if (jobs.isEmpty) return 0;
    final entries = jobs.map((j) => jsonDecode(j.payload)).toList();
    final res = await _http.post(Uri.parse('$baseUrl/v1/entries'),
        headers: _headers, body: jsonEncode({'entries': entries}));
    if (res.statusCode == 200 || res.statusCode == 201) {
      for (final j in jobs) {
        await db.dequeue(j.id);
      }
      return jobs.length;
    }
    for (final j in jobs) {
      await db.backoff(j.id, j.attempts + 1, now + _backoffMs(j.attempts + 1));
    }
    return 0;
  }

  /// Pull trusted templates → local cache (instant offline parse thereafter).
  Future<int> pullTemplates(LocalDb db, {String? since}) async {
    final uri = Uri.parse('$baseUrl/v1/templates${since != null ? '?since=$since' : ''}');
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode != 200) return 0;
    final list = jsonDecode(res.body) as List;
    for (final t in list) {
      await _cacheTemplate(db, t);
    }
    return list.length;
  }

  /// Drain `pending_parse` → POST /templates/induce (REDACTED skeleton only). Caches the result.
  Future<int> drainInduce(LocalDb db, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final jobs = await db.dueJobs('pending_parse', now);
    var done = 0;
    for (final j in jobs) {
      final p = jsonDecode(j.payload);
      final res = await _http.post(Uri.parse('$baseUrl/v1/templates/induce'),
          headers: _headers,
          body: jsonEncode({'redactedSkeleton': p['skeleton'], 'fingerprint': p['fingerprint'], 'issuer': p['issuer']}));
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _cacheTemplate(db, jsonDecode(res.body));
        await db.dequeue(j.id);
        done++;
      } else {
        await db.backoff(j.id, j.attempts + 1, now + _backoffMs(j.attempts + 1));
      }
    }
    return done;
  }

  /// The three headline numbers + balances (server is the system of record for aggregation).
  Future<Map<String, dynamic>> fetchDashboard() async {
    final res = await _http.get(Uri.parse('$baseUrl/v1/dashboard'), headers: _headers);
    if (res.statusCode != 200) throw Exception('dashboard failed: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// The ledger — every synced transaction (honest, chronological).
  Future<List<dynamic>> fetchEntries() async {
    final res = await _http.get(Uri.parse('$baseUrl/v1/entries'), headers: _headers);
    if (res.statusCode != 200) throw Exception('entries failed: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  /// Spend grouped by category / tag / line.
  Future<List<dynamic>> fetchBreakdown(String by) async {
    final res = await _http.get(Uri.parse('$baseUrl/v1/breakdown?by=$by'), headers: _headers);
    if (res.statusCode != 200) throw Exception('breakdown failed: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<void> _cacheTemplate(LocalDb db, dynamic t) => db.upsertTemplate(LocalTemplateCacheCompanion.insert(
        fingerprint: t['fingerprint'] as String,
        regex: t['regex'] as String,
        slotMap: jsonEncode(t['slotMap']),
        trustState: t['trustState'] as String,
        issuer: Value(t['issuer'] as String?),
      ));

  int _backoffMs(int attempts) => 1000 * (1 << attempts.clamp(0, 6)); // exp backoff, capped ~64s
}
