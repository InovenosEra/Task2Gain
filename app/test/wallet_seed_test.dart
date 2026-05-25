// test/wallet_seed_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game/economy_config.dart';
import 'package:task2play/services/wallet_seed.dart';

void main() {
  test('initial wallet starts with kStartingTokens and zeroed rest', () {
    final w = initialWalletData(uid: 'u1', familyId: 'fam1');
    expect(w['tokens'], kStartingTokens);
    expect(w['points'], 0);
    expect(w['moneyILS'], 0);
    expect(w['userId'], 'u1');
    expect(w['familyId'], 'fam1');
    expect((w['lifetimeEarned'] as Map)['points'], 0);
  });
}
