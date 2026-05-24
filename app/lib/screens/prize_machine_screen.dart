import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/prize.dart';
import '../services/prize_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/prize_wheel.dart';
import '../widgets/scale_tap.dart';
import '../widgets/scratch_card.dart';
import '../widgets/screen_chrome.dart';
import 'main_navigation.dart';

class PrizeMachineScreen extends StatefulWidget {
  const PrizeMachineScreen({super.key, required this.data});
  final HomeData data;

  @override
  State<PrizeMachineScreen> createState() => _PrizeMachineScreenState();
}

class _PrizeMachineScreenState extends State<PrizeMachineScreen> {
  final _service = PrizeService();
  final _rng = Random();
  bool _spinning = false;
  int _wheelTarget = 0;
  PrizeReward? _pendingWheel;
  PrizeReward? _scratchReward;
  String? _error;

  Future<int> _tokens() async {
    final snap = await FirebaseFirestore.instance
        .collection('wallets')
        .doc(widget.data.uid)
        .get();
    return (snap.data()?['tokens'] as num?)?.toInt() ?? 0;
  }

  Future<void> _playWheel() async {
    if (_spinning) return;
    if (await _tokens() <= 0) {
      setState(() => _error = 'אין לך אסימונים. תרוויח עוד! 🎯');
      return;
    }
    final reward = rollWheel(_rng);
    setState(() {
      _error = null;
      _pendingWheel = reward;
      _wheelTarget = wheelSegmentIndex(reward);
      _spinning = true;
    });
  }

  String _friendlyError(Object e) =>
      e is StateError ? e.message : 'שגיאה';

  Future<void> _onWheelSettled() async {
    final reward = _pendingWheel;
    _pendingWheel = null;
    if (reward == null) {
      if (mounted) setState(() => _spinning = false);
      return;
    }
    try {
      await _service.award(
          uid: widget.data.uid,
          familyId: widget.data.familyId,
          game: 'wheel',
          reward: reward);
      if (mounted) _showWin(reward);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  Future<void> _startScratch() async {
    if (await _tokens() <= 0) {
      setState(() => _error = 'אין לך אסימונים. תרוויח עוד! 🎯');
      return;
    }
    setState(() {
      _error = null;
      _scratchReward = rollScratch(_rng);
    });
  }

  Future<void> _onScratchComplete() async {
    final reward = _scratchReward;
    if (reward == null) return;
    try {
      await _service.award(
          uid: widget.data.uid,
          familyId: widget.data.familyId,
          game: 'scratch',
          reward: reward);
      if (mounted) {
        setState(() => _scratchReward = null);
        _showWin(reward);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    }
  }

  void _showWin(PrizeReward reward) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppPalette.bgDeep,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.gold, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(reward.emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              GradientText('זכית!',
                  style: displayFont(size: 28, weight: FontWeight.w900),
                  colors: AppPalette.heroGrad),
              const SizedBox(height: 6),
              Text(reward.label,
                  style: displayFont(size: 18, weight: FontWeight.w800)),
              const SizedBox(height: 16),
              ScaleTap(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppPalette.gold, AppPalette.goldDeep]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('אחלה',
                      style: displayFont(
                          size: 16,
                          weight: FontWeight.w900,
                          color: AppPalette.bgDeep)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenChrome(
      title: 'מכונת הפרסים 🎰',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _TokenBalance(uid: widget.data.uid),
          const SizedBox(height: 16),
          Center(
            child: PrizeWheel(
              targetIndex: _wheelTarget,
              spinning: _spinning,
              onSettled: _onWheelSettled,
            ),
          ),
          const SizedBox(height: 8),
          _PlayButton(label: 'סובב! (אסימון 1)', onTap: _playWheel),
          const SizedBox(height: 28),
          Text('כרטיס גירוד', style: displayFont(size: 18, weight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (_scratchReward != null)
            ScratchCard(
                reward: _scratchReward!, onComplete: _onScratchComplete)
          else
            _PlayButton(label: 'כרטיס חדש (אסימון 1)', onTap: _startScratch),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: bodyFont(color: AppPalette.pink)),
          ],
          const SizedBox(height: 24),
          Text('זכיות אחרונות',
              style: displayFont(size: 16, weight: FontWeight.w900)),
          const SizedBox(height: 8),
          _RecentWins(service: _service, familyId: widget.data.familyId),
        ],
      ),
    );
  }
}

class _TokenBalance extends StatelessWidget {
  const _TokenBalance({required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots(),
      builder: (context, snap) {
        final tokens = (snap.data?.data()?['tokens'] as num?)?.toInt() ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [
              AppPalette.violet.withValues(alpha: 0.4),
              AppPalette.sky.withValues(alpha: 0.3),
            ]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎟️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text('$tokens אסימונים',
                  style: displayFont(size: 22, weight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
              colors: [AppPalette.gold, AppPalette.goldDeep]),
        ),
        child: Center(
          child: Text(label,
              style: displayFont(
                  size: 18,
                  weight: FontWeight.w900,
                  color: AppPalette.bgDeep)),
        ),
      ),
    );
  }
}

class _RecentWins extends StatelessWidget {
  const _RecentWins({required this.service, required this.familyId});
  final PrizeService service;
  final String familyId;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PrizeWin>>(
      stream: service.watchRecentWins(familyId),
      builder: (context, snap) {
        final wins = snap.data ?? const [];
        if (wins.isEmpty) {
          return Text('עוד אין זכיות — תהיה הראשון! ✨',
              style: bodyFont(size: 13, color: Colors.white60));
        }
        return Column(
          children: [
            for (final w in wins)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(w.game == 'wheel' ? '🎡' : '🎫',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(w.rewardLabel,
                          style: bodyFont(size: 13, color: Colors.white70)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
