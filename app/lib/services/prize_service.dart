import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prize.dart';

class PrizeService {
  PrizeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Spends one token and credits [reward] atomically, then logs the win.
  /// Throws [StateError] if the wallet has no tokens.
  Future<void> award({
    required String uid,
    required String familyId,
    required String game,
    required PrizeReward reward,
  }) async {
    final walletRef = _firestore.collection('wallets').doc(uid);
    final winRef = _firestore.collection('prizeWins').doc();
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(walletRef);
      if (!snap.exists) throw StateError('ארנק לא נמצא');
      final wallet = snap.data()!;
      final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
      if (tokens <= 0) throw StateError('אין אסימונים');

      var tokenDelta = -1; // cost of one play
      final updates = <String, dynamic>{};
      switch (reward.type) {
        case PrizeType.points:
          updates['points'] = FieldValue.increment(reward.intValue);
          final lifetime =
              (wallet['lifetimeEarned'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{'points': 0, 'money': 0};
          updates['lifetimeEarned'] = {
            'points':
                ((lifetime['points'] as num?)?.toInt() ?? 0) + reward.intValue,
            'money': (lifetime['money'] as num?)?.toInt() ?? 0,
          };
          break;
        case PrizeType.tokens:
          tokenDelta += reward.intValue;
          break;
        case PrizeType.cosmetic:
          updates['cosmeticsOwned'] =
              FieldValue.arrayUnion([reward.value as String]);
          break;
      }
      updates['tokens'] = FieldValue.increment(tokenDelta);

      tx.set(walletRef, updates, SetOptions(merge: true));
      tx.set(winRef, {
        'userId': uid,
        'familyId': familyId,
        'game': game,
        'rewardType': reward.type.name,
        'rewardValue': reward.value,
        'rewardLabel': reward.label,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Recent wins across the family, newest first.
  Stream<List<PrizeWin>> watchRecentWins(String familyId, {int limit = 10}) {
    return _firestore
        .collection('prizeWins')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(PrizeWin.fromDoc).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list.take(limit).toList();
    });
  }
}

class PrizeWin {
  const PrizeWin({
    required this.id,
    required this.userId,
    required this.game,
    required this.rewardLabel,
    required this.createdAt,
  });
  final String id;
  final String userId;
  final String game;
  final String rewardLabel;
  final DateTime? createdAt;

  factory PrizeWin.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PrizeWin(
      id: doc.id,
      userId: (d['userId'] as String?) ?? '',
      game: (d['game'] as String?) ?? '',
      rewardLabel: (d['rewardLabel'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
