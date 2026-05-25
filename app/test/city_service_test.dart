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
