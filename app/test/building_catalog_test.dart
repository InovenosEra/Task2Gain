// test/building_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game/building_catalog.dart';

void main() {
  test('catalog has unique ids and sane values', () {
    final ids = kBuildingCatalog.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
    for (final b in kBuildingCatalog) {
      expect(b.baseTokenCost, greaterThan(0));
      expect(b.baseXpReward, greaterThan(0));
    }
  });

  test('lookup by id', () {
    expect(buildingTypeById('house')?.baseTokenCost, 10);
    expect(buildingTypeById('nope'), isNull);
  });

  test('cost, xp and value scale by level', () {
    final house = buildingTypeById('house')!;
    expect(house.tokenCostForLevel(1), 10);
    expect(house.tokenCostForLevel(2), 20);
    expect(house.xpRewardForLevel(1), 8);
    expect(house.xpRewardForLevel(2), 16);
    expect(house.valueAtLevel(2), 20);
  });
}
