/// Structural masker — port of TS `mask.ts` (incl. the FIXED §MERCHANT§ pass). The skeleton produced
/// here is BOTH the fingerprint key AND the redaction skeleton (same code path → the LLM never sees a
/// real value). Order matters; this must produce byte-identical output to the TS reference.
library;

// 1) currency amounts incl L/Cr/k notation, "/-" suffix, and the word "rupees"
final _reAmount = RegExp(
  r'(?:rs\.?|inr|₹|rupees)\s*\d[\d,]*(?:\.\d+)?\s*(?:k|lakhs?|lac|l|crores?|cr)?(?:\s*/-)?',
  caseSensitive: false,
);
// 1b) bare multiplier amounts without currency
final _reAmountBare = RegExp(
  r'\b\d[\d,]*(?:\.\d+)?\s*(?:k|lakhs?|lac|crores?|cr|l)\b',
  caseSensitive: false,
);
// 2) dates: dd-mm-yy(yy), dd/mm/yyyy, dd Mon yy
final _reDate = RegExp(
  r'\b\d{1,2}[-/ ](?:\d{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[-/ ]?\d{2,4}\b',
  caseSensitive: false,
);
// 3) account tails: XX1234, **1234, a/c ...3456, ending 1234, Card XX9012
final _reAcct = RegExp(
  r'\b(?:x{2,}|\*{2,}|a/c\s*[*.]*\s*|ending\s+|acct\.?\s*|account\s+|card\s+x*)\s*\d{2,6}\b',
  caseSensitive: false,
);
// 4) VPAs: local@psp
final _reVpa = RegExp(r'\b[\w.\-]+@[a-z]+\b', caseSensitive: false);
// 5) merchant: free-text span after an anchor preposition up to the next structural keyword/anchor
final _reMerchant = RegExp(
  r'\b(at|to|for|towards)\s+(.+?)(?=\s+(?:via|on|from|using|thru|through|ref|avl|bal|upi|info|txn|dated|at|to|for|towards|a/c|acct)\b|\s*§|[.,]|$)',
  caseSensitive: false,
);
// 6) any remaining long-ish number run — privacy backstop
final _reLongnum = RegExp(r'\d{3,}');
final _reWs = RegExp(r'\s+');

String maskBody(String body) {
  var s = body.toLowerCase().trim();
  s = s.replaceAll(_reAmount, '§AMT§');
  s = s.replaceAll(_reAmountBare, '§AMT§');
  s = s.replaceAll(_reDate, '§DATE§');
  s = s.replaceAll(_reAcct, '§ACCT§');
  s = s.replaceAll(_reVpa, '§VPA§');
  s = s.replaceAllMapped(_reMerchant, (m) => '${m.group(1)} §MERCHANT§'); // merchant → wildcard slot
  s = s.replaceAll(_reLongnum, '§NUM§'); // nothing 3+ digits survives
  s = s.replaceAll(_reWs, ' ').trim(); // collapse whitespace
  return s;
}
