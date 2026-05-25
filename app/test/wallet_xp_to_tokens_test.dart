// test/wallet_xp_to_tokens_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/services/wallet_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WalletService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = WalletService(firestore: db);
    await db.collection('users').doc('kid1').set({'familyId': 'fam1'});
    await db.collection('wallets').doc('kid1').set({
      'userId': 'kid1', 'familyId': 'fam1',
      'points': 100, 'moneyILS': 0, 'tokens': 10,
      'lifetimeEarned': {'points': 100, 'money': 0},
    });
  });

  test('converts XP to tokens at the lossy rate', () async {
    final got = await service.convertXpToTokens(userUid: 'kid1', xpToSpend: 20);
    expect(got, 10); // 20 XP * 0.5 = 10 tokens
    final w = (await db.collection('wallets').doc('kid1').get()).data()!;
    expect(w['points'], 80);  // 100 - 20
    expect(w['tokens'], 20);  // 10 + 10
  });

  test('rejects more XP than the player has', () async {
    expect(
      () => service.convertXpToTokens(userUid: 'kid1', xpToSpend: 999),
      throwsA(isA<StateError>()),
    );
  });

  test('enforces the daily token cap', () async {
    // Cap is 20 tokens/day. 60 XP would yield 30 tokens — must be blocked.
    expect(
      () => service.convertXpToTokens(userUid: 'kid1', xpToSpend: 60),
      throwsA(isA<StateError>()),
    );
  });
}
