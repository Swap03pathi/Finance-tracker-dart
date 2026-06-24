/// The structured entry the device syncs to the server — matches the server's `EntryInput` zod
/// contract (@finman/shared-contracts). Money is a wire STRING; the device generates `id` (uuidv5).
/// NO raw SMS text is included — only derived structured fields.
class EntryInput {
  final String id;
  final String? issuer;
  final String? last4;
  final String? vpa;
  final String instrumentKind; // credit_card | debit_card | vpa | netbanking
  final String? lineKind; // bank | credit_pool | wallet | loan
  final String direction; // EXPENSE | INCOME | TRANSFER | TOPUP
  final String modality; // actual | future | ...
  final String amountCaptured; // wire string
  final String? balanceAfter;
  final String? merchantText;
  final String? txnTime; // ISO UTC
  final String? messageId;

  const EntryInput({
    required this.id,
    required this.instrumentKind,
    required this.direction,
    required this.modality,
    required this.amountCaptured,
    this.issuer,
    this.last4,
    this.vpa,
    this.lineKind,
    this.balanceAfter,
    this.merchantText,
    this.txnTime,
    this.messageId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hint': {
          if (issuer != null) 'issuer': issuer,
          if (last4 != null) 'last4': last4,
          if (vpa != null) 'vpa': vpa,
          'instrumentKind': instrumentKind,
          if (lineKind != null) 'lineKind': lineKind,
        },
        'direction': direction,
        'modality': modality,
        'amountCaptured': amountCaptured,
        if (balanceAfter != null) 'balanceAfter': balanceAfter,
        if (merchantText != null) 'merchantText': merchantText,
        if (txnTime != null) 'txnTime': txnTime,
        'source': 'sms',
        if (messageId != null) 'messageId': messageId,
      };
}
