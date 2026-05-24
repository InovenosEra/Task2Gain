import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/reward.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/scale_tap.dart';
import 'main_navigation.dart';

/// Shop tab — wallet money strip + reward grid + buy action.
class ShopTab extends StatelessWidget {
  const ShopTab({super.key, required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final service = RewardService();
    final firestore = FirebaseFirestore.instance;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: Text(
            'חנות פרסים 🎁',
            style: displayFont(size: 26, weight: FontWeight.w900),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestore.collection('wallets').doc(data.uid).snapshots(),
            builder: (context, snap) {
              final wallet = snap.data?.data() ?? const {};
              final money =
                  (wallet['moneyILS'] as num?)?.toDouble() ?? 0.0;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF34206B),
                      Color(0xFF1A1B3A),
                      Color(0xFF3F1A55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.gold.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 34)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'יש לי בארנק',
                            style: bodyFont(
                                size: 12,
                                color: Colors.white60,
                                letterSpacing: 0.4),
                          ),
                          const SizedBox(height: 2),
                          GradientText(
                            '₪${money.toStringAsFixed(2)}',
                            style: displayFont(
                              size: 30,
                              weight: FontWeight.w900,
                              height: 1.0,
                            ),
                            colors: AppPalette.heroGrad,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        StreamBuilder<List<Reward>>(
          stream: service.watchFamilyRewards(data.familyId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppPalette.gold)),
              );
            }
            final rewards = snap.data ?? const [];
            if (rewards.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(40, 32, 40, 80),
                child: Column(
                  children: [
                    const Text('🪄', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 14),
                    Text(
                      'אין עדיין פרסים',
                      textAlign: TextAlign.center,
                      style: displayFont(
                          size: 20, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.role == 'admin'
                          ? 'הוסף פרסים בלשונית "ניהול"'
                          : 'בקש מההורה להוסיף פרסים',
                      textAlign: TextAlign.center,
                      style: bodyFont(
                          size: 13, color: Colors.white60),
                    ),
                  ],
                ),
              );
            }
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: rewards.length,
              itemBuilder: (_, i) => _ShopCard(
                reward: rewards[i],
                buyerUid: data.uid,
                service: service,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ShopCard extends StatefulWidget {
  const _ShopCard({
    required this.reward,
    required this.buyerUid,
    required this.service,
  });
  final Reward reward;
  final String buyerUid;
  final RewardService service;

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    try {
      await widget.service.requestPurchase(
        reward: widget.reward,
        buyerUid: widget.buyerUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.green,
          content: Text(
            'הבקשה נשלחה לאישור! 🎉',
            style: bodyFont(
              color: AppPalette.bgDeep,
              weight: FontWeight.w800,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.pink,
          content: Text('שגיאה: $e', style: bodyFont()),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppPalette.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x40FFD166), Color(0x30EF476F)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(r.icon, style: const TextStyle(fontSize: 56)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            r.title,
            style: displayFont(size: 14, weight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '₪${r.priceILS.toStringAsFixed(2)}',
            style: displayFont(
                size: 16,
                weight: FontWeight.w900,
                color: AppPalette.gold),
          ),
          const SizedBox(height: 8),
          ScaleTap(
            onTap: _busy ? null : _buy,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: _busy
                      ? [
                          AppPalette.gold.withValues(alpha: 0.4),
                          AppPalette.goldDeep.withValues(alpha: 0.4),
                        ]
                      : const [
                          AppPalette.gold,
                          AppPalette.goldDeep,
                        ],
                ),
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.bgDeep,
                        ),
                      )
                    : Text(
                        'קנה',
                        style: displayFont(
                          size: 14,
                          weight: FontWeight.w900,
                          color: AppPalette.bgDeep,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
