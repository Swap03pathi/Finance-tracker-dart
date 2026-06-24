import 'config.dart';

/// Sender normalisation — port of TS `senderNormalisation.ts`. Strips DLT operator prefix + category
/// suffix to the registered entity; detects 10-digit personal senders.
class NormalisedSender {
  final String kind; // 'personal' | 'dlt'
  final String? entity;
  const NormalisedSender(this.kind, this.entity);
}

bool isPersonalSender(String sender) {
  var digits = sender.replaceAll(RegExp(r'[\s-]'), '');
  digits = digits.replaceFirst(RegExp(r'^\+?91'), '');
  digits = digits.replaceFirst(RegExp(r'^\+'), '');
  return RegExp(r'^\d{10}$').hasMatch(digits);
}

NormalisedSender normaliseSender(String sender) {
  final raw = sender.trim();
  if (isPersonalSender(raw)) return const NormalisedSender('personal', null);
  final cfg = senderNormConfig();
  final parts = raw.toUpperCase().split('-').where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) return NormalisedSender('dlt', parts[0]);
  if (cfg.operatorPrefixes.contains(parts[0]) || RegExp(r'^[A-Z]{2}$').hasMatch(parts[0])) {
    parts.removeAt(0);
  }
  if (parts.length > 1 && cfg.categorySuffixes.contains(parts.last)) {
    parts.removeLast();
  }
  final entity = parts.join('-');
  return NormalisedSender('dlt', entity.isEmpty ? null : entity);
}
