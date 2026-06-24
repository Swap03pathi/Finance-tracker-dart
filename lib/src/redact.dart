import 'mask.dart';

/// Redaction — the one privacy-critical path (port of TS `redact.ts`). A leak here is a privacy
/// breach the server cannot catch, so this THROWS rather than leaks. Enforced device-side before send.
class RedactionLeakError implements Exception {
  final String residue;
  final String skeleton;
  RedactionLeakError(this.residue, this.skeleton);
  @override
  String toString() => 'RedactionLeakError: real value-like token "$residue" survived masking';
}

final _currencyDigit = RegExp(r'(?:rs\.?|inr|₹|rupees)\s*\d', caseSensitive: false);
final _longRun = RegExp(r'\d{3,}');

/// Assert a skeleton carries ZERO real values — reject if any currency+digit or 3+ digit run survives.
/// Used server-side too. NEVER mock or weaken this.
void assertRedacted(String skeleton) {
  final cd = _currencyDigit.firstMatch(skeleton);
  if (cd != null) throw RedactionLeakError(cd.group(0)!, skeleton);
  final lr = _longRun.firstMatch(skeleton);
  if (lr != null) throw RedactionLeakError(lr.group(0)!, skeleton);
}

/// Produce the redacted skeleton for induction and assert it is clean (the only thing that leaves device).
String redactForInduction(String body) {
  final skeleton = maskBody(body);
  assertRedacted(skeleton);
  return skeleton;
}
