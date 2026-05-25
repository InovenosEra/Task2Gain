# Little City — Economy Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data + service layer for the Little City game economy — the two-currency model (tokens = play-fuel, XP = winnings), the city/building state, and the chore→token remap — fully tested, with no UI or game engine yet.

**Architecture:** Pure Dart services + models on top of the existing Firebase/Firestore backend, following the established transaction patterns in `wallet_service.dart` and `quest_instance_service.dart`. Building debits **tokens** and credits **XP** (the existing `points` field). Chores credit **tokens** (today they credit `points`). XP cashes out to money via the existing `convertPoints`, and a new lossy/capped `convertXpToTokens` closes the loop guard. City state lives in a new `cities/{uid}` document.

**Tech Stack:** Flutter, `cloud_firestore`, `fake_cloud_firestore` (tests). No Flame/UI in this plan.

> **Known test quirk (from project memory):** in `fake_cloud_firestore`, a `FieldValue.increment` *inside a transaction* resets the field to the delta rather than adding to it. Therefore: (a) new code in `CityService` uses **absolute read-modify-write** for `tokens`/`points` so tests assert exact values; (b) tests that exercise existing `increment`-based code seed the field at `0` and assert the awarded delta.

> **Scope note:** This is plan 1 of a sequence. Plan 2 = Flame isometric city engine (renders/edits this state). Plan 3 = game UI/HUD + retiring the Prize Machine from navigation. Plan 4 = AI art spec + sprite integration. Retiring the Prize Machine and any UI live in Plan 3 — this plan touches no widgets.

---

## File Structure

- `lib/game/economy_config.dart` — **Create.** Central tuning constants (starting tokens, XP→token rate/cap, city-level curve) + pure helpers. One responsibility: economy numbers.
- `lib/game/building_catalog.dart` — **Create.** `BuildingType` definition + the const catalog + lookup. One responsibility: what can be built and its cost/XP/value.
- `lib/models/city.dart` — **Create.** `City` + `PlacedBuilding` value objects with Firestore (de)serialization and derived `cityValue`/`cityLevel`/occupancy. One responsibility: city state shape.
- `lib/services/city_service.dart` — **Create.** `placeBuilding`, `upgradeBuilding`, `watchCity`. One responsibility: mutate/read city state + the token/XP side effects.
- `lib/services/wallet_service.dart` — **Modify.** Add `convertXpToTokens` (lossy, daily-capped). Keep everything else.
- `lib/services/quest_instance_service.dart` — **Modify.** Remap `_writeEarn` so a chore credits **tokens** (chore value + bonuses) instead of `points`.
- `lib/services/wallet_seed.dart` — **Create.** Pure `initialWalletData(...)` helper returning the new-wallet map with `tokens: kStartingTokens`. Lets us test seeding without auth mocks.
- `lib/services/auth_service.dart` — **Modify.** Use `initialWalletData(...)` in both signup paths.
- Tests: `test/economy_config_test.dart`, `test/building_catalog_test.dart`, `test/city_model_test.dart`, `test/city_service_test.dart`, `test/wallet_xp_to_tokens_test.dart`, `test/wallet_seed_test.dart`, and edits to `test/quest_instance_service_test.dart`.

---

## Task 1: Economy config

**Files:**
- Create: `lib/game/economy_config.dart`
- Test: `test/economy_config_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/economy_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game/economy_config.dart';

void main() {
  test('starting tokens is 100', () {
    expect(kStartingTokens, 100);
  });

  test('city level rises one per kCityValuePerLevel of value', () {
    expect(cityLevelForValue(0), 1);
    expect(cityLevelForValue(kCityValuePerLevel - 1), 1);
    expect(cityLevelForValue(kCityValuePerLevel), 2);
    expect(cityLevelForValue(kCityValuePerLevel * 3), 4);
  });

  test('xp converts to tokens at the lossy rate, rounded down', () {
    // rate 0.5 => 2 XP buys 1 token
    expect(tokensFromXp(0), 0);
    expect(tokensFromXp(1), 0);
    expect(tokensFromXp(2), 1);
    expect(tokensFromXp(5), 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/economy_config_test.dart`
Expected: FAIL — `economy_config.dart` / symbols not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/game/economy_config.dart
/// Central economy tuning for Little City. Tweak the game's feel here.

/// Tokens every brand-new player starts with (play-fuel before any chore).
const int kStartingTokens = 100;

