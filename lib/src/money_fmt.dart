import 'package:decimal/decimal.dart';

/// Format rupees the Indian way: `₹12,470`, `₹1,00,000`, `₹2,45,678.50`.
/// Grouping is 3 digits then 2s (lakh/crore). Trailing `.00` is dropped, but real paise are kept.
/// Input is a [Decimal] (rupees) so we never round through a float — money is exact end to end.
String inr(Decimal rupees) => '₹${_digits(rupees)}';

/// Same but signed: `−₹450` for an outflow, `+₹65,000` for an inflow. Zero is unsigned (`₹0`).
String inrSigned(Decimal rupees, {required bool positive}) {
  if (rupees == Decimal.zero) return '₹0';
  return '${positive ? '+' : '−'}₹${_digits(rupees.abs())}';
}

String _digits(Decimal rupees) {
  final neg = rupees.sign < 0;
  // Quantise to exact paise with round-half-up (matches the server's rupeesToPaise), so 12.349 →
  // 12.35 and 0.005 → 0.01 rather than silently truncating.
  final paiseTotal = (rupees.abs() * Decimal.fromInt(100)).round().toBigInt();
  final whole = (paiseTotal ~/ BigInt.from(100)).toString();
  final paise = (paiseTotal % BigInt.from(100)).toInt();
  final frac = paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}';
  return '${neg ? '−' : ''}${_groupIndian(whole)}$frac';
}

/// 1234567 → "12,34,567" (last 3 digits, then groups of 2).
String _groupIndian(String n) {
  if (n.length <= 3) return n;
  final head = n.substring(0, n.length - 3);
  final tail = n.substring(n.length - 3);
  final buf = StringBuffer();
  for (int i = 0; i < head.length; i++) {
    final fromRight = head.length - i;
    buf.write(head[i]);
    if (fromRight > 1 && fromRight % 2 == 1) buf.write(',');
  }
  return '$buf,$tail';
}
