import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reward.dart';

class RewardService {
  RewardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _coll =>
      _firestore.collection('rewards');

  Stream<List<Reward>> watchFamilyRewards(String familyId) {
    return _coll
        .where('familyId', isEqualTo: familyId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Reward.fromDoc).toList();
      list.sort((a, b) => a.priceILS.compareTo(b.priceILS));
      return list;
    });
  }

  Future<String> create({
    required String familyId,
    required String createdBy,
    required String title,
    required String description,
    required String icon,
    required double priceILS,
    int? stock,
  }) async {
    final ref = await _coll.add({
      'familyId': familyId,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'icon': icon,
      'priceILS': priceILS,
      'stock': stock,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deactivate(String rewardId) {
    return _coll.doc(rewardId).update({'active': false});
  }

  /// Creates a pending purchase transaction. Parent must approve to actually
  /// debit the wallet.
  Future<String> requestPurchase({
    required Reward reward,
    required String buyerUid,
  }) async {
    final ref = await _firestore.collection('transactions').add({
      'userId': buyerUid,
      'familyId': reward.familyId,
      'type': 'purchase',
      'status': 'pending_approval',
      'rewardId': reward.id,
      'rewardTitle': reward.title,
      'rewardIcon': reward.icon,
      'amount': reward.priceILS,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Approves a pending purchase: debits the buyer's wallet, marks the
  /// transaction completed, and decrements reward stock if applicable.
  Future<void> approvePurchase({
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
      final buyerUid = data['userId'] as String;
      final amount = (data['amount'] as num).toDouble();
      final rewardId = data['rewardId'] as String?;

      final walletRef =
          _firestore.collection('wallets').doc(buyerUid);
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) throw StateError('ארנק לא נמצא');
      final wallet = walletSnap.data()!;
      final money = (wallet['moneyILS'] as num?)?.toDouble() ?? 0.0;
      if (money < amount) {
        throw StateError('אין מספיק כסף בארנק');
      }

      tx.update(walletRef, {
        'moneyILS': money - amount,
      });

      if (rewardId != null) {
        final rewardRef = _coll.doc(rewardId);
        final rewardSnap = await tx.get(rewardRef);
        if (rewardSnap.exists) {
          final r = rewardSnap.data()!;
          final stock = r['stock'];
          if (stock is num) {
            final newStock = stock.toInt() - 1;
            tx.update(rewardRef, {
              'stock': newStock,
              if (newStock <= 0) 'active': false,
            });
          }
        }
      }

      tx.update(txRef, {
        'status': 'completed',
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectPurchase({
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

  Stream<List<PendingPurchase>> watchPendingPurchases(String familyId) {
    return _firestore
        .collection('transactions')
        .where('familyId', isEqualTo: familyId)
        .where('type', isEqualTo: 'purchase')
        .where('status', isEqualTo: 'pending_approval')
        .snapshots()
        .map((snap) => snap.docs.map(PendingPurchase.fromDoc).toList());
  }
}

class PendingPurchase {
  const PendingPurchase({
    required this.id,
    required this.buyerUid,
    required this.rewardTitle,
    required this.rewardIcon,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String buyerUid;
  final String rewardTitle;
  final String rewardIcon;
  final double amount;
  final DateTime? createdAt;

  factory PendingPurchase.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PendingPurchase(
      id: doc.id,
      buyerUid: (d['userId'] as String?) ?? '',
      rewardTitle: (d['rewardTitle'] as String?) ?? '',
      rewardIcon: (d['rewardIcon'] as String?) ?? '🎁',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