/// City level curve: every this much city-value = one level.
const int kCityValuePerLevel = 100;

/// XP -> tokens conversion: the deliberately-lossy loop guard.
/// 0.5 => 2 XP buys 1 token.
const double kXpToTokenRate = 0.5;

/// Max tokens a player may obtain from XP per calendar day (UTC).
const int kXpToTokenDailyCap = 20;

/// City level for a given total city value (level 1 at value 0).
int cityLevelForValue(int cityValue) => 1 + (cityValue ~/ kCityValuePerLevel);

/// Tokens produced by converting [xp] XP, rounded down, never negative.
int tokensFromXp(int xp) => xp <= 0 ? 0 : (xp * kXpToTokenRate).floor();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/economy_config_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game/economy_config.dart app/test/economy_config_test.dart
git commit -m "feat(economy): add central economy config + helpers"
```

---

## Task 2: Building catalog

**Files:**
- Create: `lib/game/building_catalog.dart`
- Test: `test/building_catalog_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/building_catalog_test.dart`
Expected: FAIL — file/symbols not found.

- [ ] **Step 3: Write minimal implementation**

```dart
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
  BuildingType(id: 'house',     displayName: 'House',      icon: '🏠', baseTokenCost: 10, baseXpReward: 8),
  BuildingType(id: 'shop',      displayName: 'Shop',       icon: '🏪', baseTokenCost: 20, baseXpReward: 16),
  BuildingType(id: 'park',      displayName: 'Park',       icon: '🌳', baseTokenCost: 8,  baseXpReward: 6),
  BuildingType(id: 'school',    displayName: 'School',     icon: '🏫', baseTokenCost: 20, baseXpReward: 16),
  BuildingType(id: 'factory',   displayName: 'Factory',    icon: '🏭', baseTokenCost: 30, baseXpReward: 26),
  BuildingType(id: 'apartment', displayName: 'Apartments', icon: '🏢', baseTokenCost: 25, baseXpReward: 22),
  BuildingType(id: 'decor',     displayName: 'Decoration', icon: '🗿', baseTokenCost: 4,  baseXpReward: 2),
  BuildingType(id: 'road',      displayName: 'Road',       icon: '🛣️', baseTokenCost: 2,  baseXpReward: 1),
];

