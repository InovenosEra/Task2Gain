// lib/services/city_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../game/building_catalog.dart';
import '../game/economy_config.dart';
import '../models/city.dart';

/// Outcome of a place/upgrade action, so the UI can celebrate it.
class BuildResult {
  const BuildResult({
    this.bonusTokens = 0,
    this.xpGained = 0,
    this.tokensSpent = 0,
  });
  final int bonusTokens;
  final int xpGained;
  final int tokensSpent;
  bool get hasBonus => bonusTokens > 0;
}

class CityService {
  CityService({
    FirebaseFirestore? firestore,
    double Function()? rng,
    DateTime Function()? clock,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _rng = rng ?? (() => Random().nextDouble()),
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;

  /// Returns a value in [0, 1); injected in tests to force/suppress surprises.
  final double Function() _rng;

  /// Wall clock; injected in tests to control the "today" used by the daily
  /// reward.
  final DateTime Function() _clock;

  String _today() {
    final d = _clock();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Whether the once-per-day reward can be claimed (not yet claimed today).
  Future<bool> isDailyRewardAvailable(String uid) async {
    final snap = await _walletRef(uid).get();
    return (snap.data()?['lastDailyClaim'] as String?) != _today();
  }

  /// Claims the daily reward: credits [kDailyRewardTokens] once per calendar
  /// day. Returns the amount granted (0 if already claimed today).
  Future<int> claimDailyReward(String uid) async {
    return _firestore.runTransaction<int>((tx) async {
      final ref = _walletRef(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('ארנק לא נמצא');
      final w = snap.data()!;
      if ((w['lastDailyClaim'] as String?) == _today()) return 0;
      final tokens = (w['tokens'] as num?)?.toInt() ?? 0;
      tx.update(ref, {
        'tokens': tokens + kDailyRewardTokens,
        'lastDailyClaim': _today(),
      });
      return kDailyRewardTokens;
    });
  }

  DocumentReference<Map<String, dynamic>> _cityRef(String uid) =>
      _firestore.collection('cities').doc(uid);
  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _firestore.collection('wallets').doc(uid);

  /// Rolls for a surprise bonus. Kept separate so both place and upgrade
  /// share the exact same delight rule.
  int _rollBonus() => _rng() < kSurpriseChance ? kSurpriseBonusTokens : 0;

  /// Places a new building: debits tokens, credits XP (the `points` field),
  /// appends the building, and may award a surprise token bonus. Absolute
  /// writes (read-modify-write) so the behaviour is testable under
  /// fake_cloud_firestore. Returns the [BuildResult] (any bonus awarded).
  Future<BuildResult> placeBuilding({
    required String uid,
    required String typeId,
    required int gridX,
    required int gridY,
  }) async {
    final type = buildingTypeById(typeId);
    if (type == null) throw StateError('סוג מבנה לא ידוע: $typeId');

    return _firestore.runTransaction<BuildResult>((tx) async {
      final citySnap = await tx.get(_cityRef(uid));
      final walletSnap = await tx.get(_walletRef(uid));
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');

      final city = City.fromDoc(uid, citySnap.data());
      if (city.isOccupied(gridX, gridY)) throw StateError('המשבצת תפוסה');

      final wallet = walletSnap.data()!;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
      final cost = type.tokenCostForLevel(1);
      if (tokens < cost) throw StateError('אין מספיק אסימונים');

      final xp = type.xpRewardForLevel(1);
      final bonus = _rollBonus();
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
        'tokens': tokens - cost + bonus,
        'points': points + xp,
        'lifetimeEarned': {
          'points': ((lifetime['points'] as num?)?.toInt() ?? 0) + xp,
          'money': (lifetime['money'] as num?)?.toInt() ?? 0,
          'tokens': ((lifetime['tokens'] as num?)?.toInt() ?? 0) + bonus,
        },
      });

      return BuildResult(bonusTokens: bonus, xpGained: xp, tokensSpent: cost);
    });
  }

  /// Upgrades the building at ([gridX],[gridY]) to its next level: charges the
  /// rising token cost, credits the level's XP, and may award a surprise bonus.
  Future<BuildResult> upgradeBuilding({
    required String uid,
    required int gridX,
    required int gridY,
  }) async {
    return _firestore.runTransaction<BuildResult>((tx) async {
      final citySnap = await tx.get(_cityRef(uid));
      final walletSnap = await tx.get(_walletRef(uid));
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');

      final city = City.fromDoc(uid, citySnap.data());
      final idx = city.indexAt(gridX, gridY);
      if (idx < 0) throw StateError('אין מבנה במשבצת הזו');

      final existing = city.buildings[idx];
      final type = buildingTypeById(existing.typeId);
      if (type == null) throw StateError('סוג מבנה לא ידוע: ${existing.typeId}');

      final nextLevel = existing.level + 1;
      final cost = type.tokenCostForLevel(nextLevel);
      final xp = type.xpRewardForLevel(nextLevel);

      final wallet = walletSnap.data()!;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
      if (tokens < cost) throw StateError('אין מספיק אסימונים');
      final bonus = _rollBonus();
      final points = (wallet['points'] as num?)?.toInt() ?? 0;
      final lifetime = (wallet['lifetimeEarned'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{'points': 0, 'money': 0};

      final buildings = [...city.buildings];
      buildings[idx] = existing.copyWith(level: nextLevel);

      tx.set(_cityRef(uid), {
        'uid': uid,
        'buildings': buildings.map((b) => b.toMap()).toList(),
      }, SetOptions(merge: true));

      tx.update(_walletRef(uid), {
        'tokens': tokens - cost + bonus,
        'points': points + xp,
        'lifetimeEarned': {
          'points': ((lifetime['points'] as num?)?.toInt() ?? 0) + xp,
          'money': (lifetime['money'] as num?)?.toInt() ?? 0,
          'tokens': ((lifetime['tokens'] as num?)?.toInt() ?? 0) + bonus,
        },
      });

      return BuildResult(bonusTokens: bonus, xpGained: xp, tokensSpent: cost);
    });
  }

  /// Removes the building at ([gridX],[gridY]) and refunds half of its current
  /// value in tokens (XP already earned is kept; the partial refund + the daily
  /// XP→token cap keep build/demolish from being a farm). Returns the refund.
  Future<int> removeBuilding({
    required String uid,
    required int gridX,
    required int gridY,
  }) async {
    return _firestore.runTransaction<int>((tx) async {
      final citySnap = await tx.get(_cityRef(uid));
      final walletSnap = await tx.get(_walletRef(uid));
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');

      final city = City.fromDoc(uid, citySnap.data());
      final idx = city.indexAt(gridX, gridY);
      if (idx < 0) throw StateError('אין מבנה במשבצת הזו');

      final existing = city.buildings[idx];
      final type = buildingTypeById(existing.typeId);
      final refund = type == null ? 0 : type.valueAtLevel(existing.level) ~/ 2;

      final buildings = [...city.buildings]..removeAt(idx);
      final wallet = walletSnap.data()!;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;

      tx.set(_cityRef(uid), {
        'uid': uid,
        'buildings': buildings.map((b) => b.toMap()).toList(),
      }, SetOptions(merge: true));
      tx.update(_walletRef(uid), {'tokens': tokens + refund});

      return refund;
    });
  }

  /// Moves the building at ([fromX],[fromY]) to an empty ([toX],[toY]),
  /// keeping its type and level. Free (no token change).
  Future<void> moveBuilding({
    required String uid,
    required int fromX,
    required int fromY,
    required int toX,
    required int toY,
  }) async {
    return _firestore.runTransaction<void>((tx) async {
      final citySnap = await tx.get(_cityRef(uid));
      final city = City.fromDoc(uid, citySnap.data());
      final idx = city.indexAt(fromX, fromY);
      if (idx < 0) throw StateError('אין מבנה במשבצת הזו');
      if ((fromX != toX || fromY != toY) && city.isOccupied(toX, toY)) {
        throw StateError('המשבצת תפוסה');
      }
      final b = city.buildings[idx];
      final buildings = [...city.buildings];
      buildings[idx] = PlacedBuilding(
          typeId: b.typeId, gridX: toX, gridY: toY, level: b.level);
      tx.set(_cityRef(uid), {
        'uid': uid,
        'buildings': buildings.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    });
  }

  /// Renames the city. Trimmed; capped to a sane length. Stored alongside the
  /// buildings on the same city doc (merge so buildings are untouched).
  Future<void> renameCity(String uid, String name) {
    final clean = name.trim();
    final capped = clean.length > 24 ? clean.substring(0, 24) : clean;
    return _cityRef(uid).set(
      {'uid': uid, 'name': capped},
      SetOptions(merge: true),
    );
  }

  Stream<City> watchCity(String uid) =>
      _cityRef(uid).snapshots().map((s) => City.fromDoc(uid, s.data()));
}
