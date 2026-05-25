import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/services/wallet_service.dart';

void main() {
  test('convertPoints preserves lifetimeEarned.tokens', () async {
    final db = FakeFirebaseFirestore();
    final service = WalletService(firestore: db);
    await db.collection('families').doc('fam1').set({
      'settings': {'pointToShekelRate': 0.01, 'minPointsToConvert': 100},
    });
    await db.collection('users').doc('kid1').set({'familyId': 'fam1'});
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1', 'familyId': 'fam1',
      'points': 200, 'moneyILS': 0, 'tokens': 9,
      'lifetimeEarned': {'points': 200, 'money': 0, 'tokens': 42},
    });

    await service.convertPoints(userUid: 'kid1', pointsToConvert: 100);

    final life = (await db.collection('wallets').doc('kid1').get())
        .data()!['lifetimeEarned'] as Map;
    expect(life['tokens'], 42); // preserved, not wiped
  });
}
