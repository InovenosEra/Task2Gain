import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/models/quest.dart';
import 'package:task2play/services/quest_instance_service.dart';

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

  String dayKey(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
  }

  final today = dayKey(DateTime.now());
  final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
  final threeDaysAgo =
      dayKey(DateTime.now().subtract(const Duration(days: 3)));

  test('streak continues from yesterday (4 -> 5)', () async {
    await db.collection('users').doc('kid1').set({
      'streak': {'current': 4, 'longest': 4, 'lastDate': yesterday},
    }, SetOptions(merge: true));

    await service.completeAuto(
        quest: quest(points: 30, mode: QuestApprovalMode.auto), kidUid: 'kid1');

    final streak = (await db.collection('users').doc('kid1').get())
        .data()!['streak'] as Map;
    expect(streak['current'], 5);
    expect(streak['longest'], 5);
  });

  test('streak resets after a gap (9 -> 1, longest stays 9)', () async {
    await db.collection('users').doc('kid1').set({
      'streak': {'current': 9, 'longest': 9, 'lastDate': threeDaysAgo},
    }, SetOptions(merge: true));

    await service.completeAuto(
        quest: quest(points: 30, mode: QuestApprovalMode.auto), kidUid: 'kid1');

    final streak = (await db.collection('users').doc('kid1').get())
        .data()!['streak'] as Map;
    expect(streak['current'], 1);
    expect(streak['longest'], 9);
  });

  test('already counted today: no double-count, no extra milestone token',
      () async {
    // Seed streak at day 3 (a milestone day) already counted today, and
    // earnedToday at today so points do not re-cross the daily goal.
    // tokens seeded at 0 (default setUp). Note: fake_cloud_firestore resets a
    // FieldValue.increment inside a transaction to the increment amount, so we
    // assert the awarded delta directly rather than a pre-seeded baseline.
    await db.collection('users').doc('kid1').set({
      'streak': {'current': 3, 'longest': 3, 'lastDate': today},
      'earnedToday': {'date': today, 'points': 0},
    }, SetOptions(merge: true));

    // Points below the daily goal of 50 so crossedDailyGoal is false.
    await service.completeAuto(
        quest: quest(points: 10, mode: QuestApprovalMode.auto), kidUid: 'kid1');

    final user = (await db.collection('users').doc('kid1').get()).data()!;
    final streak = user['streak'] as Map;
    expect(streak['current'], 3); // unchanged, already counted today
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 0); // no goal crossing, no milestone awarded
  });

  test('milestone token lands when streak reaches day 7 (+3 tokens)', () async {
    // Day 6 yesterday -> completing today pushes to day 7 (milestone).
    await db.collection('users').doc('kid1').set({
      'streak': {'current': 6, 'longest': 6, 'lastDate': yesterday},
    }, SetOptions(merge: true));

    // Points below the daily goal so the milestone token is isolated from the
    // daily-goal token. tokens start at 0 from setUp; the transactional
    // increment is the awarded amount (see note in the prior test).
    await service.completeAuto(
        quest: quest(points: 10, mode: QuestApprovalMode.auto), kidUid: 'kid1');

    final streak = (await db.collection('users').doc('kid1').get())
        .data()!['streak'] as Map;
    expect(streak['current'], 7);
    final wallet = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(wallet['tokens'], 3); // day-7 milestone (+3), no goal crossing
  });

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
