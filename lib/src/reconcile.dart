// Per-account balance reconciliation (pure Dart, package:decimal, no Flutter).
//
// Rule: per account, between two consecutive balance-bearing messages,
// signed_txn_amount + current_AvlBal must equal the previous AvlBal. When it does not, surface an
// "unexplained ₹X / needs review" gap — never absorb the difference into a total, and never
// hard-error, because some accounts (Slice and similar) credit DAILY INTEREST with no SMS, so a
// balance can legitimately move with no transaction message.
//
// Money is exact: package:decimal only, never double (doc 07 §15).

import 'package:decimal/decimal.dart';
import 'money_fmt.dart';

enum GapReason { unexplainedDelta, silentCredit, unknownDirection }

/// One break in the running balance between two consecutive balance-bearing messages on an account.
class BalanceGap {
  final String lineId, lineLabel, prevEntryId, currEntryId;
  final DateTime prevTime, currTime;
  final Decimal prevBalance, currBalance, unexplained;
  final Decimal? signedDelta;
  final GapReason reason;
  const BalanceGap(this.lineId, this.lineLabel, this.prevEntryId, this.currEntryId, this.prevTime,
      this.currTime, this.prevBalance, this.currBalance, this.signedDelta, this.unexplained, this.reason);

  Decimal get magnitude => unexplained.abs();

  String get humanReason {
    final amt = inr(unexplained.abs());
    switch (reason) {
      case GapReason.silentCredit:
        return 'Balance rose by $amt with no transaction message — likely interest. Needs review.';
      case GapReason.unknownDirection:
        return 'Balance changed by $amt across an unsigned transfer. Needs review.';
      case GapReason.unexplainedDelta:
        final dir = unexplained.sign < 0 ? 'less' : 'more';
        return 'Unexplained $amt — balance is $dir than the transaction explains. '
            'A message may be missing or mis-parsed. Needs review.';
    }
  }
}

/// Reconciliation outcome for a single account (line).
class AccountReconciliation {
  final String lineId, lineLabel;
  final int balanceBearingCount;
  final List<BalanceGap> gaps;
  const AccountReconciliation(this.lineId, this.lineLabel, this.balanceBearingCount, this.gaps);
  bool get reconciles => gaps.isEmpty;
  Decimal get totalUnexplained => gaps.fold(Decimal.zero, (a, g) => a + g.magnitude);
}

class ReconciliationResult {
  final List<AccountReconciliation> accounts;
  const ReconciliationResult(this.accounts);

  List<AccountReconciliation> get accountsNeedingReview {
    final out = accounts.where((a) => !a.reconciles).toList();
    out.sort((a, b) => b.totalUnexplained.compareTo(a.totalUnexplained));
    return out;
  }

  bool get hasGaps => accounts.any((a) => !a.reconciles);
  int get gapCount => accounts.fold(0, (a, x) => a + x.gaps.length);
  Decimal get totalUnexplained => accounts.fold(Decimal.zero, (a, x) => a + x.totalUnexplained);

  String? get headline {
    if (!hasGaps) return null;
    final n = accountsNeedingReview.length;
    return 'Unexplained ${inr(totalUnexplained)} across $n ${n == 1 ? 'account' : 'accounts'} — needs review';
  }
}

class _Row {
  final String id, lineId, lineLabel, direction;
  final Decimal amount, balanceAfter;
  final DateTime time;
  _Row(this.id, this.lineId, this.lineLabel, this.direction, this.amount, this.balanceAfter, this.time);

  /// The balance change this transaction *should* have produced. null when the direction can't sign it.
  Decimal? get signedDelta {
    if (direction == 'EXPENSE') return -amount;
    if (direction == 'INCOME' || direction == 'TOPUP') return amount;
    return null; // TRANSFER and anything else: sign unknown
  }
}

/// Reconcile balances from the GET /entries rows. Only entries carrying BOTH balanceAfter and
/// txnTime participate; others cannot anchor a balance equation.
ReconciliationResult reconcile(List<dynamic> entries) {
  final rows = <_Row>[];
  for (final raw in entries) {
    if (raw is! Map) continue;
    final j = raw.cast<String, dynamic>();
    final balRaw = j['balanceAfter'];
    if (balRaw == null) continue;
    final bal = Decimal.tryParse(balRaw.toString());
    if (bal == null) continue;
    final timeRaw = j['txnTime'];
    if (timeRaw == null) continue;
    final time = DateTime.tryParse(timeRaw.toString());
    if (time == null) continue;
    final amt = Decimal.tryParse((j['amountEffective'] ?? '0').toString()) ?? Decimal.zero;
    final lr = j['lineLabel'];
    final label = (lr is String && lr.trim().isNotEmpty) ? lr.trim() : 'Account';
    rows.add(_Row(j['id'].toString(), j['lineId'].toString(), label, j['direction'].toString(),
        amt.abs(), bal, time.toUtc()));
  }

  final byLine = <String, List<_Row>>{};
  for (final r in rows) {
    byLine.putIfAbsent(r.lineId, () => <_Row>[]).add(r);
  }

  final accounts = <AccountReconciliation>[];
  byLine.forEach((lineId, group) {
    group.sort((a, b) {
      final c = a.time.compareTo(b.time);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    final label = group.first.lineLabel;
    final gaps = <BalanceGap>[];
    for (var i = 1; i < group.length; i++) {
      final prev = group[i - 1];
      final curr = group[i];
      final delta = curr.signedDelta;
      if (delta == null) {
        final moved = curr.balanceAfter - prev.balanceAfter;
        if (moved != Decimal.zero) {
          gaps.add(BalanceGap(curr.lineId, label, prev.id, curr.id, prev.time, curr.time,
              prev.balanceAfter, curr.balanceAfter, null, moved, GapReason.unknownDirection));
        }
        continue;
      }
      final unexplained = curr.balanceAfter - prev.balanceAfter - delta;
      if (unexplained == Decimal.zero) continue;
      // balance HIGHER than the txn explains → an un-messaged credit (Slice interest); LOWER → a
      // debit the parser missed or mis-read (the "off by ₹1,000" case).
      final reason = unexplained.sign > 0 ? GapReason.silentCredit : GapReason.unexplainedDelta;
      gaps.add(BalanceGap(curr.lineId, label, prev.id, curr.id, prev.time, curr.time,
          prev.balanceAfter, curr.balanceAfter, delta, unexplained, reason));
    }
    accounts.add(AccountReconciliation(lineId, label, group.length, gaps));
  });
  return ReconciliationResult(accounts);
}
