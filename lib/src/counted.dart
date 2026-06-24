import 'modality.dart';
import 'money_type.dart';

/// The single source of truth for "does this entry hit the headline numbers?" (port of TS `counted.ts`).
/// Counted IFF direction is EXPENSE/INCOME AND modality is actual AND not a reversal leg.
bool computeIsCounted(Direction direction, Modality modality, {String netStatus = 'active'}) {
  if (direction == Direction.TRANSFER || direction == Direction.TOPUP) return false;
  if (modality != Modality.actual) return false;
  if (netStatus == 'is_reversal') return false;
  return true;
}
