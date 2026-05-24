import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/badge.dart';
import '../models/quest.dart';
import '../models/quest_instance.dart';

class QuestInstanceService {
  QuestInstanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _coll =>
      _firestore.collection('questInstances');

  /// Kid starts a quest — creates an instance in_progress.
  Future<String> startQuest({
    required Quest quest,
    required String kidUid,
  }) async {
    final ref = await _coll.add({
      'questId': quest.id,
      'familyId': quest.familyId,
      'assignedTo': kidUid,
      'status': QuestInstanceStatus.inProgress.serialized,
      'title': quest.title,
      'icon': quest.icon,
      'points': quest.points,
      'xpReward': quest.xpReward,
      'startedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> submit(String instanceId, {List<String>? proofPhotos}) {
    return _coll.doc(instanceId).update({
      'status': QuestInstanceStatus.submitted.serialized,
      'submittedAt': FieldValue.serverTimestamp(),
      if (proofPhotos != null && proofPhotos.isNotEmpty)
        'proofPhotos': proofPhotos,
    });
  }

  /// Approves a submission and credits points + XP. Runs as a Firestore
  /// transaction so the wallet/user increments and the instance status flip
  /// happen atomically.
  Future<void> approve({
    required String instanceId,
    required String adminUid,
  }) async {
    final instanceRef = _coll.doc(instanceId);
    await _firestore.runTransaction((tx) async {
      final instanceSnap = await tx.get(instanceRef);
      if (!instanceSnap.exists) throw StateError('Instance missing');
      final data = instanceSnap.data()!;
      if (data['status'] != QuestInstanceStatus.submitted.serialized) {
        throw StateError('Instance is not awaiting approval');
      }
      final assignedTo = data['assignedTo'] as String;
      final points = (data['points'] as num?)?.toInt() ?? 0;
      final xp = (data['xpReward'] as num?)?.toInt() ?? 0;

      final walletRef = _firestore.collection('wallets').doc(assignedTo);
      final userRef = _firestore.collection('users').doc(assignedTo);
      final walletSnap = await tx.get(walletRef);
      final userSnap = await tx.get(userRef);

      final wallet = walletSnap.data() ?? <String, dynamic>{};
      final lifetime = (wallet['lifetimeEarned'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{'points': 0, 'money': 0};
      final newLifetimePoints =
          ((lifetime['points'] as num?)?.toInt() ?? 0) + points;

      tx.set(walletRef, {
        'points': FieldValue.increment(points),
        'lifetimeEarned': {
          'points': newLifetimePoints,
          'money': (lifetime['money'] as num?)?.toInt() ?? 0,
        },
      }, SetOptions(merge: true));

      final user = userSnap.data() ?? <String, dynamic>{};
      final currentXp = (user['xp'] as num?)?.toInt() ?? 0;
      final currentLevel = (user['level'] as num?)?.toInt() ?? 1;
      final xpToNext = (user['xpToNextLevel'] as num?)?.toInt() ?? 100;
      final newXp = currentXp + xp;

      var levelAfter = currentLevel;
      var xpAfter = newXp;
      var xpThreshold = xpToNext;
      while (xpAfter >= xpThreshold) {
        xpAfter -= xpThreshold;
        levelAfter += 1;
        xpThreshold = (xpThreshold * 1.4).round();
      }

      final streakMap = (user['streak'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final lastDateStr = streakMap['lastDate'] as String?;
      final today = _todayUtcKey();
      final yesterday = _yesterdayUtcKey();
      var streakCurrent = (streakMap['current'] as num?)?.toInt() ?? 0;
      var streakLongest = (streakMap['longest'] as num?)?.toInt() ?? 0;
      if (lastDateStr == today) {
        // already counted today
      } else if (lastDateStr == yesterday) {
        streakCurrent += 1;
      } else {
        streakCurrent = 1;
      }
      if (streakCurrent > streakLongest) streakLongest = streakCurrent;

      final questsCompleted =
          ((user['questsCompleted'] as num?)?.toInt() ?? 0) + 1;
      final existingBadges = (user['badges'] as List?)?.cast<dynamic>() ??
          const <dynamic>[];
      final existingBadgeIds = existingBadges
          .map((b) => (b is Map ? b['id'] as String? : null) ?? '')
          .toSet();
      final metrics = BadgeMetrics(
        level: levelAfter,
        lifetimePoints: newLifetimePoints,
        currentStreak: streakCurrent,
        longestStreak: streakLongest,
        questsCompleted: questsCompleted,
      );
      final newlyUnlocked = badgeCatalog
          .where((b) =>
              !existingBadgeIds.contains(b.id) && b.unlocked(metrics))
          .map((b) => {
                'id': b.id,
                'earnedAt': DateTime.now().toUtc().toIso8601String(),
              })
          .toList();
      final updatedBadges = [...existingBadges, ...newlyUnlocked];

      tx.update(userRef, {
        'xp': xpAfter,
        'level': levelAfter,
        'xpToNextLevel': xpThreshold,
        'streak': {
          'current': streakCurrent,
          'longest': streakLongest,
          'lastDate': today,
        },
        'questsCompleted': questsCompleted,
        'badges': updatedBadges,
      });

      tx.update(instanceRef, {
        'status': QuestInstanceStatus.approved.serialized,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'pointsAwarded': points,
        'xpAwarded': xp,
      });
    });
  }

  Future<void> reject({
    required String instanceId,
    required String adminUid,
    String? reason,
  }) {
    return _coll.doc(instanceId).update({
      'status': QuestInstanceStatus.rejected.serialized,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }

  static String _todayUtcKey() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayUtcKey() {
    final y = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  Stream<List<QuestInstance>> watchMine(String kidUid) {
    return _coll
        .where('assignedTo', isEqualTo: kidUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(QuestInstance.fromDoc).toList();
      list.sort((a, b) {
        // newest first by submittedAt fallback to approvedAt
        DateTime ad = a.submittedAt ?? a.approvedAt ?? DateTime(0);
        DateTime bd = b.submittedAt ?? b.approvedAt ?? DateTime(0);
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  Stream<List<QuestInstance>> watchPendingApprovals(String familyId) {
    return _coll
        .where('familyId', isEqualTo: familyId)
        .where('status',
            isEqualTo: QuestInstanceStatus.submitted.serialized)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(QuestInstance.fromDoc).toList();
      list.sort((a, b) =>
          (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    });
  }
}
