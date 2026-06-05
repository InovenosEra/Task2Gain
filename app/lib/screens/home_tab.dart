import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../services/quest_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/glow_card.dart';
import '../widgets/landscape_body.dart';
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneTitle(
          title: 'משימות פתוחות',
          trailing: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppPalette.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('זמינות', style: bodyFont(size: 12, color: Colors.white60)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Quest>>(
            stream: questService.watchFamilyQuests(data.familyId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppPalette.gold));
              }
              final quests = snap.data ?? const [];
              if (quests.isEmpty) {
                return const _EmptyQuests();
              }
              return GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisExtent: 96,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: quests.length,
                itemBuilder: (context, i) => _QuestCard(
                  quest: quests[i],
                  onTap: () => context.pushFadeUp(
                    (_) => QuestDetailScreen(
                      quest: quests[i],
                      kidUid: data.uid,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    return LandscapeSection(
      strip: _WalletStrip(
        data: data,
        firestore: firestore,
        onConvert: () => context.pushFadeUp(
          (_) => ConvertPointsScreen(uid: data.uid, familyId: data.familyId),
        ),
        onTransfer: () => context.pushFadeUp(
          (_) => TransferCashCashScreen(uid: data.uid, familyId: data.familyId),
        ),
      ),
      content: content,
    );
  }
}

/// Compact full-width wallet bar for the top of the Tasks screen: a small
/// avatar + inline balance chips (points / money / tokens / streak) on the
/// right, the two quick actions on the left.
class _WalletStrip extends StatelessWidget {
  const _WalletStrip({
    required this.data,
    required this.firestore,
    required this.onConvert,
    required this.onTransfer,
  });
  final HomeData data;
  final FirebaseFirestore firestore;
  final VoidCallback onConvert;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('users').doc(data.uid).snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('wallets').doc(data.uid).snapshots(),
          builder: (context, walletSnap) {
            final user = userSnap.data?.data() ?? const {};
            final wallet = walletSnap.data?.data() ?? const {};
            final points = (wallet['points'] as num?)?.toInt() ?? 0;
            final money = (wallet['moneyILS'] as num?)?.toDouble() ?? 0.0;
            final tokens = (wallet['tokens'] as num?)?.toInt() ?? 0;
            final streakMap =
                (user['streak'] as Map?)?.cast<String, dynamic>() ?? const {};
            final streak = (streakMap['current'] as num?)?.toInt() ?? 0;

            return GlowCard(
              glowColor: AppPalette.gold,
              glowOpacity: 0.18,
              glowRadius: 22,
              borderColor: AppPalette.gold.withValues(alpha: 0.22),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF34206B),
                  Color(0xFF1A1B3A),
                  Color(0xFF3F1A55),
                ],
              ),
              child: Row(
                children: [
                  AvatarBubble(emoji: data.avatar, size: 40),
                  const SizedBox(width: 12),
                  _StatChip(
                      emoji: '⭐',
                      value: '$points',
                      tone: AppPalette.gold),
                  const SizedBox(width: 8),
                  _StatChip(
                      emoji: '💰',
                      value: '₪${money.toStringAsFixed(2)}',
                      tone: AppPalette.green),
                  const SizedBox(width: 8),
                  _StatChip(
                      emoji: '🎟️',
                      value: '$tokens',
                      tone: AppPalette.violet),
                  const SizedBox(width: 8),
                  _StatChip(
                      emoji: streak >= 3 ? '🔥' : '✨',
                      value: '$streak',
                      tone: AppPalette.pink),
                  const Spacer(),
                  _StripAction(
                      emoji: '💱',
                      label: 'המר נקודות',
                      tone: AppPalette.green,
                      onTap: onConvert),
                  const SizedBox(width: 8),
                  _StripAction(
                      emoji: '💸',
                      label: 'CashCash',
                      tone: AppPalette.sky,
                      onTap: onTransfer),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Inline balance chip: emoji + value on a tinted pill.
class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.emoji, required this.value, required this.tone});
  final String emoji;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(value, style: displayFont(size: 15, weight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// Compact action button used in the wallet strip.
class _StripAction extends StatelessWidget {
  const _StripAction(
      {required this.emoji,
      required this.label,
      required this.tone,
      required this.onTap});
  final String emoji;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(label, style: displayFont(size: 13, weight: FontWeight.w800)),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: displayFont(
                          size: 16, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _miniTag(
                            '${quest.points} ⭐', grad.first),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌟', style: TextStyle(fontSize: 64)),
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
