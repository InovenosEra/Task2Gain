import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class PhotoUploadService {
  PhotoUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads [file] under `quest-proofs/{familyId}/{instanceId}/{name}.jpg`
  /// and returns its download URL.
  Future<String> uploadProof({
    required String familyId,
    required String instanceId,
    required String name,
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child('quest-proofs')
        .child(familyId)
        .child(instanceId)
        .child('$name.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
