import 'package:finman_engine/finman_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => primeCategoryState()); // clean slate between tests

  test('seed dictionary gives a cold-start guess', () {
    expect(categoryForMerchant('Zomato'), 1); // Food
    expect(categoryForMerchant('Amazon Pay'), 2); // Shopping (contains "amazon")
  });

  test('unknown merchant returns null → prompt the user', () {
    expect(categoryForMerchant('Oraval travels'), isNull);
    expect(needsCategory('Oraval travels'), isTrue);
    expect(needsCategory('Zomato'), isFalse);
  });

  test('a saved override wins over the seed dictionary and is remembered', () {
    setOverrideInMemory('Oraval travels', 5); // Travel
    expect(categoryForMerchant('Oraval travels'), 5);
    expect(needsCategory('Oraval travels'), isFalse);
    // override beats the dictionary guess for a known merchant too
    setOverrideInMemory('zomato', 12);
    expect(categoryForMerchant('Zomato'), 12);
  });

  test('custom categories get ids ≥ 100 and resolve by name', () {
    final id = addCustomCategoryInMemory('Pets');
    expect(id >= 100, isTrue);
    expect(categoryName(id), 'Pets');
    expect(allCategories()[id], 'Pets');
  });

  test('priming clears in-memory state', () {
    setOverrideInMemory('foo', 3);
    addCustomCategoryInMemory('Bar');
    primeCategoryState();
    expect(categoryForMerchant('foo'), isNull);
    expect(customCategories.isEmpty, isTrue);
  });
}
