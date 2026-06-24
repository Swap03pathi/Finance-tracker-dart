// Enum values mirror the server's Direction wire enum exactly — intentional UPPER_CASE.
// ignore_for_file: constant_identifier_names
import 'config.dart';

/// Money-type classification — the boundary (port of TS `moneyType.ts`). EXPENSE/INCOME cross the
/// boundary to/from outside; TRANSFER/TOPUP move balances between own nodes and never count.
enum Direction { EXPENSE, INCOME, TRANSFER, TOPUP }

/// From the transaction verb: is money leaving (out) or entering (in) this line?
String? verbDirection(String body) {
  final lower = body.toLowerCase();
  if (RegExp(r'\b(debited|spent|withdrawn|paid|deducted|debit|sent|blocked|added)\b').hasMatch(lower)) {
    if (RegExp(r'added to .*wallet', caseSensitive: false).hasMatch(body)) return 'in';
    return 'out';
  }
  if (RegExp(r'\b(credited|received|refund|reversed|returned|load|loaded)\b').hasMatch(lower)) return 'in';
  return null;
}

Direction classifyMoneyType({
  required String direction, // 'out' | 'in'
  required bool counterpartyIsOwnNode,
  bool isTopup = false,
}) {
  if (isTopup) return Direction.TOPUP;
  if (counterpartyIsOwnNode) return Direction.TRANSFER;
  return direction == 'out' ? Direction.EXPENSE : Direction.INCOME;
}

/// Is the named issuer/counterparty a seeded own-node wallet? (extended by learned own-nodes)
bool isSeededOwnNode(String? issuer, [Set<String> learned = const {}]) {
  if (issuer == null) return false;
  final up = issuer.toUpperCase();
  return ownNodeIssuers().contains(up) || learned.contains(up);
}

/// TOPUP detection: external value into a wallet (gift card / voucher).
bool isTopupText(String body) => RegExp(
      r'gift card|gift voucher|voucher|added to .*(amazon pay|wallet) balance',
      caseSensitive: false,
    ).hasMatch(body);

extension DirectionWire on Direction {
  String get wire => name; // 'EXPENSE' | 'INCOME' | ... matches the server enum
}
