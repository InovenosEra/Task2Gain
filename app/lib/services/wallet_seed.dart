// lib/services/wallet_seed.dart
import '../game/economy_config.dart';

/// The Firestore document a brand-new player's wallet starts with.
/// Players begin with [kStartingTokens] tokens so the game is fun before
/// any chore is required.
Map<String, dynamic> initialWalletData({
  required String uid,
  required String familyId,
}) {
  return {
    'userId': uid,
    'familyId': familyId,
    'points': 0,
    'moneyILS': 0,
    'tokens': kStartingTokens,
    'cosmeticsOwned': <String>[],
    'lifetimeEarned': {'points': 0, 'money': 0, 'tokens': 0},
  };
}
