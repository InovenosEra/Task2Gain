import 'package:cloud_firestore/cloud_firestore.dart';
import '../game/economy_config.dart';

class WalletService {
  WalletService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Converts the requested number of points into ILS at the family's
  /// configured `pointToShekelRate`. Returns the ILS credited. Runs inside a
  /// transaction so the points debit and money credit happen atomically.
  Future<double> convertPoints({
    required String userUid,
    required int pointsToConvert,
  }) async {
    if (pointsToConvert <= 0) {
      throw StateError('יש להמיר מספר חיובי של נקודות');
    }
    final walletRef = _firestore.collection('wallets').doc(userUid);
    final userRef = _firestore.collection('users').doc(userUid);

    final result = await _firestore.runTransaction<double>((tx) async {
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) {
        throw StateError('ארנק לא נמצא');
      }
      final wallet = walletSnap.data()!;
      final currentPoints = (wallet['points'] as num?)?.toInt() ?? 0;
      final currentMoney = (wallet['moneyILS'] as num?)?.toDouble() ?? 0.0;
      final lifetime = (wallet['lifetimeEarned'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{'points': 0, 'money': 0};

      final userSnap = await tx.get(userRef);
      final familyId = userSnap.data()?['familyId'] as String?;
      if (familyId == null) throw StateError('משתמש בלי משפחה');

      final familySnap =
          await tx.get(_firestore.collection('families').doc(familyId));
      final settings = (familySnap.data()?['settings'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final rate = (settings['pointToShekelRate'] as num?)?.toDouble() ?? 0.01;
      final minPoints =
          (settings['minPointsToConvert'] as num?)?.toInt() ?? 100;

      if (currentPoints < minPoints) {
        throw StateError('מינימום $minPoints נקודות להמרה');
      }
      if (pointsToConvert > currentPoints) {
        throw StateError('אין מספיק נקודות');
      }

      final shekels = pointsToConvert * rate;
      final newMoney = currentMoney + shekels;
      final newLifetimeMoney =
          ((lifetime['money'] as num?)?.toDouble() ?? 0.0) + shekels;

      tx.update(walletRef, {
        'points': FieldValue.increment(-pointsToConvert),
        'moneyILS': newMoney,
        'lifetimeEarned': {
          'points': (lifetime['points'] as num?)?.toInt() ?? 0,
          'money': newLifetimeMoney,
          'tokens': (lifetime['tokens'] as num?)?.toInt() ?? 0,
        },
      });

      tx.set(_firestore.collection('transactions').doc(), {
        'userId': userUid,
        'familyId': familyId,
        'type': 'convert',
        'status': 'completed',
        'pointsConverted': pointsToConvert,
        'amount': shekels,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return shekels;
    });
    return result;
  }

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

  /// Kid requests a CashCash transfer (or any external money transfer). Parent
  /// approves manually — `completeTransfer` debits the wallet.
  Future<String> requestTransfer({
    required String userUid,
    required String familyId,
    required double amountILS,
    String channel = 'cashcash',
  }) async {
    if (amountILS <= 0) throw StateError('סכום חיובי בלבד');
    final walletSnap =
        await _firestore.collection('wallets').doc(userUid).get();
    final money = (walletSnap.data()?['moneyILS'] as num?)?.toDouble() ?? 0.0;
    if (money < amountILS) throw StateError('אין מספיק כסף בארנק');

    final ref = await _firestore.collection('transactions').add({
      'userId': userUid,
      'familyId': familyId,
      'type': 'transfer-out',
      'status': 'pending_approval',
      'channel': channel,
      'amount': amountILS,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Parent confirms they performed the external transfer; debit the wallet
  /// and mark transaction completed.
  Future<void> completeTransfer({
    required String transactionId,
    required String adminUid,
  }) async {
    final txRef = _firestore.collection('transactions').doc(transactionId);
    await _firestore.runTransaction((tx) async {
      final txSnap = await tx.get(txRef);
      if (!txSnap.exists) throw StateError('Transaction missing');
      final data = txSnap.data()!;
      if (data['status'] != 'pending_approval') {
        throw StateError('כבר טופל');
      }
      final userUid = data['userId'] as String;
      final amount = (data['amount'] as num).toDouble();
      final walletRef = _firestore.collection('wallets').doc(userUid);
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');
      final money =
          (walletSnap.data()!['moneyILS'] as num?)?.toDouble() ?? 0.0;
      if (money < amount) throw StateError('אין מספיק כסף בארנק');

      tx.update(walletRef, {'moneyILS': money - amount});
      tx.update(txRef, {
        'status': 'completed',
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectTransfer({
    required String transactionId,
    required String adminUid,
    String? reason,
  }) {
    return _firestore.collection('transactions').doc(transactionId).update({
      'status': 'rejected',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }

  Stream<List<PendingTransfer>> watchPendingTransfers(String familyId) {
    return _firestore
        .collection('transactions')
        .where('familyId', isEqualTo: familyId)
        .where('type', isEqualTo: 'transfer-out')
        .where('status', isEqualTo: 'pending_approval')
        .snapshots()
        .map((snap) => snap.docs.map(PendingTransfer.fromDoc).toList());
  }

  Future<void> setGoal({
    required String userUid,
    required String rewardId,
  }) {
    return _firestore
        .collection('users')
        .doc(userUid)
        .collection('rewardTargets')
        .doc('current')
        .set({
      'rewardId': rewardId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearGoal(String userUid) {
    return _firestore
        .collection('users')
        .doc(userUid)
        .collection('rewardTargets')
        .doc('current')
        .delete();
  }

  Stream<String?> watchGoal(String userUid) {
    return _firestore
        .collection('users')
        .doc(userUid)
        .collection('rewardTargets')
        .doc('current')
        .snapshots()
        .map((s) => s.data()?['rewardId'] as String?);
  }
}

class PendingTransfer {
  const PendingTransfer({
    required this.id,
    required this.userUid,
    required this.amount,
    required this.channel,
    required this.createdAt,
  });

  final String id;
  final String userUid;
  final double amount;
  final String channel;
  final DateTime? createdAt;

  factory PendingTransfer.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PendingTransfer(
      id: doc.id,
      userUid: (d['userId'] as String?) ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      channel: (d['channel'] as String?) ?? 'cashcash',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
