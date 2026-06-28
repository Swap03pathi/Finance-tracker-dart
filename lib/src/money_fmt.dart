import 'package:decimal/decimal.dart';

/// Format rupees the Indian way: `₹12,470`, `₹1,00,000`, `₹2,45,678.50`.
/// Grouping is 3 digits then 2s (lakh/crore). Trailing `.00` is dropped, but real paise are kept.
/// Input is a [Decimal] (rupees) so we never round through a float — money is exact end to end.
String inr(Decimal rupees) => '₹${_digits(rupees)}';

/// Same but signed: `−₹450` for an outflow, `+₹65,000` for an inflow. [positive] picks the glyph set.
String inrSigned(Decimal rupees, {required bool positive}) =>
    '${positive ? '+' : '−'}₹${_digits(rupees.abs())}';

String _digits(Decimal rupees) {
  final neg = rupees.sign < 0;
  final v = rupees.abs();
  final whole = v.truncate().toBigInt().toString();
  // fractional part, 2dp, trimmed of a pure ".00"
  final frac = (v - v.truncate()).toString(); // e.g. "0.5" / "0" / "0.05"
  String paise = '';
  if (frac != '0') {
    final after = frac.contains('.') ? frac.split('.')[1] : '';
    final two = '${after}00'.substring(0, 2);
    if (two != '00') paise = '.$two';
  }
  return '${neg ? '−' : ''}${_groupIndian(whole)}$paise';
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
