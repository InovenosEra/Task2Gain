// lib/services/city_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/building_catalog.dart';
import '../models/city.dart';

class CityService {
  CityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _cityRef(String uid) =>
      _firestore.collection('cities').doc(uid);
  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _firestore.collection('wallets').doc(uid);

  /// Places a new building: debits tokens, credits XP (the `points` field),
  /// and appends the building. Absolute writes (read-modify-write) so the
  /// behaviour is correct and testable under fake_cloud_firestore.
  Future<void> placeBuilding({
    required String uid,
    required String typeId,
    required int gridX,
    required int gridY,
  }) async {
    final type = buildingTypeById(typeId);
    if (type == null) throw StateError('סוג מבנה לא ידוע: $typeId');

    await _firestore.runTransaction((tx) async {
      final citySnap = await tx.get(_cityRef(uid));
      final walletSnap = await tx.get(_walletRef(uid));
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');

      final city = City.fromDoc(uid, citySnap.data());
      if (city.isOccupied(gridX, gridY)) throw StateError('המשבצת תפוסה');

      final wallet = walletSnap.data()!;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
      final cost = type.tokenCostForLevel(1);
      if (tokens < cost) throw StateError('אין מספיק טוקנים');

      final xp = type.xpRewardForLevel(1);
      final points = (wallet['points'] as num?)?.toInt() ?? 0;
      final lifetime = (wallet['lifetimeEarned'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{'points': 0, 'money': 0};

      final buildings = [
        ...city.buildings,
        PlacedBuilding(typeId: typeId, gridX: gridX, gridY: gridY, level: 1),
      ];

      tx.set(_cityRef(uid), {
        'uid': uid,
        'buildings': buildings.map((b) => b.toMap()).toList(),
      }, SetOptions(merge: true));

      tx.update(_walletRef(uid), {
        'tokens': tokens - cost,
        'points': points + xp,
        'lifetimeEarned': {
          'points': ((lifetime['points'] as num?)?.toInt() ?? 0) + xp,
          'money': (lifetime['money'] as num?)?.toInt() ?? 0,
        },
      });
    });
  }

  Stream<City> watchCity(String uid) =>
      _cityRef(uid).snapshots().map((s) => City.fromDoc(uid, s.data()));
}
