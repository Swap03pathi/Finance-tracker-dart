import 'dart:convert';
import 'package:finman_engine/finman_engine.dart'
    show
        primeCategoryState,
        categoryOverrides,
        customCategories,
        setOverrideInMemory,
        addCustomCategoryInMemory;
import 'database.dart';

/// Durable home for the user's category choices (doc 05 §payee-tag, brought forward for dogfood):
///   - `catOverrides`: merchant → categoryId (remembered once set; per-user, never mutates the seed dict)
///   - `catCustom`:    customId → name (categories the user added)
/// Loaded once at startup into the engine's in-memory state so `categoryForMerchant` stays synchronous.
class CategoryStore {
  final LocalDb db;
  CategoryStore(this.db);

  Future<void> load() async {
    final ov = await db.getState('catOverrides');
    final cu = await db.getState('catCustom');
    primeCategoryState(
      overrides: ov != null ? Map<String, int>.from(jsonDecode(ov) as Map) : {},
      customNames: cu != null
          ? {for (final e in (jsonDecode(cu) as Map).entries) int.parse('${e.key}'): '${e.value}'}
          : {},
    );
  }

  Future<void> _save() async {
    await db.setState('catOverrides', jsonEncode(categoryOverrides));
    await db.setState('catCustom', jsonEncode({for (final e in customCategories.entries) '${e.key}': e.value}));
  }

  /// Remember a merchant → category choice for this user.
  Future<void> setOverride(String merchant, int categoryId) async {
    setOverrideInMemory(merchant, categoryId);
    await _save();
  }

  /// Add a new custom category; returns its id.
  Future<int> addCustom(String name) async {
    final id = addCustomCategoryInMemory(name);
    await _save();
    return id;
  }
}
