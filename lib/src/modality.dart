import 'config.dart';

/// Modality classification — port of TS `modality.ts`. Runs ON-DEVICE because it reads the raw SMS
/// tense words (which never leave the phone). Only `actual` is eligible to count.
enum Modality { actual, future, conditional, failed, hold, mandate }

bool _has(String body, List<String> words) {
  final lower = body.toLowerCase();
  return words.any((w) => lower.contains(w.toLowerCase()));
}

Modality classifyModality(String body) {
  final r = gateRules();
  if (_has(body, r.mandate)) return Modality.mandate;
  if (_has(body, r.future)) return Modality.future;
  if (_has(body, r.conditional)) return Modality.conditional;
  if (_has(body, [...r.failedContext, 'failed', 'declined'])) return Modality.failed;
  if (_has(body, r.hold)) return Modality.hold;
  return Modality.actual;
}

extension ModalityWire on Modality {
  String get wire => name; // 'actual' | 'future' | ... matches the server enum
}
