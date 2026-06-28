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

/// Custom categories the user added (id ≥ 100 to stay clear of the system 1–12) and per-merchant
/// overrides. Both are primed at startup from device storage (see CategoryStore) so the resolution
/// below stays synchronous — mirroring how primeConfig() injects the rule data.
Map<String, int> _overrides = {}; // normalised merchant → categoryId (the user's learned choice)
Map<int, String> _customNames = {}; // customId → display name

void primeCategoryState({Map<String, int>? overrides, Map<int, String>? customNames}) {
  _overrides = overrides ?? {};
  _customNames = customNames ?? {};
}

Map<String, int> get categoryOverrides => Map.unmodifiable(_overrides);
Map<int, String> get customCategories => Map.unmodifiable(_customNames);

/// System + custom categories, for the picker. System first, customs after.
Map<int, String> allCategories() => {...systemCategories, ..._customNames};

int _idForName(String name) => systemCategories.entries
    .firstWhere((e) => e.value == name, orElse: () => const MapEntry(12, 'Miscellaneous'))
    .key;

String categoryName(int? id) =>
    id == null ? 'Uncategorised' : (systemCategories[id] ?? _customNames[id] ?? 'Uncategorised');

String _norm(String s) => s.toLowerCase().trim();

/// Category for an EXPENSE merchant, in priority order:
///   1. the user's saved per-merchant override (learned choice), then
///   2. the seed merchant→category dictionary (cold-start guess), then
///   3. **null** — unknown/first-sighting → the app should PROMPT the user (push + in-app popup).
/// Returning null (instead of defaulting to Miscellaneous) is what surfaces a new merchant for tagging.
int? categoryForMerchant(String? merchantText) {
  if (merchantText == null) return null;
  final key = _norm(merchantText);
  for (final e in _overrides.entries) {
    if (key.contains(e.key) || e.key.contains(key)) return e.value;
  }
  final dict = merchantDictionary();
  for (final name in dict.keys) {
    if (key.contains(name)) return _idForName(dict[name]!);
  }
  return null;
}

/// True when this expense merchant has no known category yet — i.e. it needs a prompt.
bool needsCategory(String? merchantText) =>
    merchantText != null && categoryForMerchant(merchantText) == null;

// ── mutators (in-memory; CategoryStore persists + re-primes) ───────────────────────────────────
void setOverrideInMemory(String merchant, int categoryId) => _overrides[_norm(merchant)] = categoryId;

/// Register a new custom category, returning its id (≥100, monotonic above existing customs).
int addCustomCategoryInMemory(String name) {
  final id = _customNames.keys.fold(99, (m, k) => k > m ? k : m) + 1;
  _customNames[id] = name.trim();
  return id;
}
