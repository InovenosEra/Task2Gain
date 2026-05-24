import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2gain/models/quest.dart';
import 'package:task2gain/services/quest_instance_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late QuestInstanceService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = QuestInstanceService(firestore: db);
    await db.collection('users').doc('kid1').set({
      'familyId': 'fam1',
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'questsCompleted': 0,
      'badges': <Map<String, dynamic>>[],
    });
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1',
      'familyId': 'fam1',
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
  });

  Quest quest({int points = 60, QuestApprovalMode mode = QuestApprovalMode.required}) =>
      Quest(
        id: 'q1',
        familyId: 'fam1',
        title: 'נקה את החדר',
        description: '',
        icon: '🧹',
        points: points,
        difficulty: QuestDifficulty.easy,
        proofRequired: QuestProof.none,
        recurrence: QuestRecurrence.once,
        approvalMode: mode,
        createdBy: 'parent1',
        active: true,
        createdAt: DateTime.now(),
      );

  test('approve credits points + lifetime, never writes xp/level', () async {
    final id = await service.startQuest(quest: quest(), kidUid: 'kid1');
    await service.submit(id);
    await service.approve(instanceId: id, adminUid: 'parent1');

    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['points'], 60);
    expect((wallet['lifetimeEarned'] as Map)['points'], 60);

    final user = (await db.collection('users').doc('kid1').get()).data()!;
    expect(user.containsKey('xp'), isFalse);
    expect(user.containsKey('level'), isFalse);
    expect(user['questsCompleted'], 1);
    expect((user['streak'] as Map)['current'], 1);
  });

  test('crossing the daily goal awards exactly one token', () async {
    final id = await service.startQuest(quest: quest(points: 60), kidUid: 'kid1');
    await service.submit(id);
    await service.approve(instanceId: id, adminUid: 'parent1');
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 1); // 60 >= goal 50, daily-goal token
  });

  test('completeAuto credits instantly without submit', () async {
    final id = await service.completeAuto(
        quest: quest(points: 30, mode: QuestApprovalMode.auto), kidUid: 'kid1');
    final inst = (await db.collection('questInstances').doc(id).get()).data()!;
    expect(inst['status'], 'approved');
    expect(inst['pointsAwarded'], 30);
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['points'], 30);
    expect(wallet['tokens'], 0); // 30 < goal 50, no daily-goal token yet
  });

  test('first quest unlocks first_quest badge, not any level badge', () async {
    final id = await service.completeAuto(
        quest: quest(mode: QuestApprovalMode.auto), kidUid: 'kid1');
    expect(id, isNotEmpty);
    final user = (await db.collection('users').doc('kid1').get()).data()!;
    final ids = (user['badges'] as List)
        .map((b) => (b as Map)['id'] as String)
        .toList();
    expect(ids, contains('first_quest'));
    expect(ids.any((s) => s.startsWith('level_')), isFalse);
  });
}
