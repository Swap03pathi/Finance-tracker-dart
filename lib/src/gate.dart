import 'config.dart';
import 'sender_normalisation.dart';
import 'parse_amount.dart';

/// The cheap rule-based gate — port of TS `gate.ts`. Admits amount + (verb OR modality trigger);
/// drops personal/empty/otp/promo/denylist/balance-only.
class GateResult {
  final bool admit;
  final String reason; // admit|empty|personal|denylist|otp|promo|balance_only
  final String? normalisedSender;
  final bool buffered;
  const GateResult(this.admit, this.reason, this.normalisedSender, this.buffered);
}

String _escape(String w) => w.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

bool _hasWord(String body, List<String> words) {
  final lower = body.toLowerCase();
  return words.any((w) => RegExp('\\b${_escape(w)}\\b', caseSensitive: false).hasMatch(lower));
}

bool _hasAmountToken(String body) => extractAmounts(body).isNotEmpty;
bool _isOtp(String b) =>
    RegExp(r'\botp\b|one time password|do not share|code is', caseSensitive: false).hasMatch(b);
bool _isPromo(String b) =>
    RegExp(r'\b(offer|sale|win|won|discount|expires|click|claim|shop now|flat \d+%|\d+% off)\b',
            caseSensitive: false)
        .hasMatch(b) ||
    RegExp(r'\bcashback\b', caseSensitive: false).hasMatch(b);

GateResult gate(String sender, String body, [Set<String> denylist = const {}]) {
  final norm = normaliseSender(sender);
  if (body.trim().isEmpty) return GateResult(false, 'empty', norm.entity, false);
  if (norm.kind == 'personal') return const GateResult(false, 'personal', null, false);
  if (norm.entity != null && denylist.contains(norm.entity)) {
    return GateResult(false, 'denylist', norm.entity, false);
  }
  if (_isOtp(body)) return GateResult(false, 'otp', norm.entity, true);
  if (_isPromo(body)) return GateResult(false, 'promo', norm.entity, false);

  final r = gateRules();
  final amount = _hasAmountToken(body);
  final verb = _hasWord(body, r.transactionVerbs);
  final trigger = _hasWord(body, [
    ...r.future,
    ...r.conditional,
    ...r.hold,
    ...r.mandate,
    ...r.refund,
    ...r.failedContext,
  ]);

  if (amount && (verb || trigger)) return GateResult(true, 'admit', norm.entity, false);
  return GateResult(false, 'balance_only', norm.entity, false);
}
