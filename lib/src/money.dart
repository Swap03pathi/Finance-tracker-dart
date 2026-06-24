import 'package:decimal/decimal.dart';

/// Money core — integer paise (Dart `int` is 64-bit, exact, no float drift). ₹1,234.50 == 123450.
/// Mirror of the TS engine `money.ts`. Conversion to/from rupees uses `package:decimal` (decimal.js parity).
typedef Paise = int;

/// Exact sum of paise — integer addition, zero drift.
int sumPaise(Iterable<Paise> values) {
  var total = 0;
  for (final v in values) {
    total += v;
  }
  return total;
}

/// Rupees (string/Decimal) -> integer paise, via Decimal so 0.1+0.2 never drifts.
Paise rupeesToPaise(String rupees) =>
    (Decimal.parse(rupees) * Decimal.fromInt(100)).round().toBigInt().toInt();

/// Integer paise -> Decimal rupees.
Decimal paiseToRupees(Paise paise) =>
    (Decimal.fromInt(paise) / Decimal.fromInt(100)).toDecimal();
