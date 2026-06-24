/// Money core — integer paise (Dart `int` is 64-bit, exact, no float drift). ₹1,234.50 == 123450.
/// Parsing produces paise (see parse_amount.dart); the device only needs the wire formatter below.
typedef Paise = int;

/// Integer paise -> wire rupee string "1234.50" (what the server's EntryInput expects).
String paiseToWire(Paise paise) {
  final neg = paise < 0;
  final a = paise.abs();
  return '${neg ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}
