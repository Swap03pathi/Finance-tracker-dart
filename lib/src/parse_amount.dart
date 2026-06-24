import 'package:decimal/decimal.dart';
import 'money.dart';

/// parseAmount — the single money extractor (port of TS `parseAmount.ts`). Returns integer paise for
/// confident parses; marks low-confidence (paise=null) for garbled input rather than mis-parsing.
class ParsedAmount {
  final Paise? paise;
  final String confidence; // 'high' | 'low'
  final String? matched;
  const ParsedAmount(this.paise, this.confidence, this.matched);
}

const _multipliers = <String, int>{
  'k': 1000,
  'l': 100000,
  'lac': 100000,
  'lakh': 100000,
  'lakhs': 100000,
  'cr': 10000000,
  'crore': 10000000,
  'crores': 10000000,
};

final _cleanNumber = RegExp(r'^[0-9][0-9,]*(?:\.[0-9]+)?$');
// currency-led: Rs / Rs. / INR / ₹ then a number blob, optional spaced multiplier
final _currencyLed = RegExp(
  r'(?:rs\.?|inr|₹)\s*([0-9a-z.,]+)(?:\s+(k|lakhs?|lac|l|crores?|cr))?',
  caseSensitive: false,
);
// bare number + multiplier, no currency ("2.5Cr")
final _bareMult = RegExp(
  r'\b([0-9][0-9,]*(?:\.[0-9]+)?)\s*(k|lakhs?|lac|l|crores?|cr)\b',
  caseSensitive: false,
);
final _glued = RegExp(r'^([0-9.,]+)(k|l|lac|lakh|lakhs|cr|crore|crores)$', caseSensitive: false);

Paise _buildPaise(String coreNumber, String? multiplier) {
  final cleaned = coreNumber.replaceAll(',', ''); // commas are grouping only
  var value = Decimal.parse(cleaned);
  if (multiplier != null) {
    value = value * Decimal.fromInt(_multipliers[multiplier.toLowerCase()]!);
  }
  return (value * Decimal.fromInt(100)).round().toBigInt().toInt();
}

({String core, String? mult}) _splitGluedMultiplier(String blob) {
  final m = _glued.firstMatch(blob);
  if (m != null) return (core: m.group(1)!, mult: m.group(2));
  return (core: blob, mult: null);
}

ParsedAmount parseAmount(String raw) {
  final c = _currencyLed.firstMatch(raw);
  if (c != null) {
    final blob = c.group(1)!;
    final spacedMult = c.group(2);
    String core;
    String? mult;
    if (spacedMult != null) {
      core = blob;
      mult = spacedMult;
    } else {
      final s = _splitGluedMultiplier(blob);
      core = s.core;
      mult = s.mult;
    }
    if (!_cleanNumber.hasMatch(core)) {
      return ParsedAmount(null, 'low', c.group(0)); // stray letters (e.g. "4,5O.00") — refuse to guess
    }
    return ParsedAmount(_buildPaise(core, mult), 'high', c.group(0));
  }
  final b = _bareMult.firstMatch(raw);
  if (b != null) {
    return ParsedAmount(_buildPaise(b.group(1)!, b.group(2)), 'high', b.group(0));
  }
  return const ParsedAmount(null, 'low', null);
}

/// Extract every currency amount in order (for slot disambiguation: txn first, balance later).
List<Paise> extractAmounts(String body) {
  final re = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*(k|lakhs?|lac|l|crores?|cr)?',
    caseSensitive: false,
  );
  return [for (final m in re.allMatches(body)) _buildPaise(m.group(1)!, m.group(2))];
}
