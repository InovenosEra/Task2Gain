import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import 'badges_screen.dart';
import 'main_navigation.dart';

/// Profile tab — big avatar + wallet/level summary + entry points to badges
/// and a sign-out action.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.data,
    required this.onSignOut,
  });
  final HomeData data;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppPalette.gold.withValues(alpha: 0.35),
                    AppPalette.gold.withValues(alpha: 0),
                  ]),
                ),
              ),
              AvatarBubble(emoji: data.avatar, size: 108),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            data.displayName,
            style: displayFont(size: 26, weight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            data.role == 'admin'
                ? 'הורה במשפחת ${data.familyName}'
                : 'חבר במשפחת ${data.familyName}',
            style: bodyFont(size: 13, color: Colors.white60),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                firestore.collection('users').doc(data.uid).snapshots(),
            builder: (context, userSnap) {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: firestore
                    .collection('wallets')
                    .doc(data.uid)
                    .snapshots(),
                builder: (context, walletSnap) {
                  final user = userSnap.data?.data() ?? const {};
                  final wallet = walletSnap.data?.data() ?? const {};
                  final streakMap = (user['streak'] as Map?)
                          ?.cast<String, dynamic>() ??
                      const {};
                  final streakDays =
                      (streakMap['current'] as num?)?.toInt() ?? 0;
                  final streakLongest =
                      (streakMap['longest'] as num?)?.toInt() ?? 0;
                  final questsDone =
                      (user['questsCompleted'] as num?)?.toInt() ?? 0;
                  final points =
                      (wallet['points'] as num?)?.toInt() ?? 0;
                  final money =
                      (wallet['moneyILS'] as num?)?.toDouble() ?? 0.0;
                  final lifetimePoints = ((wallet['lifetimeEarned']
                              as Map?)?['points'] as num?)
                          ?.toInt() ??
                      0;
                  return Column(
                    children: [
                      _StatGrid(stats: [
                        _Stat('⭐', '$points', 'נקודות', AppPalette.gold),
                        _Stat('💰', '₪${money.toStringAsFixed(2)}', 'כסף',
                            AppPalette.green),
                        _Stat('🔥', '$streakDays', 'רצף', AppPalette.pink),
                        _Stat('🏆', '$questsDone', 'משימות',
                            AppPalette.violet),
                      ]),
                      const SizedBox(height: 14),
                      _LifetimeStrip(
                          longest: streakLongest, lifetime: lifetimePoints),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _ProfileLink(
                emoji: '🏅',
                label: 'ההישגים שלי',
                onTap: () => context
                    .pushFadeUp((_) => BadgesScreen(uid: data.uid)),
              ),
              const SizedBox(height: 10),
              _ProfileLink(
                emoji: '🚪',
                label: 'התנתק',
                tone: AppPalette.pink,
                onTap: onSignOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _LifetimeStrip extends StatelessWidget {
  const _LifetimeStrip({required this.longest, required this.lifetime});
  final int longest;
  final int lifetime;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('רצף שיא: $longest 🔥',
              style: bodyFont(size: 12, color: Colors.white70)),
          Text('סה״כ הרווחת: $lifetime ⭐',
              style: bodyFont(size: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.emoji, this.value, this.label, this.tone);
  final String emoji;
  final String value;
  final String label;
  final Color tone;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: s.tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: s.tone.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.value,
                            style: displayFont(
                                size: 18,
                                weight: FontWeight.w900,
                                height: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.label,
                            style: bodyFont(
                                size: 11, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.tone = AppPalette.gold,
  });
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: displayFont(size: 16, weight: FontWeight.w800),
              ),
            ),
            Icon(Icons.chevron_left,
                color: Colors.white.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
