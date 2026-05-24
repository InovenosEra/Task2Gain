import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/badge.dart';
import '../models/quest.dart';
import '../models/quest_instance.dart';
import 'daily_goal.dart';

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

  /// Auto-approved (honor-system) completion: creates an instance already
  /// approved and credits the reward in one transaction. No parent step.
  Future<String> completeAuto({
    required Quest quest,
    required String kidUid,
  }) async {
    final ref = _coll.doc();
    await _firestore.runTransaction((tx) async {
      // All reads must precede writes in a Firestore transaction.
      final earn = await _readEarnState(tx, uid: kidUid);
      tx.set(ref, {
        'questId': quest.id,
        'familyId': quest.familyId,
        'assignedTo': kidUid,
        'status': QuestInstanceStatus.approved.serialized,
        'title': quest.title,
        'icon': quest.icon,
        'points': quest.points,
        'startedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': kidUid,
        'pointsAwarded': quest.points,
        'comboMultiplier': 1.0,
      });
      _writeEarn(tx, uid: kidUid, points: quest.points, earn: earn,
          instanceRef: ref);
    });
    return ref.id;
  }

  /// Approves a submitted instance and credits points + tokens + streak +
  /// badges atomically. Writes no xp/level.
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
      final earn = await _readEarnState(tx, uid: assignedTo);
      tx.update(instanceRef, {
        'status': QuestInstanceStatus.approved.serialized,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'pointsAwarded': points,
        'comboMultiplier': 1.0,
      });
      _writeEarn(tx, uid: assignedTo, points: points, earn: earn,
          instanceRef: instanceRef);
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

  /// Snapshot of everything the earn-credit needs, read before any write.
  Future<_EarnState> _readEarnState(
      Transaction tx, {required String uid}) async {
    final walletRef = _firestore.collection('wallets').doc(uid);
    final userRef = _firestore.collection('users').doc(uid);
    final walletSnap = await tx.get(walletRef);
    final userSnap = await tx.get(userRef);
    return _EarnState(
      walletRef: walletRef,
      userRef: userRef,
      wallet: walletSnap.data() ?? <String, dynamic>{},
      user: userSnap.data() ?? <String, dynamic>{},
    );
  }

  void _writeEarn(
    Transaction tx, {
    required String uid,
    required int points,
    required _EarnState earn,
    required DocumentReference<Map<String, dynamic>> instanceRef,
  }) {
    final wallet = earn.wallet;
    final user = earn.user;
    final now = DateTime.now().toUtc();
    final today = _dayKey(now);
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

    // Lifetime points.
    final lifetime =
        (wallet['lifetimeEarned'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{'points': 0, 'money': 0};
    final newLifetimePoints =
        ((lifetime['points'] as num?)?.toInt() ?? 0) + points;

    // Streak.
    final streakMap =
        (user['streak'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lastDateStr = streakMap['lastDate'] as String?;
    var streakCurrent = (streakMap['current'] as num?)?.toInt() ?? 0;
    var streakLongest = (streakMap['longest'] as num?)?.toInt() ?? 0;
    final streakAlreadyCountedToday = lastDateStr == today;
    if (streakAlreadyCountedToday) {
      // no change
    } else if (lastDateStr == yesterday) {
      streakCurrent += 1;
    } else {
      streakCurrent = 1;
    }
    if (streakCurrent > streakLongest) streakLongest = streakCurrent;

    // Today's running earnings (resets when the date rolls over).
    final earnedMap =
        (user['earnedToday'] as Map?)?.cast<String, dynamic>() ?? const {};
    final earnedDate = earnedMap['date'] as String?;
    final earnedBefore =
        earnedDate == today ? (earnedMap['points'] as num?)?.toInt() ?? 0 : 0;
    final goal = (user['dailyGoal'] as num?)?.toInt() ?? 50;

    // Tokens: daily-goal crossing + streak milestone (only on a fresh streak day).
    var tokensEarned = 0;
    if (crossedDailyGoal(
        earnedToday: earnedBefore, justEarned: points, goal: goal)) {
      tokensEarned += 1;
    }
    if (!streakAlreadyCountedToday) {
      tokensEarned += streakMilestoneTokens(streakCurrent);
    }

    // Badges.
    final questsCompleted =
        ((user['questsCompleted'] as num?)?.toInt() ?? 0) + 1;
    final existingBadges =
        (user['badges'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    final existingBadgeIds = existingBadges
        .map((b) => (b is Map ? b['id'] as String? : null) ?? '')
        .toSet();
    final metrics = BadgeMetrics(
      lifetimePoints: newLifetimePoints,
      currentStreak: streakCurrent,
      longestStreak: streakLongest,
      questsCompleted: questsCompleted,
    );
    final newlyUnlocked = badgeCatalog
        .where((b) => !existingBadgeIds.contains(b.id) && b.unlocked(metrics))
        .map((b) => {
              'id': b.id,
              'earnedAt': now.toIso8601String(),
            })
        .toList();
    final updatedBadges = [...existingBadges, ...newlyUnlocked];

    tx.set(earn.walletRef, {
      'points': FieldValue.increment(points),
      'tokens': FieldValue.increment(tokensEarned),
      'lifetimeEarned': {
        'points': newLifetimePoints,
        'money': (lifetime['money'] as num?)?.toInt() ?? 0,
      },
    }, SetOptions(merge: true));

    tx.set(earn.userRef, {
      'streak': {
        'current': streakCurrent,
        'longest': streakLongest,
        'lastDate': today,
      },
      'earnedToday': {'date': today, 'points': earnedBefore + points},
      'questsCompleted': questsCompleted,
      'badges': updatedBadges,
    }, SetOptions(merge: true));

    tx.update(instanceRef, {'tokensAwarded': tokensEarned});
  }

  /// UTC date key in `YYYY-MM-DD` form for the given (already-UTC) time.
  static String _dayKey(DateTime utc) {
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
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

class _EarnState {
  _EarnState({
    required this.walletRef,
    required this.userRef,
    required this.wallet,
    required this.user,
  });
  final DocumentReference<Map<String, dynamic>> walletRef;
  final DocumentReference<Map<String, dynamic>> userRef;
  final Map<String, dynamic> wallet;
  final Map<String, dynamic> user;
}
