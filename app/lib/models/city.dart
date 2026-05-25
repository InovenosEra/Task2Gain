import '../game/building_catalog.dart';
import '../game/economy_config.dart';

class PlacedBuilding {
  const PlacedBuilding({
    required this.typeId,
    required this.gridX,
    required this.gridY,
    this.level = 1,
  });

  final String typeId;
  final int gridX;
  final int gridY;
  final int level;

  PlacedBuilding copyWith({int? level}) => PlacedBuilding(
        typeId: typeId,
        gridX: gridX,
        gridY: gridY,
        level: level ?? this.level,
      );

  Map<String, dynamic> toMap() =>
      {'type': typeId, 'gridX': gridX, 'gridY': gridY, 'level': level};

  factory PlacedBuilding.fromMap(Map<String, dynamic> m) => PlacedBuilding(
        typeId: (m['type'] as String?) ?? '',
        gridX: (m['gridX'] as num?)?.toInt() ?? 0,
        gridY: (m['gridY'] as num?)?.toInt() ?? 0,
        level: (m['level'] as num?)?.toInt() ?? 1,
      );
}

class City {
  const City({required this.uid, required this.buildings});

  final String uid;
  final List<PlacedBuilding> buildings;

  int get cityValue {
    var v = 0;
    for (final b in buildings) {
      final t = buildingTypeById(b.typeId);
      if (t != null) v += t.valueAtLevel(b.level);
    }
    return v;
  }

  int get cityLevel => cityLevelForValue(cityValue);

  bool isOccupied(int x, int y) =>
      buildings.any((b) => b.gridX == x && b.gridY == y);

  int indexAt(int x, int y) =>
      buildings.indexWhere((b) => b.gridX == x && b.gridY == y);

  factory City.fromDoc(String uid, Map<String, dynamic>? data) {
    final raw = (data?['buildings'] as List?)?.cast<dynamic>() ?? const [];
    return City(
      uid: uid,
      buildings: raw
          .map((e) => PlacedBuilding.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