BuildingType? buildingTypeById(String id) {
  for (final b in kBuildingCatalog) {
    if (b.id == id) return b;
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/building_catalog_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/game/building_catalog.dart app/test/building_catalog_test.dart
git commit -m "feat(economy): add building catalog with cost/xp/value"
```

---

## Task 3: City model

**Files:**
- Create: `lib/models/city.dart`
- Test: `test/city_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/city_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/models/city.dart';

void main() {
  test('fromDoc handles missing data', () {
    final c = City.fromDoc('u1', null);
    expect(c.buildings, isEmpty);
    expect(c.cityValue, 0);
    expect(c.cityLevel, 1);
  });

  test('round-trips buildings and derives value + level', () {
    final c = City.fromDoc('u1', {
      'buildings': [
        {'type': 'house', 'gridX': 0, 'gridY': 0, 'level': 1}, // value 10
        {'type': 'shop', 'gridX': 1, 'gridY': 0, 'level': 2},  // value 40
      ],
    });
    expect(c.buildings.length, 2);
    expect(c.cityValue, 50);
    expect(c.cityLevel, 1); // 50 < 100
    expect(c.isOccupied(0, 0), isTrue);
    expect(c.isOccupied(5, 5), isFalse);
  });

  test('PlacedBuilding toMap matches schema', () {
    const b = PlacedBuilding(typeId: 'park', gridX: 3, gridY: 4, level: 1);
    expect(b.toMap(), {'type': 'park', 'gridX': 3, 'gridY': 4, 'level': 1});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/city_model_test.dart`
Expected: FAIL — file/symbols not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/models/city.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/city_model_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/city.dart app/test/city_model_test.dart
git commit -m "feat(economy): add City + PlacedBuilding model"
```

---

## Task 4: CityService.placeBuilding

**Files:**
- Create: `lib/services/city_service.dart`
- Test: `test/city_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/city_service_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/models/city.dart';
import 'package:task2play/services/city_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CityService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = CityService(firestore: db);
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1', 'familyId': 'fam1',
      'points': 0, 'moneyILS': 0, 'tokens': 100,
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
  });

  test('placeBuilding debits tokens, credits XP, persists building', () async {
    await service.placeBuilding(
        uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0); // cost 10, xp 8

    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 90);
    expect(w['points'], 8);
    expect((w['lifetimeEarned'] as Map)['points'], 8);

    final c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.buildings.length, 1);
    expect(c.buildings.first.typeId, 'house');
    expect(c.cityValue, 10);
  });

  test('placeBuilding rejects insufficient tokens', () async {
    await db.collection('wallets').doc('kid1').set({'tokens': 5}, SetOptions(merge: true));
    expect(
      () => service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0),
      throwsA(isA<StateError>()),
    );
  });

  test('placeBuilding rejects an occupied cell', () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    expect(
      () => service.placeBuilding(uid: 'kid1', typeId: 'park', gridX: 0, gridY: 0),
      throwsA(isA<StateError>()),
    );
  });

  test('placeBuilding rejects unknown type', () async {
    expect(
      () => service.placeBuilding(uid: 'kid1', typeId: 'castle', gridX: 0, gridY: 0),
      throwsA(isA<StateError>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/city_service_test.dart`
Expected: FAIL — `city_service.dart` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/city_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/city_service.dart app/test/city_service_test.dart
git commit -m "feat(economy): CityService.placeBuilding (tokens out, XP in)"
```

---

## Task 5: CityService.upgradeBuilding

**Files:**
- Modify: `lib/services/city_service.dart`
- Test: `test/city_service_test.dart` (add cases)

- [ ] **Step 1: Write the failing test (append to existing file)**

```dart
  test('upgradeBuilding raises level, charges rising cost, credits XP', () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    // After place: tokens 90, points 8, house level 1.
    await service.upgradeBuilding(uid: 'kid1', gridX: 0, gridY: 0);
    // Upgrade to level 2 costs 10*2=20, awards 8*2=16 XP.

    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 70); // 90 - 20
    expect(w['points'], 24); // 8 + 16

    final c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.buildings.single.level, 2);
    expect(c.cityValue, 20); // house at level 2 => value 20
  });

  test('upgradeBuilding throws when no building at cell', () async {
    expect(
      () => service.upgradeBuilding(uid: 'kid1', gridX: 9, gridY: 9),
      throwsA(isA<StateError>()),
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/city_service_test.dart`
Expected: FAIL — `upgradeBuilding` not defined.

- [ ] **Step 3: Add the implementation to `CityService`**

```dart
  /// Upgrades the building at ([gridX],[gridY]) to its next level: charges the
  /// rising token cost and credits the level's XP.
  Future<void> upgradeBuilding({
    required String uid,
    required int gridX,
    required int gridY,
  }) async {
    await _firestore.runTransaction((tx) async {
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
      if (tokens < cost) throw StateError('אין מספיק טוקנים');
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
        'tokens': tokens - cost,
        'points': points + xp,
        'lifetimeEarned': {
          'points': ((lifetime['points'] as num?)?.toInt() ?? 0) + xp,
          'money': (lifetime['money'] as num?)?.toInt() ?? 0,
        },
      });
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/city_service_test.dart`
Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/city_service.dart app/test/city_service_test.dart
git commit -m "feat(economy): CityService.upgradeBuilding with rising cost"
```

---

## Task 6: XP → tokens conversion (loop guard)

**Files:**
- Modify: `lib/services/wallet_service.dart`
- Test: `test/wallet_xp_to_tokens_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/wallet_xp_to_tokens_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/services/wallet_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WalletService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = WalletService(firestore: db);
    await db.collection('users').doc('kid1').set({'familyId': 'fam1'});
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1', 'familyId': 'fam1',
      'points': 100, 'moneyILS': 0, 'tokens': 10,
      'lifetimeEarned': {'points': 100, 'money': 0},
    });
  });

  test('converts XP to tokens at the lossy rate', () async {
    final got = await service.convertXpToTokens(userUid: 'kid1', xpToSpend: 20);
    expect(got, 10); // 20 XP * 0.5 = 10 tokens
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['points'], 80);  // 100 - 20
    expect(w['tokens'], 20);  // 10 + 10
  });

  test('rejects more XP than the player has', () async {
    expect(
      () => service.convertXpToTokens(userUid: 'kid1', xpToSpend: 999),
      throwsA(isA<StateError>()),
    );
  });

  test('enforces the daily token cap', () async {
    // Cap is 20 tokens/day. 60 XP would yield 30 tokens — must be blocked.
    expect(
      () => service.convertXpToTokens(userUid: 'kid1', xpToSpend: 60),
      throwsA(isA<StateError>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/wallet_xp_to_tokens_test.dart`
Expected: FAIL — `convertXpToTokens` not defined.

- [ ] **Step 3: Add the implementation to `WalletService`**

Add this import at the top of `lib/services/wallet_service.dart` (below the existing import):

```dart
import '../game/economy_config.dart';
```

Add this method inside the `WalletService` class:

```dart
  /// Trades XP (the `points` field) for tokens at the deliberately-lossy
  /// [kXpToTokenRate], capped at [kXpToTokenDailyCap] tokens per UTC day.
  /// Returns the number of tokens credited. This is the loop guard that keeps
  /// chores necessary. Uses absolute writes so it is testable.
  Future<int> convertXpToTokens({
    required String userUid,
    required int xpToSpend,
  }) async {
    if (xpToSpend <= 0) throw StateError('יש להמיר כמות חיובית של XP');
    final tokensOut = tokensFromXp(xpToSpend);
    if (tokensOut <= 0) throw StateError('כמות קטנה מדי להמרה');
    if (tokensOut > kXpToTokenDailyCap) {
      throw StateError('המקסימום היומי הוא $kXpToTokenDailyCap טוקנים');
    }

    final walletRef = _firestore.collection('wallets').doc(userUid);
    final userRef = _firestore.collection('users').doc(userUid);
    final today = _utcDayKey(DateTime.now());

    return _firestore.runTransaction<int>((tx) async {
      final walletSnap = await tx.get(walletRef);
      final userSnap = await tx.get(userRef);
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');
      final wallet = walletSnap.data()!;
      final points = (wallet['points'] as num?)?.toInt() ?? 0;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
      if (xpToSpend > points) throw StateError('אין מספיק XP');

      // Daily cap (resets when the UTC date rolls over).
      final capMap = (userSnap.data()?['xpToTokenToday'] as Map?)
              ?.cast<String, dynamic>() ??
          const {};
      final usedToday =
          capMap['date'] == today ? (capMap['tokens'] as num?)?.toInt() ?? 0 : 0;
      if (usedToday + tokensOut > kXpToTokenDailyCap) {
        throw StateError('חרגת מהמכסה היומית להמרה');
      }

      tx.update(walletRef, {
        'points': points - xpToSpend,
        'tokens': tokens + tokensOut,
      });
      tx.set(userRef, {
        'xpToTokenToday': {'date': today, 'tokens': usedToday + tokensOut},
      }, SetOptions(merge: true));

      return tokensOut;
    });
  }

  static String _utcDayKey(DateTime t) {
    final u = t.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/wallet_xp_to_tokens_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/wallet_service.dart app/test/wallet_xp_to_tokens_test.dart
git commit -m "feat(economy): XP->tokens lossy/capped conversion (loop guard)"
```

---

## Task 7: Chores credit tokens (remap)

Currently `_writeEarn` in `quest_instance_service.dart` credits the chore value to `points` and bonus `tokens` from daily-goal/streak. In the new model a chore is the player's **fuel**, so its value plus bonuses go to **tokens**, and `points` (XP) is no longer credited by chores (XP comes from building). Streak/daily-goal/badges are kept.

**Files:**
- Modify: `lib/services/quest_instance_service.dart`
- Test: `test/quest_instance_service_test.dart` (update expectations)

- [ ] **Step 1: Update the existing tests to the new behavior**

In `test/quest_instance_service_test.dart`, replace the `approve credits points...` test and the `crossing the daily goal...` test and the `completeAuto credits instantly...` test with these (the chore value now lands in `tokens`, plus the daily-goal bonus; `points` stays 0):

```dart
  test('approve credits tokens (chore value + daily-goal bonus), no XP', () async {
    // quest value 60 >= daily goal 50 => +1 daily-goal bonus token.
    final id = await service.startQuest(quest: quest(), kidUid: 'kid1');
    await service.submit(id);
    await service.approve(instanceId: id, adminUid: 'parent1');

    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 61); // 60 value + 1 daily-goal bonus
    expect(wallet['points'], 0);  // chores no longer grant XP

    final user = (await db.collection('users').doc('kid1').get()).data()!;
    expect(user['questsCompleted'], 1);
    expect((user['streak'] as Map)['current'], 1);
  });

  test('chore below daily goal grants only its value in tokens', () async {
    final id = await service.startQuest(quest: quest(points: 30), kidUid: 'kid1');
    await service.submit(id);
    await service.approve(instanceId: id, adminUid: 'parent1');
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 30); // 30 value, 30 < goal 50 so no bonus
    expect(wallet['points'], 0);
  });

  test('completeAuto credits tokens instantly without submit', () async {
    final id = await service.completeAuto(
        quest: quest(points: 30, mode: QuestApprovalMode.auto), kidUid: 'kid1');
    final inst = (await db.collection('questInstances').doc(id).get()).data()!;
    expect(inst['status'], 'approved');
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 30); // 30 value, below goal so no bonus
    expect(wallet['points'], 0);
  });
```

Leave the streak tests (`streak continues...`, `streak resets...`), the `already counted today...` test, the `milestone token lands...` test, and the `first quest unlocks...` badge test unchanged — they assert streak/badges/bonus-token behavior that is preserved. (The `milestone` and `already counted today` tests use a 10-point quest; note that under the remap those 10 value-tokens are also credited, but those tests only assert streak and the *bonus* token count via deltas — keep them as-is and confirm they still pass; if a `tokens` assertion there now fails because value is included, update that assertion to add the quest value: day-7 test becomes `expect(wallet['tokens'], 13)` (10 value + 3 milestone) and the already-counted test becomes `expect(wallet['tokens'], 10)` (10 value, no bonus).)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/quest_instance_service_test.dart`
Expected: FAIL — current code still credits `points`, so `tokens`/`points` assertions mismatch.

- [ ] **Step 3: Edit `_writeEarn` in `quest_instance_service.dart`**

Replace the two `tx.set(...)` wallet/user write blocks (the wallet `tx.set(earn.walletRef, {...})` call) so the chore value goes to tokens and points is not credited. Specifically, change the wallet write from:

```dart
    tx.set(earn.walletRef, {
      'points': FieldValue.increment(points),
      'tokens': FieldValue.increment(tokensEarned),
      'lifetimeEarned': {
        'points': newLifetimePoints,
        'money': (lifetime['money'] as num?)?.toInt() ?? 0,
      },
    }, SetOptions(merge: true));
```

to:

```dart
    // New model: the chore's value is play-fuel (tokens), plus any
    // daily-goal/streak bonus tokens. Chores no longer grant XP (points);
    // XP comes from building the city.
    tx.set(earn.walletRef, {
      'tokens': FieldValue.increment(points + tokensEarned),
      'lifetimeEarned': {
        'tokens': ((lifetime['tokens'] as num?)?.toInt() ?? 0) + points + tokensEarned,
        'money': (lifetime['money'] as num?)?.toInt() ?? 0,
      },
    }, SetOptions(merge: true));
```

Then update the badge metric so it no longer depends on chore points. Change:

```dart
    final metrics = BadgeMetrics(
      lifetimePoints: newLifetimePoints,
      currentStreak: streakCurrent,
      longestStreak: streakLongest,
      questsCompleted: questsCompleted,
    );
```

to:

```dart
    final metrics = BadgeMetrics(
      lifetimePoints: 0, // chores no longer track points; badges use streak/quests
      currentStreak: streakCurrent,
      longestStreak: streakLongest,
      questsCompleted: questsCompleted,
    );
```

And delete the now-unused `newLifetimePoints` local (the line `final newLifetimePoints = ((lifetime['points'] as num?)?.toInt() ?? 0) + points;`) to avoid an analyzer warning.

> Note on the fake-firestore increment quirk: the updated tests assert `tokens` as deltas from the `0` seed in `setUp`, so `increment(points + tokensEarned)` reads correctly (e.g. 61, 30).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/quest_instance_service_test.dart`
Expected: PASS (all tests, including unchanged streak/badge cases).

- [ ] **Step 5: Commit**

```bash
git add app/lib/services/quest_instance_service.dart app/test/quest_instance_service_test.dart
git commit -m "feat(economy): chores credit tokens (play-fuel), not XP"
```

---

## Task 8: New players start with 100 tokens

**Files:**
- Create: `lib/services/wallet_seed.dart`
- Modify: `lib/services/auth_service.dart`
- Test: `test/wallet_seed_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/wallet_seed_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game/economy_config.dart';
import 'package:task2play/services/wallet_seed.dart';

void main() {
  test('initial wallet starts with kStartingTokens and zeroed rest', () {
    final w = initialWalletData(uid: 'u1', familyId: 'fam1');
    expect(w['tokens'], kStartingTokens);
    expect(w['points'], 0);
    expect(w['moneyILS'], 0);
    expect(w['userId'], 'u1');
    expect(w['familyId'], 'fam1');
    expect((w['lifetimeEarned'] as Map)['points'], 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/wallet_seed_test.dart`
Expected: FAIL — `wallet_seed.dart` not found.

- [ ] **Step 3: Create the helper**

```dart
// lib/services/wallet_seed.dart
import '../game/economy_config.dart';

/// The Firestore document a brand-new player's wallet starts with.
/// Players begin with [kStartingTokens] tokens so the game is fun before
/// any chore is required.
Map<String, dynamic> initialWalletData({
  required String uid,
  required String familyId,
}) {
  return {
    'userId': uid,
    'familyId': familyId,
    'points': 0,
    'moneyILS': 0,
    'tokens': kStartingTokens,
    'cosmeticsOwned': <String>[],
    'lifetimeEarned': {'points': 0, 'money': 0, 'tokens': 0},
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/wallet_seed_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Use the helper in `auth_service.dart`**

Add the import at the top of `lib/services/auth_service.dart`:

```dart
import 'wallet_seed.dart';
```

In `signUpParent`, replace:

```dart
    batch.set(_firestore.collection('wallets').doc(uid), {
      'userId': uid,
      'familyId': familyRef.id,
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'cosmeticsOwned': <String>[],
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
```

with:

```dart
    batch.set(_firestore.collection('wallets').doc(uid),
        initialWalletData(uid: uid, familyId: familyRef.id));
```

In `signUpWithInvite`, replace:

```dart
    batch.set(_firestore.collection('wallets').doc(uid), {
      'userId': uid,
      'familyId': familyId,
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'cosmeticsOwned': <String>[],
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
```

with:

```dart
    batch.set(_firestore.collection('wallets').doc(uid),
        initialWalletData(uid: uid, familyId: familyId));
```

- [ ] **Step 6: Verify the project still analyzes & full suite passes**

Run: `cd app && flutter analyze && flutter test`
Expected: analyze clean (no new issues); all tests pass.

- [ ] **Step 7: Commit**

```bash
git add app/lib/services/wallet_seed.dart app/lib/services/auth_service.dart app/test/wallet_seed_test.dart
git commit -m "feat(economy): new players start with 100 tokens"
```

---

## Self-Review

**Spec coverage (spec §6 economy, §7 architecture):**
- Tokens = play-fuel earned by chores → Task 7. ✅
- 100 starting tokens → Tasks 1 + 8. ✅
- Building costs/upgrade scaling → Tasks 2, 4, 5. ✅
- XP = winnings earned by building → Tasks 4, 5 (credit `points`). ✅
- XP → money (existing `convertPoints`) and XP → prize (money → rewards shop) → no new code, confirmed existing. ✅
- XP → tokens lossy/capped loop guard → Task 6. ✅
- City state independent of XP, permanent → Task 3 (`City`), Tasks 4–5 (city doc never debited on cash-out). ✅
- Reuse existing backend/collections → all tasks build on `wallets`/`users`, add only `cities`. ✅

**Deferred to later plans (not gaps):** Flame engine (Plan 2), HUD/build UI + retiring Prize Machine from nav (Plan 3), AI art spec + sprites (Plan 4). The "bonus XP from some chores" is intentionally omitted from MVP (the spec marks it optional); add later by crediting a small `points` amount in `_writeEarn` if desired.

**Placeholder scan:** none — every step has concrete code and exact commands.

**Type consistency:** `buildingTypeById`, `tokenCostForLevel`/`xpRewardForLevel`/`valueAtLevel`, `City.fromDoc`/`isOccupied`/`indexAt`, `PlacedBuilding.copyWith`/`toMap`, `tokensFromXp`, `kStartingTokens`/`kXpToTokenRate`/`kXpToTokenDailyCap`, `initialWalletData`, `convertXpToTokens` are defined once and referenced consistently across tasks.
