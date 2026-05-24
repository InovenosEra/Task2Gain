import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Registers a parent, creates a `families/{familyId}` document, and a
  /// matching `users/{uid}` doc with role=admin. Returns the new familyId.
  Future<String> signUpParent({
    required String email,
    required String password,
    required String parentDisplayName,
    required String familyName,
    String avatar = '👤',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final familyRef = _firestore.collection('families').doc();
    final userRef = _firestore.collection('users').doc(uid);

    final batch = _firestore.batch();
    batch.set(familyRef, {
      'name': familyName,
      'createdAt': FieldValue.serverTimestamp(),
      'plan': 'free',
      'settings': {
        'minPointsToConvert': 100,
        'pointToShekelRate': 0.01,
        'leaderboardIncludesAdmins': false,
        'dailyGoalDefault': 50,
      },
    });
    batch.set(userRef, {
      'familyId': familyRef.id,
      'role': 'admin',
      'displayName': parentDisplayName,
      'avatar': {'type': 'preset', 'value': avatar},
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'badges': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('wallets').doc(uid), {
      'userId': uid,
      'familyId': familyRef.id,
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'cosmeticsOwned': <String>[],
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
    await batch.commit();

    return familyRef.id;
  }

  /// Accepts an invite code, signs up a kid (or spouse), and wires them to the
  /// existing family. Returns the familyId on success.
  Future<String> signUpWithInvite({
    required String inviteCode,
    required String email,
    required String password,
    required String displayName,
    String avatar = '🦁',
  }) async {
    final inviteRef = _firestore.collection('invitations').doc(inviteCode);
    final inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists) {
      throw StateError('קוד הזמנה לא נמצא');
    }
    final invite = inviteSnap.data()!;
    if (invite['status'] != 'pending') {
      throw StateError('הקוד הזה כבר שימש');
    }
    final familyId = invite['familyId'] as String;
    final role = (invite['role'] as String?) ?? 'kid';

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), {
      'familyId': familyId,
      'role': role,
      'displayName': displayName,
      'avatar': {'type': 'preset', 'value': avatar},
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'badges': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('wallets').doc(uid), {
      'userId': uid,
      'familyId': familyId,
      'points': 0,
      'moneyILS': 0,
      'tokens': 0,
      'cosmeticsOwned': <String>[],
      'lifetimeEarned': {'points': 0, 'money': 0},
    });
    batch.update(inviteRef, {
      'status': 'used',
      'usedBy': uid,
      'usedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return familyId;
  }

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}
