import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../models/quest_instance.dart';
import '../models/reward.dart';
import '../services/quest_instance_service.dart';
import '../services/quest_service.dart';
import '../services/reward_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import 'approvals_screen.dart';
import 'create_quest_screen.dart';
import 'invite_member_screen.dart';
import 'manage_rewards_screen.dart';

/// Admin tab — entry points to family management: approvals (with live count),
/// quest CRUD list, reward management, invite. Owns the lists so admin can
/// edit/delete in place.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) {
    final questService = QuestService();
    final instanceService = QuestInstanceService();
    final rewardService = RewardService();
    final walletService = WalletService();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
          child: Text(
            'ניהול ⚙️',
            style: displayFont(size: 26, weight: FontWeight.w900),
          ),
        ),
        // Quick links
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _PendingCard(
                familyId: familyId,
                instanceService: instanceService,
                rewardService: rewardService,
                walletService: walletService,
                onTap: () => context.pushFadeUp(
                  (_) => ApprovalsScreen(familyId: familyId),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AdminLink(
                      emoji: '👨‍👩‍👧',
                      label: 'הזמן בן משפחה',
                      tone: AppPalette.green,
                      onTap: () => context.pushFadeUp(
                        (_) => InviteMemberScreen(familyId: familyId),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AdminLink(
                      emoji: '🎁',
                      label: 'ניהול פרסים',
                      tone: AppPalette.gold,
                      onTap: () => context.pushFadeUp(
                        (_) => ManageRewardsScreen(familyId: familyId),
                      ),
                    ),
                  ),
                ],
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
                'הקווסטים שלי',
                style:
                    displayFont(size: 20, weight: FontWeight.w800),
              ),
              const Spacer(),
              ScaleTap(
                onTap: () => context.pushFadeUp(
                  (_) => CreateQuestScreen(familyId: familyId),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppPalette.gold,
                        AppPalette.goldDeep,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppPalette.gold.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add,
                          color: AppPalette.bgDeep, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'חדש',
                        style: displayFont(
                          size: 13,
                          weight: FontWeight.w900,
                          color: AppPalette.bgDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<Quest>>(
          stream: questService.watchFamilyQuests(familyId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppPalette.gold)),
              );
            }
            final quests = snap.data ?? const [];
            if (quests.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.fromLTRB(40, 16, 40, 32),
                child: Column(
                  children: [
                    const Text('🎯',
                        style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 10),
                    Text(
                      'אין עדיין קווסטים',
                      style: displayFont(
                          size: 18, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'לחץ "חדש" כדי ליצור את הראשון',
                      style: bodyFont(
                          size: 13, color: Colors.white60),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  for (final q in quests) ...[
                    _AdminQuestCard(
                      quest: q,
                      onEdit: () => context.pushFadeUp(
                        (_) => CreateQuestScreen(
                          familyId: familyId,
                          existing: q,
                        ),
                      ),
                      onDelete: () => _confirmDelete(
                        context,
                        title: 'למחוק את הקווסט?',
                        body: q.title,
                        onConfirm: () =>
                            questService.deactivate(q.id),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'הפרסים שלי',
            style: displayFont(size: 20, weight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<Reward>>(
          stream: rewardService.watchFamilyRewards(familyId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppPalette.gold)),
              );
            }
            final rewards = snap.data ?? const [];
            if (rewards.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(40, 8, 40, 100),
                child: Column(
                  children: [
                    const Text('🎁',
                        style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 10),
                    Text(
                      'אין עדיין פרסים',
                      style: displayFont(
                          size: 16, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'גש ל"ניהול פרסים" כדי להוסיף',
                      style: bodyFont(
                          size: 12, color: Colors.white60),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                children: [
                  for (final r in rewards) ...[
                    _AdminRewardCard(
                      reward: r,
                      onDelete: () => _confirmDelete(
                        context,
                        title: 'למחוק את הפרס?',
                        body: r.title,
                        onConfirm: () =>
                            rewardService.deactivate(r.id),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppPalette.surface,
          title: Text(title, style: displayFont(weight: FontWeight.w800)),
          content: Text(body, style: bodyFont()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('ביטול',
                  style: bodyFont(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('מחק',
                  style: bodyFont(color: AppPalette.pink)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await onConfirm();
    }
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.familyId,
    required this.instanceService,
    required this.rewardService,
    required this.walletService,
    required this.onTap,
  });
  final String familyId;
  final QuestInstanceService instanceService;
  final RewardService rewardService;
  final WalletService walletService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuestInstance>>(
      stream: instanceService.watchPendingApprovals(familyId),
      builder: (context, qSnap) {
        return StreamBuilder<List<PendingPurchase>>(
          stream: rewardService.watchPendingPurchases(familyId),
          builder: (context, pSnap) {
            return StreamBuilder<List<PendingTransfer>>(
              stream:
                  walletService.watchPendingTransfers(familyId),
              builder: (context, tSnap) {
                final count = (qSnap.data?.length ?? 0) +
                    (pSnap.data?.length ?? 0) +
                    (tSnap.data?.length ?? 0);
                final has = count > 0;
                return ScaleTap(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: has
                            ? const [
                                Color(0xFF551A33),
                                Color(0xFF1A1B3A),
                                Color(0xFF3F1A55),
                              ]
                            : const [
                                Color(0xFF34206B),
                                Color(0xFF1A1B3A),
                                Color(0xFF3F1A55),
                              ],
                      ),
                      boxShadow: has
                          ? [
                              BoxShadow(
                                color: AppPalette.pink
                                    .withValues(alpha: 0.35),
                                blurRadius: 22,
                                spreadRadius: -2,
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: has
                                ? AppPalette.pink
                                    .withValues(alpha: 0.2)
                                : Colors.white
                                    .withValues(alpha: 0.06),
                            border: Border.all(
                              color: has
                                  ? AppPalette.pink
                                  : Colors.white
                                      .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            has ? '⏳' : '✨',
                            style:
                                const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                has
                                    ? '$count ממתינים לאישור'
                                    : 'אין מה לאשר',
                                style: displayFont(
                                  size: 18,
                                  weight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                has
                                    ? 'משימות, קניות והעברות'
                                    : 'הכל מטופל. עבודה טובה!',
                                style: bodyFont(
                                  size: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left,
                            color: has
                                ? AppPalette.pink
                                : Colors.white24),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminLink extends StatelessWidget {
  const _AdminLink({
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: displayFont(size: 13, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminQuestCard extends StatelessWidget {
  const _AdminQuestCard({
    required this.quest,
    required this.onEdit,
    required this.onDelete,
  });
  final Quest quest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  List<Color> _gradFor(QuestDifficulty d) {
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
    final grad = _gradFor(quest.difficulty);
    return ScaleTap(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppPalette.bgDeep,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad
                        .map((c) => c.withValues(alpha: 0.3))
                        .toList(),
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(quest.icon,
                    style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: displayFont(
                          size: 15, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quest.points}⭐ · ${quest.xpReward} XP · ${quest.difficulty.label} · ${quest.recurrence.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyFont(
                          size: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              ScaleTap(
                onTap: onEdit,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_outlined,
                      color: grad.first, size: 18),
                ),
              ),
              const SizedBox(width: 6),
              ScaleTap(
                onTap: onDelete,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppPalette.pink.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppPalette.pink, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRewardCard extends StatelessWidget {
  const _AdminRewardCard({
    required this.reward,
    required this.onDelete,
  });
  final Reward reward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0x40FFD166),
                  Color(0x30EF476F),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color:
                      AppPalette.gold.withValues(alpha: 0.4)),
            ),
            child:
                Text(reward.icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: displayFont(
                      size: 15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.stock == null
                      ? '₪${reward.priceILS.toStringAsFixed(2)}'
                      : '₪${reward.priceILS.toStringAsFixed(2)} · מלאי ${reward.stock}',
                  style: bodyFont(
                      size: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          ScaleTap(
            onTap: onDelete,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.pink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline,
                  color: AppPalette.pink, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
