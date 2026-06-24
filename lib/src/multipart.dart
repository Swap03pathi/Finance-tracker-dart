/// Multipart / concatenated SMS reassembly (port of TS `multipart.ts`). Reassemble by concatenation
/// ref id BEFORE gating/fingerprinting, or we'd fingerprint half a message. A missing part is flagged,
/// never half-parsed.
class SmsPart {
  final String refId;
  final int partIndex; // 1-based
  final int totalParts;
  final String text;
  const SmsPart({required this.refId, required this.partIndex, required this.totalParts, required this.text});
}

class ReassemblyResult {
  final String refId;
  final bool complete;
  final String? body; // null when incomplete
  final List<int> missing;
  const ReassemblyResult(this.refId, this.complete, this.body, this.missing);
}

ReassemblyResult reassemble(List<SmsPart> parts) {
  final refId = parts.isNotEmpty ? parts.first.refId : '';
  final total = parts.isNotEmpty ? parts.first.totalParts : parts.length;
  final byIndex = <int, String>{for (final p in parts) p.partIndex: p.text};
  final missing = <int>[];
  for (var i = 1; i <= total; i++) {
    if (!byIndex.containsKey(i)) missing.add(i);
  }
  if (missing.isNotEmpty) return ReassemblyResult(refId, false, null, missing);
  final body = [for (var i = 1; i <= total; i++) byIndex[i]!].join();
  return ReassemblyResult(refId, true, body, const []);
}
