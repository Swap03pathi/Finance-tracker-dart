import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:finman_engine/finman_engine.dart';

/// Golden-vector lockstep (doc 10 §3): the Dart port must reproduce the TS reference output for every
/// committed vector. Redaction + fingerprint are the strict sets — a divergence means the PORT is wrong.
List<dynamic> _load(String name) =>
    (jsonDecode(File('golden-vectors/$name').readAsStringSync())['vectors'] as List);

void main() {
  group('amount-vectors.json (B)', () {
    for (final v in _load('amount-vectors.json')) {
      test('"${v['input']}" -> ${v['paise']}/${v['confidence']}', () {
        final r = parseAmount(v['input'] as String);
        expect(r.paise, v['paise']);
        expect(r.confidence, v['confidence']);
      });
    }
  });

  group('gate-vectors.json (A)', () {
    for (final v in _load('gate-vectors.json')) {
      test('"${v['sender']}" / "${(v['body'] as String).substring(0, (v['body'] as String).length.clamp(0, 28))}…"', () {
        final r = gate(v['sender'] as String, v['body'] as String);
        expect(r.admit, v['admit']);
        expect(r.reason, v['reason']);
      });
    }
  });

  group('fingerprint-vectors.json (D) — byte-exact skeleton + sha256', () {
    for (final v in _load('fingerprint-vectors.json')) {
      test('"${(v['input'] as String).substring(0, 24)}…"', () {
        expect(maskBody(v['input'] as String), v['skeleton']); // identical skeleton
        expect(fingerprint(v['input'] as String), v['fingerprint']); // identical hash
      });
    }
  });

  group('template-vectors.json — apply a known template locally', () {
    for (final v in _load('template-vectors.json')) {
      test('"${(v['body'] as String).substring(0, 24)}…"', () {
        final r = parseWithTemplate(v['regex'] as String, v['body'] as String);
        expect(r, isNotNull);
        expect(r!.amountPaise, v['amountPaise']);
        expect(r.balancePaise, v['balancePaise']);
        expect(r.merchant, v['merchant']);
      });
    }
  });

  group('redaction-vectors.json (W) — privacy, highest priority', () {
    for (final v in _load('redaction-vectors.json')) {
      test('"${(v['input'] as String).substring(0, (v['input'] as String).length.clamp(0, 24))}…"', () {
        expect(maskBody(v['input'] as String), v['skeleton']);
        expect(v['leaks'], false);
        expect(RegExp(r'\d{3,}').hasMatch(maskBody(v['input'] as String)), false);
        // redactForInduction must not throw for a clean skeleton
        expect(() => redactForInduction(v['input'] as String), returnsNormally);
      });
    }
  });
}
