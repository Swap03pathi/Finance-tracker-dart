import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Deterministic UUIDv5 for sync idempotency + cross-SMS dedup (port of TS `idempotentId.ts`).
/// The device is the sole id generator; a retry / dual-SMS for one event collapses to the same id.
const _namespace = 'b9f8a4e2-1c3d-4f5a-9b6e-7d8c9a0b1c2d';
const _uuid = Uuid();

String uuidv5(String name, [String namespace = _namespace]) => _uuid.v5(namespace, name);

/// Extract the bank's own transaction reference (UPI ref / RRN / UTR / txn id) when present.
/// The captured ref must contain a digit so a word like "reference" can't be mis-split.
String? extractReference(String body) {
  final m = RegExp(
    r'(?:upi(?:\s*ref(?:erence)?(?:\s*no\.?)?)?|ref(?:erence)?(?:\s*(?:no|id|num)\.?)?|rrn|utr|txn\s*id|transaction\s*id)[:#.\s-]*((?=[a-z0-9]*\d)[a-z0-9]{6,})',
    caseSensitive: false,
  ).firstMatch(body);
  return m?.group(1)!.toUpperCase();
}

const dedupFallbackWindowSec = 10;

/// PRIMARY: bank reference (exact). NEXT: a content hash of the body, so the same SMS captured by both
/// the real-time receiver and the catch-up sweep (different timestamps) collapses to one. LAST RESORT:
/// a small time-bucket. The body stays on the device — only the derived id leaves.
String logicalEntryId({
  required String userId,
  required String lineKey,
  required String direction,
  required int amountPaise,
  required int epochSec,
  String? reference,
  String? content,
}) {
  if (reference != null) {
    return uuidv5('$userId|$lineKey|ref:$reference');
  }
  if (content != null && content.isNotEmpty) {
    final h = sha1.convert(utf8.encode(content)).toString();
    return uuidv5('$userId|$lineKey|content:$h');
  }
  final bucket = epochSec ~/ dedupFallbackWindowSec;
  return uuidv5('$userId|$lineKey|$direction|$amountPaise|$bucket');
}
