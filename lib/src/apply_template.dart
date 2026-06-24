import 'parse_amount.dart';

/// Apply a KNOWN template on-device — port of TS `parseWithTemplate`. The device receives the
/// synthesised regex from the server's trusted template library and runs it locally (zero LLM cost,
/// fully offline). Named groups (amount/balance/merchant) drive extraction.
class TemplateMatch {
  final int? amountPaise;
  final int? balancePaise;
  final String? merchant;
  const TemplateMatch(this.amountPaise, this.balancePaise, this.merchant);
}

String? _namedOrNull(RegExpMatch m, String name) {
  try {
    return m.namedGroup(name);
  } catch (_) {
    return null; // the template's regex doesn't define this group
  }
}

TemplateMatch? parseWithTemplate(String regex, String body) {
  final re = RegExp(regex, caseSensitive: false);
  final m = re.firstMatch(body);
  if (m == null) return null;
  final amount = _namedOrNull(m, 'amount');
  final balance = _namedOrNull(m, 'balance');
  final merchant = _namedOrNull(m, 'merchant');
  return TemplateMatch(
    amount != null ? parseAmount(amount).paise : null,
    balance != null ? parseAmount(balance).paise : null,
    merchant?.trim(),
  );
}
