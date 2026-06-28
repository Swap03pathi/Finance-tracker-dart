import 'dart:convert';
import '../finman_engine.dart';
import '../data/database.dart';
import 'entry.dart';

/// On-device ingestion pipeline (doc 03 §2): reassemble → gate → fingerprint → match local template →
/// HIT: apply template + classify + build EntryInput → store raw + enqueue pending_sync.
/// MISS: enqueue pending_parse with the REDACTED skeleton (raw never leaves the device).
/// Offline-first: everything is stored/queued locally; the sync client drains separately.
class IngestResult {
  final String outcome; // 'synced_queued' | 'parse_queued' | 'dropped'
  final String? entryId;
  const IngestResult(this.outcome, this.entryId);
}

String? _extractLast4(String body) {
  final m = RegExp(r'(?:x{2,}|\*{2,}|a/c\s*[*.]*\s*|ending\s+|card\s+x*)\s*(\d{2,6})', caseSensitive: false)
      .firstMatch(body);
  return m?.group(1);
}

String _instrumentKind(String body) {
  final l = body.toLowerCase();
  if (l.contains('@')) return 'vpa';
  if (l.contains('debit card')) return 'debit_card';
  if (l.contains('card')) return 'credit_card';
  if (l.contains('a/c') || l.contains('account') || l.contains('net banking')) return 'netbanking';
  return 'vpa';
}

Future<IngestResult> ingestSms(
  LocalDb db, {
  required String userId,
  required String sender,
  required String body,
  required int smsTimeMs,
  required String messageId,
  Set<String> learnedOwnNodes = const {},
}) async {
  await db.putRaw(LocalRawMessagesCompanion.insert(
      messageId: messageId, sender: sender, body: body, smsTimeMs: smsTimeMs));

  final g = gate(sender, body);
  final issuer = g.normalisedSender;
  if (!g.admit) {
    await db.markProcessed(messageId); // OTP/promo/personal/balance-only — discarded (raw kept locally)
    return const IngestResult('dropped', null);
  }

  final fp = fingerprint(body);
  final tmpl = await db.templateFor(fp);
  if (tmpl == null) {
    // novel shape → queue only the REDACTED skeleton for server induction (privacy-critical)
    final skeleton = redactForInduction(body);
    await db.enqueue(LocalOutboxCompanion.insert(
        id: 'parse:$fp',
        kind: 'pending_parse',
        payload: jsonEncode({'skeleton': skeleton, 'fingerprint': fp, 'issuer': issuer, 'messageId': messageId})));
    return const IngestResult('parse_queued', null);
  }

  // HIT: apply the known template + classify on-device
  final m = parseWithTemplate(tmpl.regex, body);
  final amountPaise = m?.amountPaise ?? parseAmount(body).paise ?? 0;
  final balancePaise = m?.balancePaise;
  final merchant = m?.merchant;
  final modality = classifyModality(body);
  final vd = verbDirection(body) ?? 'out';
  final ownNode = isSeededOwnNode(issuer, learnedOwnNodes) ||
      (merchant != null && isSeededOwnNode(merchant, learnedOwnNodes));
  final dir = classifyMoneyType(direction: vd, counterpartyIsOwnNode: ownNode, isTopup: isTopupText(body));

  final last4 = _extractLast4(body);
  final reference = extractReference(body);
  final lineKey = '${issuer ?? '?'}|${last4 ?? '?'}';
  final id = logicalEntryId(
    userId: userId,
    lineKey: lineKey,
    direction: dir.wire,
    amountPaise: amountPaise,
    epochSec: smsTimeMs ~/ 1000,
    reference: reference,
  );

  final entry = EntryInput(
    id: id,
    issuer: issuer,
    last4: last4,
    instrumentKind: _instrumentKind(body),
    direction: dir.wire,
    modality: modality.wire,
    amountCaptured: paiseToWire(amountPaise),
    balanceAfter: balancePaise != null ? paiseToWire(balancePaise) : null,
    merchantText: merchant,
    txnTime: DateTime.fromMillisecondsSinceEpoch(smsTimeMs, isUtc: true).toIso8601String(),
    messageId: messageId,
  );

  await db.enqueue(LocalOutboxCompanion.insert(
      id: id, kind: 'pending_sync', payload: jsonEncode(entry.toJson())));
  await db.markProcessed(messageId);
  return IngestResult('synced_queued', id);
}

/// Re-ingest raw messages that previously had no template (still unprocessed) — now that templates may
/// have been pulled/induced from the server. Returns how many newly produced a sync-able entry.
Future<int> reprocessUnparsed(LocalDb db, String userId) async {
  final pending = await (db.select(db.localRawMessages)..where((t) => t.processed.equals(false))).get();
  var reparsed = 0;
  for (final r in pending) {
    final res = await ingestSms(db,
        userId: userId, sender: r.sender, body: r.body, smsTimeMs: r.smsTimeMs, messageId: r.messageId);
    if (res.outcome == 'synced_queued') reparsed++;
  }
  return reparsed;
}
