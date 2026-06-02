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
    required this.category,
  });

  final String id;
  final String displayName;
  final String icon;
  final int baseTokenCost;
  final int baseXpReward;

  /// Which [BuildingCategory] this type belongs to (by id).
  final String category;

  /// Token cost to build/upgrade to [level] (level 1 = first placement).
  int tokenCostForLevel(int level) => baseTokenCost * level;

  /// XP awarded when building/upgrading to [level].
  int xpRewardForLevel(int level) => baseXpReward * level;

  /// City-value contribution of this building at [level].
  int valueAtLevel(int level) => baseTokenCost * level;
}

/// A group of buildings shown in the build tray. The tray lists categories
/// first; picking one reveals its buildings.
class BuildingCategory {
  const BuildingCategory({
    required this.id,
    required this.displayName,
    required this.icon,
  });

  final String id;
  final String displayName;
  final String icon;
}

const List<BuildingCategory> kBuildingCategories = [
  BuildingCategory(id: 'residential', displayName: 'מגורים', icon: '🏘️'),
  BuildingCategory(id: 'business', displayName: 'עסקים', icon: '🛍️'),
  BuildingCategory(id: 'civic', displayName: 'ציבורי', icon: '🏛️'),
  BuildingCategory(id: 'scenery', displayName: 'נוף ותשתית', icon: '🌳'),
];

const List<BuildingType> kBuildingCatalog = [
  BuildingType(id: 'house',     displayName: 'בית',     icon: '🏠', baseTokenCost: 10, baseXpReward: 8,  category: 'residential'),
  BuildingType(id: 'apartment', displayName: 'בניין',   icon: '🏢', baseTokenCost: 25, baseXpReward: 22, category: 'residential'),
  BuildingType(id: 'tower',     displayName: 'מגדל',     icon: '🏙️', baseTokenCost: 45, baseXpReward: 40, category: 'residential'),
  BuildingType(id: 'shop',      displayName: 'חנות',    icon: '🏪', baseTokenCost: 20, baseXpReward: 16, category: 'business'),
  BuildingType(id: 'cafe',      displayName: 'בית קפה',  icon: '☕', baseTokenCost: 18, baseXpReward: 14, category: 'business'),
  BuildingType(id: 'factory',   displayName: 'מפעל',    icon: '🏭', baseTokenCost: 30, baseXpReward: 26, category: 'business'),
  BuildingType(id: 'bank',      displayName: 'בנק',      icon: '🏦', baseTokenCost: 50, baseXpReward: 44, category: 'business'),
  BuildingType(id: 'school',    displayName: 'בית ספר', icon: '🏫', baseTokenCost: 20, baseXpReward: 16, category: 'civic'),
  BuildingType(id: 'hospital',  displayName: 'בית חולים', icon: '🏥', baseTokenCost: 40, baseXpReward: 34, category: 'civic'),
  BuildingType(id: 'cityhall',  displayName: 'עירייה',   icon: '🏛️', baseTokenCost: 35, baseXpReward: 30, category: 'civic'),
  BuildingType(id: 'park',      displayName: 'פארק',    icon: '🌳', baseTokenCost: 8,  baseXpReward: 6,  category: 'scenery'),
  BuildingType(id: 'fountain',  displayName: 'מזרקה',    icon: '⛲', baseTokenCost: 12, baseXpReward: 8,  category: 'scenery'),
  BuildingType(id: 'decor',     displayName: 'קישוט',   icon: '🗿', baseTokenCost: 4,  baseXpReward: 2,  category: 'scenery'),
  BuildingType(id: 'road',      displayName: 'כביש',    icon: '🛣️', baseTokenCost: 2,  baseXpReward: 1,  category: 'scenery'),
];

BuildingType? buildingTypeById(String id) {
  for (final b in kBuildingCatalog) {
    if (b.id == id) return b;
  }
  return null;
}
