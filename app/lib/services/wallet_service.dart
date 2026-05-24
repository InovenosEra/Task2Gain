import 'package:cloud_firestore/cloud_firestore.dart';

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
