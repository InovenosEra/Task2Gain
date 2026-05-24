import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/quest_instance.dart';
import '../services/quest_instance_service.dart';
import '../services/reward_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_chrome.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key, required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) {
    return ScreenChrome(
      title: 'אישורים ממתינים',
      child: _CombinedFeed(
        familyId: familyId,
        questService: QuestInstanceService(),
        rewardService: RewardService(),
        walletService: WalletService(),
      ),
    );
  }
}

class _CombinedFeed extends StatelessWidget {
  const _CombinedFeed({
    required this.familyId,
    required this.questService,
    required this.rewardService,
    required this.walletService,
  });
  final String familyId;
  final QuestInstanceService questService;
  final RewardService rewardService;
  final WalletService walletService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuestInstance>>(
      stream: questService.watchPendingApprovals(familyId),
      builder: (context, questSnap) {
        return StreamBuilder<List<PendingPurchase>>(
          stream: rewardService.watchPendingPurchases(familyId),
          builder: (context, purchaseSnap) {
            return StreamBuilder<List<PendingTransfer>>(
              stream: walletService.watchPendingTransfers(familyId),
              builder: (context, transferSnap) {
                final loading =
                    questSnap.connectionState == ConnectionState.waiting ||
                        purchaseSnap.connectionState ==
                            ConnectionState.waiting ||
                        transferSnap.connectionState ==
                            ConnectionState.waiting;
                if (loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppPalette.gold),
                  );
                }
                final quests = questSnap.data ?? const [];
                final purchases = purchaseSnap.data ?? const [];
                final transfers = transferSnap.data ?? const [];
                if (quests.isEmpty &&
                    purchases.isEmpty &&
                    transfers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨',
                              style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 14),
                          Text(
                            'אין מה לאשר',
                            style: displayFont(
                                size: 20, weight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'הכל מטופל. עבודה טובה!',
                            style: bodyFont(
                                size: 13, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (quests.isNotEmpty) ...[
                      _Section(label: 'משימות', count: quests.length),
                      const SizedBox(height: 8),
                      for (final q in quests) ...[
                        _QuestApprovalCard(
                            instance: q, service: questService),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ],
                    if (purchases.isNotEmpty) ...[
                      _Section(label: 'קניות', count: purchases.length),
                      const SizedBox(height: 8),
                      for (final p in purchases) ...[
                        _PurchaseApprovalCard(
                            purchase: p, service: rewardService),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ],
                    if (transfers.isNotEmpty) ...[
                      _Section(label: 'העברות', count: transfers.length),
                      const SizedBox(height: 8),
                      for (final t in transfers) ...[
                        _TransferApprovalCard(
                            transfer: t, service: walletService),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        children: [
          Text(label,
              style: displayFont(
                  size: 14, weight: FontWeight.w800, color: AppPalette.gold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: AppPalette.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: bodyFont(
                  size: 11,
                  weight: FontWeight.w800,
                  color: AppPalette.gold,
                )),
          ),
        ],
      ),
    );
  }
}

class _QuestApprovalCard extends StatefulWidget {
  const _QuestApprovalCard({required this.instance, required this.service});
  final QuestInstance instance;
  final QuestInstanceService service;

  @override
  State<_QuestApprovalCard> createState() => _QuestApprovalCardState();
}

class _QuestApprovalCardState extends State<_QuestApprovalCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function(String adminUid) op) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    setState(() => _busy = true);
    try {
      await op(adminUid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e', style: bodyFont())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inst = widget.instance;
    return _ApprovalCardShell(
      child: Column(
        children: [
          Row(
            children: [
              _IconBox(emoji: inst.icon, color: AppPalette.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inst.title,
                      style: displayFont(
                          size: 16, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${inst.points}⭐  ·  +${inst.xpReward} XP',
                      style: bodyFont(
                          size: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (inst.proofPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                inst.proofPhotos.first,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 80,
                  color: Colors.white.withValues(alpha: 0.04),
                  alignment: Alignment.center,
                  child: Text('תמונה לא נטענה',
                      style: bodyFont(color: Colors.white54)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _RowButtons(
            busy: _busy,
            onReject: () => _act((u) => widget.service.reject(
                  instanceId: inst.id,
                  adminUid: u,
                )),
            onApprove: () => _act((u) => widget.service.approve(
                  instanceId: inst.id,
                  adminUid: u,
                )),
          ),
        ],
      ),
    );
  }
}

class _PurchaseApprovalCard extends StatefulWidget {
  const _PurchaseApprovalCard({
    required this.purchase,
    required this.service,
  });
  final PendingPurchase purchase;
  final RewardService service;

  @override
  State<_PurchaseApprovalCard> createState() =>
      _PurchaseApprovalCardState();
}

class _PurchaseApprovalCardState extends State<_PurchaseApprovalCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function(String adminUid) op) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    setState(() => _busy = true);
    try {
      await op(adminUid);
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: bodyFont())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e', style: bodyFont())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    return _ApprovalCardShell(
      child: Column(
        children: [
          Row(
            children: [
              _IconBox(emoji: p.rewardIcon, color: AppPalette.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'בקשת קנייה: ${p.rewardTitle}',
                      style: displayFont(
                          size: 15, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'סכום: ₪${p.amount.toStringAsFixed(2)}',
                      style: bodyFont(
                          size: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RowButtons(
            busy: _busy,
            onReject: () => _act((u) => widget.service.rejectPurchase(
                  transactionId: p.id,
                  adminUid: u,
                )),
            onApprove: () => _act((u) => widget.service.approvePurchase(
                  transactionId: p.id,
                  adminUid: u,
                )),
          ),
        ],
      ),
    );
  }
}

class _TransferApprovalCard extends StatefulWidget {
  const _TransferApprovalCard({
    required this.transfer,
    required this.service,
  });
  final PendingTransfer transfer;
  final WalletService service;

  @override
  State<_TransferApprovalCard> createState() =>
      _TransferApprovalCardState();
}

class _TransferApprovalCardState extends State<_TransferApprovalCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function(String adminUid) op) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    setState(() => _busy = true);
    try {
      await op(adminUid);
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: bodyFont())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e', style: bodyFont())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return _ApprovalCardShell(
      child: Column(
        children: [
          Row(
            children: [
              _IconBox(emoji: '💸', color: AppPalette.sky),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'בקשת העברה ל-${t.channel}',
                      style: displayFont(
                          size: 15, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₪${t.amount.toStringAsFixed(2)} מהארנק',
                      style: bodyFont(
                          size: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'אחרי אישור: בצע את ההעברה ב-CashCash בעצמך.',
                      style: bodyFont(
                          size: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RowButtons(
            busy: _busy,
            onReject: () => _act((u) => widget.service.rejectTransfer(
                  transactionId: t.id,
                  adminUid: u,
                )),
            onApprove: () => _act((u) => widget.service.completeTransfer(
                  transactionId: t.id,
                  adminUid: u,
                )),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCardShell extends StatelessWidget {
  const _ApprovalCardShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.emoji, required this.color});
  final String emoji;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 26)),
    );
  }
}

class _RowButtons extends StatelessWidget {
  const _RowButtons({
    required this.busy,
    required this.onReject,
    required this.onApprove,
  });
  final bool busy;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ScaleTap(
            onTap: busy ? null : onReject,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppPalette.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppPalette.pink.withValues(alpha: 0.6),
                ),
              ),
              child: Center(
                child: Text(
                  'דחה',
                  style: displayFont(
                      size: 14,
                      weight: FontWeight.w800,
                      color: AppPalette.pink),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ScaleTap(
            onTap: busy ? null : onApprove,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: busy
                      ? [
                          AppPalette.green.withValues(alpha: 0.4),
                          AppPalette.sky.withValues(alpha: 0.4),
                        ]
                      : const [AppPalette.green, AppPalette.sky],
                ),
                boxShadow: busy
                    ? null
                    : [
                        BoxShadow(
                          color: AppPalette.green.withValues(alpha: 0.4),
                          blurRadius: 14,
                          spreadRadius: -2,
                        ),
                      ],
              ),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppPalette.bgDeep),
                      )
                    : Text(
                        'אשר',
                        style: displayFont(
                            size: 14,
                            weight: FontWeight.w900,
                            color: AppPalette.bgDeep),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
