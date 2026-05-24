import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationService {
  InvitationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _rand = Random.secure();

  /// Creates a pending 6-digit invite for the given family. Retries on
  /// collisions. Returns the code.
  Future<String> createInvite({
    required String familyId,
    required String createdBy,
    String role = 'kid',
    Duration validFor = const Duration(days: 14),
  }) async {
    final expiresAt =
        Timestamp.fromDate(DateTime.now().toUtc().add(validFor));
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateCode();
      final ref = _firestore.collection('invitations').doc(code);
      final created = await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return false;
        tx.set(ref, {
          'code': code,
          'familyId': familyId,
          'createdBy': createdBy,
          'role': role,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt,
        });
        return true;
      });
      if (created) return code;
    }
    throw StateError('לא הצליח ליצור קוד פנוי, נסה שוב');
  }

  Stream<List<Invitation>> watchPending(String familyId) {
    return _firestore
        .collection('invitations')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(Invitation.fromDoc).toList());
  }

  String _generateCode() {
    final n = _rand.nextInt(900000) + 100000;
    return n.toString();
  }
}

class Invitation {
  const Invitation({
    required this.code,
    required this.familyId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String code;
  final String familyId;
  final String role;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory Invitation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Invitation(
      code: (d['code'] as String?) ?? doc.id,
      familyId: (d['familyId'] as String?) ?? '',
      role: (d['role'] as String?) ?? 'kid',
      status: (d['status'] as String?) ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}
