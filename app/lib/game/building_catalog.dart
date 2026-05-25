// lib/game/building_catalog.dart
/// The buildings a player can place, with their token cost and XP reward.
/// All footprints are 1x1 for the MVP.
class BuildingType {
  const BuildingType({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.baseTokenCost,
    required this.baseXpReward,
  });

  final String id;
  final String displayName;
  final String icon;
  final int baseTokenCost;
  final int baseXpReward;

  /// Token cost to build/upgrade to [level] (level 1 = first placement).
  int tokenCostForLevel(int level) => baseTokenCost * level;

  /// XP awarded when building/upgrading to [level].
  int xpRewardForLevel(int level) => baseXpReward * level;

  /// City-value contribution of this building at [level].
  int valueAtLevel(int level) => baseTokenCost * level;
}

const List<BuildingType> kBuildingCatalog = [
  BuildingType(id: 'house',     displayName: 'בית',     icon: '🏠', baseTokenCost: 10, baseXpReward: 8),
  BuildingType(id: 'shop',      displayName: 'חנות',    icon: '🏪', baseTokenCost: 20, baseXpReward: 16),
  BuildingType(id: 'park',      displayName: 'פארק',    icon: '🌳', baseTokenCost: 8,  baseXpReward: 6),
  BuildingType(id: 'school',    displayName: 'בית ספר', icon: '🏫', baseTokenCost: 20, baseXpReward: 16),
  BuildingType(id: 'factory',   displayName: 'מפעל',    icon: '🏭', baseTokenCost: 30, baseXpReward: 26),
  BuildingType(id: 'apartment', displayName: 'בניין',   icon: '🏢', baseTokenCost: 25, baseXpReward: 22),
  BuildingType(id: 'tower',     displayName: 'מגדל',     icon: '🏙️', baseTokenCost: 45, baseXpReward: 40),
  BuildingType(id: 'cityhall',  displayName: 'עירייה',   icon: '🏛️', baseTokenCost: 35, baseXpReward: 30),
  BuildingType(id: 'hospital',  displayName: 'בית חולים', icon: '🏥', baseTokenCost: 40, baseXpReward: 34),
  BuildingType(id: 'cafe',      displayName: 'בית קפה',  icon: '☕', baseTokenCost: 18, baseXpReward: 14),
  BuildingType(id: 'bank',      displayName: 'בנק',      icon: '🏦', baseTokenCost: 50, baseXpReward: 44),
  BuildingType(id: 'decor',     displayName: 'קישוט',   icon: '🗿', baseTokenCost: 4,  baseXpReward: 2),
  BuildingType(id: 'road',      displayName: 'כביש',    icon: '🛣️', baseTokenCost: 2,  baseXpReward: 1),
];

BuildingType? buildingTypeById(String id) {
  for (final b in kBuildingCatalog) {
    if (b.id == id) return b;
  }
  return null;
}
