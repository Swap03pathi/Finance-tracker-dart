import 'config.dart';

/// The fixed system taxonomy (doc 04 §3.4). Ids mirror the server's seed order (autoincrement 1–12),
/// so the device can set categoryId locally and the server's by-category breakdown lines up.
const systemCategories = <int, String>{
  1: 'Food',
  2: 'Shopping',
  3: 'Rent',
  4: 'Utilities',
  5: 'Travel',
  6: 'Healthcare',
  7: 'Entertainment',
  8: 'Investments',
  9: 'Education',
  10: 'Loans',
  11: 'Insurance',
  12: 'Miscellaneous',
};

int _idForName(String name) => systemCategories.entries
    .firstWhere((e) => e.value == name, orElse: () => const MapEntry(12, 'Miscellaneous'))
    .key;

String categoryName(int? id) => id == null ? 'Uncategorised' : (systemCategories[id] ?? 'Uncategorised');

/// Cold-start category for an EXPENSE: a known merchant → its category, else Miscellaneous.
/// (Learn-once payee tagging that overrides this is Phase 5.)
int categoryForMerchant(String? merchantText) {
  if (merchantText == null) return 12; // Miscellaneous
  final dict = merchantDictionary();
  final key = merchantText.toLowerCase();
  for (final name in dict.keys) {
    if (key.contains(name)) return _idForName(dict[name]!);
  }
  return 12;
}
