// test/city_service_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game/economy_config.dart';
import 'package:task2play/models/city.dart';
import 'package:task2play/services/city_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CityService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    // rng >= kSurpriseChance => never trigger a surprise, so the exact
    // token/XP assertions below are deterministic.
    service = CityService(firestore: db, rng: () => 1.0);
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1', 'familyId': 'fam1',
      'points': 0, 'moneyILS': 0, 'tokens': 100,
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
  });

  test('surprise bonus credits extra tokens when the roll hits', () async {
    // rng < kSurpriseChance => always trigger a +kSurpriseBonusTokens surprise.
    final lucky = CityService(firestore: db, rng: () => 0.0);
    final result =
        await lucky.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);

    expect(result.hasBonus, isTrue);
    expect(result.bonusTokens, 5);
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 95); // 100 - 10 cost + 5 surprise
    expect((w['lifetimeEarned'] as Map)['tokens'], 5);
  });

  test('upgrade surprise bonus credits extra tokens when the roll hits',
      () async {
    // place with no surprise (rng 1.0): tokens 90
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    final lucky = CityService(firestore: db, rng: () => 0.0);
    final result = await lucky.upgradeBuilding(uid: 'kid1', gridX: 0, gridY: 0);

    expect(result.bonusTokens, 5);
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 75); // 90 - 20 upgrade cost + 5 surprise
    expect((w['lifetimeEarned'] as Map)['tokens'], 5);
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

  test('place/upgrade/remove throw when the wallet is missing', () async {
    // 'ghost' has no wallet doc — each op checks wallet existence.
    expect(
      () => service.placeBuilding(
          uid: 'ghost', typeId: 'house', gridX: 0, gridY: 0),
      throwsA(isA<StateError>()),
    );
    expect(
      () => service.upgradeBuilding(uid: 'ghost', gridX: 0, gridY: 0),
      throwsA(isA<StateError>()),
    );
    expect(
      () => service.removeBuilding(uid: 'ghost', gridX: 0, gridY: 0),
      throwsA(isA<StateError>()),
    );
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

  test('removeBuilding deletes it and refunds half its value', () async {
    await service.placeBuilding(
        uid: 'kid1', typeId: 'shop', gridX: 1, gridY: 1); // cost 20 -> tokens 80
    await service.upgradeBuilding(
        uid: 'kid1', gridX: 1, gridY: 1); // to lvl2, cost 40 -> tokens 40

    // shop value at level 2 = baseTokenCost(20) * 2 = 40; refund = 20.
    final refund =
        await service.removeBuilding(uid: 'kid1', gridX: 1, gridY: 1);
    expect(refund, 20);

    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 60); // 40 + 20 refund
    final c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.isOccupied(1, 1), isFalse);
  });

  test('removeBuilding throws when no building at cell', () async {
    expect(
      () => service.removeBuilding(uid: 'kid1', gridX: 7, gridY: 7),
      throwsA(isA<StateError>()),
    );
  });

  test('moveBuilding relocates a building, free of charge', () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    await service.upgradeBuilding(uid: 'kid1', gridX: 0, gridY: 0); // lvl 2
    final before = (await db.collection('wallets').doc('kid1').get())
        .data()!['tokens'];

    await service.moveBuilding(
        uid: 'kid1', fromX: 0, fromY: 0, toX: 3, toY: 4);

    final c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.isOccupied(0, 0), isFalse);
    expect(c.isOccupied(3, 4), isTrue);
    expect(c.buildings.single.level, 2); // level preserved
    expect(c.buildings.single.typeId, 'house');
    final after = (await db.collection('wallets').doc('kid1').get())
        .data()!['tokens'];
    expect(after, before); // free
  });

  test('moveBuilding to the same cell is a harmless no-op', () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 2, gridY: 2);
    await service.moveBuilding(
        uid: 'kid1', fromX: 2, fromY: 2, toX: 2, toY: 2);
    final c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.isOccupied(2, 2), isTrue);
    expect(c.buildings.length, 1);
  });

  test('removeBuilding of a level-1 building refunds half its base value',
      () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    final refund =
        await service.removeBuilding(uid: 'kid1', gridX: 0, gridY: 0);
    expect(refund, 5); // house value at level 1 = 10, refund = 5
  });

  test('moveBuilding throws if destination occupied', () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    await service.placeBuilding(uid: 'kid1', typeId: 'park', gridX: 1, gridY: 0);
    expect(
      () => service.moveBuilding(
          uid: 'kid1', fromX: 0, fromY: 0, toX: 1, toY: 0),
      throwsA(isA<StateError>()),
    );
  });

  test('full lifecycle keeps wallet + city consistent', () async {
    // place house: -10 tokens (->90), +8 xp
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);
    // upgrade to lvl2: -20 (->70), +16 xp (->24)
    await service.upgradeBuilding(uid: 'kid1', gridX: 0, gridY: 0);
    // move: free
    await service.moveBuilding(uid: 'kid1', fromX: 0, fromY: 0, toX: 3, toY: 3);
    // remove lvl2 house (value 20): refund 10 (->80)
    final refund = await service.removeBuilding(uid: 'kid1', gridX: 3, gridY: 3);
    expect(refund, 10);

    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['tokens'], 80);
    expect(w['points'], 24);
    final c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.buildings, isEmpty);
  });

  test('renameCity stores a trimmed, capped name without touching buildings',
      () async {
    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0);

    await service.renameCity('kid1', '  סאניוויל  ');
    var c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.name, 'סאניוויל');
    expect(c.buildings.length, 1); // merge preserved the building

    // Caps to 24 chars.
    await service.renameCity('kid1', 'א' * 40);
    c = City.fromDoc(
        'kid1', (await db.collection('cities').doc('kid1').get()).data());
    expect(c.name.length, 24);
  });

  test('claimDailyReward grants once per day, then is unavailable', () async {
    var day = DateTime(2026, 5, 26, 9);
    final svc = CityService(firestore: db, rng: () => 1.0, clock: () => day);

    expect(await svc.isDailyRewardAvailable('kid1'), isTrue);
    final first = await svc.claimDailyReward('kid1');
    expect(first, kDailyRewardTokens);
    expect(
        (await db.collection('wallets').doc('kid1').get()).data()!['tokens'],
        100 + kDailyRewardTokens);

    // Same day: unavailable, no further grant.
    expect(await svc.isDailyRewardAvailable('kid1'), isFalse);
    expect(await svc.claimDailyReward('kid1'), 0);
    expect(
        (await db.collection('wallets').doc('kid1').get()).data()!['tokens'],
        100 + kDailyRewardTokens);

    // Next day: available again.
    day = DateTime(2026, 5, 27, 9);
    expect(await svc.isDailyRewardAvailable('kid1'), isTrue);
    expect(await svc.claimDailyReward('kid1'), kDailyRewardTokens);
    expect(
        (await db.collection('wallets').doc('kid1').get()).data()!['tokens'],
        100 + 2 * kDailyRewardTokens);
  });

  test('placeBuilding preserves lifetimeEarned.tokens', () async {
    await db.collection('wallets').doc('kid1').set({
      'lifetimeEarned': {'points': 5, 'money': 0, 'tokens': 7},
    }, SetOptions(merge: true));

    await service.placeBuilding(uid: 'kid1', typeId: 'house', gridX: 0, gridY: 0); // xp 8

    final life = (await db.collection('wallets').doc('kid1').get())
        .data()!['lifetimeEarned'] as Map;
    expect(life['points'], 13); // 5 + 8
    expect(life['tokens'], 7);  // preserved, not wiped
  });
}
