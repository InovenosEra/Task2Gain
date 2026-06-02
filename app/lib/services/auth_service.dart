import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'photo_upload_service.dart';
import 'wallet_seed.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PhotoUploadService? photos,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _photos = photos ?? PhotoUploadService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final PhotoUploadService _photos;

  /// Builds the stored `avatar` map. With a picked [file] it uploads to
  /// Storage (as the just-created [uid]) and stores the URL; if that fails it
  /// falls back to the [emoji] preset so signup is never blocked by an avatar.
  Future<Map<String, dynamic>> _avatarData({
    required String uid,
    required String emoji,
    File? file,
  }) async {
    if (file == null) return {'type': 'preset', 'value': emoji};
    try {
      final url = await _photos.uploadAvatar(uid: uid, file: file);
      return {'type': 'photo', 'value': url};
    } catch (_) {
      return {'type': 'preset', 'value': emoji};
    }
  }

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
    File? avatarFile,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final avatarData =
        await _avatarData(uid: uid, emoji: avatar, file: avatarFile);

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
      'avatar': avatarData,
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'badges': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('wallets').doc(uid),
        initialWalletData(uid: uid, familyId: familyRef.id));
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
    File? avatarFile,
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
    final avatarData =
        await _avatarData(uid: uid, emoji: avatar, file: avatarFile);

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), {
      'familyId': familyId,
      'role': role,
      'displayName': displayName,
      'avatar': avatarData,
      'dailyGoal': 50,
      'streak': {'current': 0, 'longest': 0, 'lastDate': null},
      'badges': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('wallets').doc(uid),
        initialWalletData(uid: uid, familyId: familyId));
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
