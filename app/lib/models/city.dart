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
        typeId: m['type'] is String ? m['type'] as String : '',
        gridX: _toInt(m['gridX']),
        gridY: _toInt(m['gridY']),
        level: _toInt(m['level'], 1),
      );
}

/// Tolerant int coercion: accepts num or numeric String, else [fallback].
/// Firestore data can be unexpectedly typed, so parsing must never throw.
int _toInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// Default Hebrew city names, picked deterministically from the uid so a
/// brand-new city always has a friendly title before the player renames it.
const List<String> _kDefaultCityNames = [
  'אורנים',
  'שדות זהב',
  'נווה שלום',
  'הר הזהב',
  'גן עדן',
  'כפר שמש',
  'מעיינות',
  'רמת אור',
];

class City {
  const City({required this.uid, required this.buildings, this.name = ''});

  final String uid;
  final List<PlacedBuilding> buildings;

  /// The player-chosen city name. Empty until the player renames it.
  final String name;

  /// Name to show in the UI: the chosen [name], or a stable default derived
  /// from the uid so every city reads as a real place from the start.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (uid.isEmpty) return _kDefaultCityNames.first;
    final i = uid.codeUnits.fold<int>(0, (a, b) => a + b) %
        _kDefaultCityNames.length;
    return _kDefaultCityNames[i];
  }

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
    final rawList = data?['buildings'];
    final raw = rawList is List ? rawList : const [];
    return City(
      uid: uid,
      name: data?['name'] is String ? data!['name'] as String : '',
      buildings: raw
          .whereType<Map>()
          .map((e) => PlacedBuilding.fromMap(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
