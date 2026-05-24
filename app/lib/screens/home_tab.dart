import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../services/quest_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/gradient_text.dart';
import '../widgets/glow_card.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import 'convert_points_screen.dart';
import 'main_navigation.dart';
import 'quest_detail_screen.dart';
import 'transfer_cashcash_screen.dart';

/// Home tab — wallet hero at the top, open quests below. Same view for both
/// kids and admins; an admin can also do quests.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final questService = QuestService();
    return ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _Header(data: data),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _WalletHero(uid: data.uid, firestore: firestore),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    emoji: '💱',
                    label: 'המר נקודות',
                    tone: AppPalette.green,
                    onTap: () => context.pushFadeUp(
                      (_) => ConvertPointsScreen(
                        uid: data.uid,
                        familyId: data.familyId,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    emoji: '💸',
                    label: 'CashCash',
                    tone: AppPalette.sky,
                    onTap: () => context.pushFadeUp(
                      (_) => TransferCashCashScreen(
                        uid: data.uid,
                        familyId: data.familyId,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'משימות פתוחות',
                  style: displayFont(size: 22, weight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppPalette.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'זמינות',
                  style: bodyFont(
                      size: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Quest>>(
            stream: questService.watchFamilyQuests(data.familyId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppPalette.gold)),
                );
              }
              final quests = snap.data ?? const [];
              if (quests.isEmpty) {
                return const _EmptyQuests();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    for (var i = 0; i < quests.length; i++) ...[
                      _QuestCard(
                        quest: quests[i],
                        onTap: () => context.pushFadeUp(
                          (_) => QuestDetailScreen(
                            quest: quests[i],
                            kidUid: data.uid,
                          ),
                        ),
                      ),
                      if (i < quests.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          AvatarBubble(emoji: data.avatar, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'היי, ${data.displayName}!',
                  style: displayFont(size: 22, weight: FontWeight.w900),
                ),
                Text(
                  data.familyName,
                  style: bodyFont(
                      size: 13,
                      color: AppPalette.gold,
                      weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.uid, required this.firestore});
  final String uid;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('wallets').doc(uid).snapshots(),
          builder: (context, walletSnap) {
            final user = userSnap.data?.data() ?? const {};
            final wallet = walletSnap.data?.data() ?? const {};
            final level = (user['level'] as num?)?.toInt() ?? 1;
            final xp = (user['xp'] as num?)?.toInt() ?? 0;
            final xpToNext =
                (user['xpToNextLevel'] as num?)?.toInt() ?? 100;
            final points = (wallet['points'] as num?)?.toInt() ?? 0;
            final money =
                (wallet['moneyILS'] as num?)?.toDouble() ?? 0.0;
            final streakMap = (user['streak'] as Map?)
                    ?.cast<String, dynamic>() ??
                const {};
            final streakDays =
                (streakMap['current'] as num?)?.toInt() ?? 0;
            final progress = xpToNext == 0
                ? 0.0
                : (xp / xpToNext).clamp(0.0, 1.0);

            return GlowCard(
              glowColor: AppPalette.gold,
              glowOpacity: 0.32,
              glowRadius: 32,
              borderColor: AppPalette.gold.withValues(alpha: 0.3),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF34206B),
                  Color(0xFF1A1B3A),
                  Color(0xFF3F1A55),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'בארנק שלי',
                              style: bodyFont(
                                size: 12,
                                color: Colors.white60,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedIntCounter(
                              value: points,
                              style: displayFont(
                                  size: 52,
                                  weight: FontWeight.w900,
                                  height: 1.0),
                              builder: (context, text) => GradientText(
                                text,
                                style: displayFont(
                                  size: 52,
                                  weight: FontWeight.w900,
                                  height: 1.0,
                                ),
                                colors: AppPalette.heroGrad,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Text(
                                    'נקודות ⭐',
                                    style: bodyFont(
                                      size: 13,
                                      color: Colors.white70,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '·',
                                    style: bodyFont(
                                        color: Colors.white24),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₪${money.toStringAsFixed(2)}',
                                    style: bodyFont(
                                      size: 13,
                                      color: AppPalette.gold,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _LevelBadge(level: level),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StreakFlame(days: streakDays),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'XP',
                                  style: bodyFont(
                                    size: 11,
                                    color: Colors.white54,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$xp / $xpToNext',
                                  style: bodyFont(
                                    size: 12,
                                    color: Colors.white,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _XpBar(progress: progress),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppPalette.heroGrad,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.pink.withValues(alpha: 0.4),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LV',
            style: bodyFont(
              size: 9,
              color: Colors.white.withValues(alpha: 0.8),
              weight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          Text(
            '$level',
            style: displayFont(
                size: 26, weight: FontWeight.w900, height: 1.0),
          ),
        ],
      ),
    );
  }
}

class _StreakFlame extends StatelessWidget {
  const _StreakFlame({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) {
    final hot = days >= 3;
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hot
            ? AppPalette.pink.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: hot
              ? AppPalette.pink.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: hot
            ? [
                BoxShadow(
                  color: AppPalette.pink.withValues(alpha: 0.4),
                  blurRadius: 14,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hot ? '🔥' : '✨', style: const TextStyle(fontSize: 20)),
          Text(
            '$days',
            style: displayFont(
              size: 13,
              weight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              widthFactor: progress,
              heightFactor: 1.0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppPalette.heroGrad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.emoji,
    required this.label,
    required this.tone,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: displayFont(size: 14, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onTap});
  final Quest quest;
  final VoidCallback onTap;

  List<Color> _gradientFor(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.easy:
        return AppPalette.easyGrad;
      case QuestDifficulty.medium:
        return AppPalette.mediumGrad;
      case QuestDifficulty.epic:
        return AppPalette.epicGrad;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradientFor(quest.difficulty);
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: grad.first.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.bgDeep,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad
                        .map((c) => c.withValues(alpha: 0.3))
                        .toList(),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(quest.icon,
                    style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: displayFont(
                          size: 16, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _miniTag(
                            '${quest.points} ⭐', grad.first),
                        _miniTag(
                            '${quest.xpReward} XP', grad.last),
                        _miniTag(quest.recurrence.label,
                            Colors.white.withValues(alpha: 0.45)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: grad.first, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: bodyFont(
            size: 11,
            color: Colors.white,
            weight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyQuests extends StatelessWidget {
  const _EmptyQuests();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 80),
      child: Column(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 14),
          Text(
            'אין משימות כרגע',
            textAlign: TextAlign.center,
            style: displayFont(size: 22, weight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'בקש מההורה להוסיף קווסט חדש',
            textAlign: TextAlign.center,
            style: bodyFont(size: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
