import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quest.dart';

class QuestService {
  QuestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _coll =>
      _firestore.collection('quests');

  Stream<List<Quest>> watchFamilyQuests(String familyId) {
    return _coll
        .where('familyId', isEqualTo: familyId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final quests = snap.docs.map(Quest.fromDoc).toList();
      quests.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return quests;
    });
  }

  Future<String> createQuest({
    required String familyId,
    required String createdBy,
    required String title,
    required String description,
    required String icon,
    required int points,
    required QuestDifficulty difficulty,
    required QuestProof proofRequired,
    required QuestRecurrence recurrence,
  }) async {
    final xp = _xpForDifficulty(difficulty, points);
    final ref = await _coll.add({
      'familyId': familyId,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'icon': icon,
      'points': points,
      'xpReward': xp,
      'difficulty': difficulty.serialized,
      'proofRequired': proofRequired.serialized,
      'recurrence': recurrence.serialized,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deactivate(String questId) {
    return _coll.doc(questId).update({'active': false});
  }

  Future<void> updateQuest({
    required String questId,
    required String title,
    required String description,
    required String icon,
    required int points,
    required QuestDifficulty difficulty,
    required QuestProof proofRequired,
    required QuestRecurrence recurrence,
  }) {
    final xp = _xpForDifficulty(difficulty, points);
    return _coll.doc(questId).update({
      'title': title,
      'description': description,
      'icon': icon,
      'points': points,
      'xpReward': xp,
      'difficulty': difficulty.serialized,
      'proofRequired': proofRequired.serialized,
      'recurrence': recurrence.serialized,
    });
  }

  int _xpForDifficulty(QuestDifficulty d, int points) {
    final multiplier = switch (d) {
      QuestDifficulty.easy => 1.0,
      QuestDifficulty.medium => 1.5,
      QuestDifficulty.epic => 2.5,
    };
    return (points * multiplier).round();
  }
}
