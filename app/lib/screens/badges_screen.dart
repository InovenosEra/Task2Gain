import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/badge.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/screen_chrome.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return ScreenChrome(
      title: 'ההישגים שלי 🏅',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? const {};
          final earnedIds = ((data['badges'] as List?) ?? [])
              .map((b) => (b is Map ? b['id'] as String? : null) ?? '')
              .toSet();
          final earnedCount = earnedIds.length;
          final total = badgeCatalog.length;
          final progress = total == 0 ? 0.0 : earnedCount / total;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
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
                        color: AppPalette.violet.withValues(alpha: 0.35),
                        blurRadius: 26,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GradientText(
                            '$earnedCount',
                            style: displayFont(
                              size: 56,
                              weight: FontWeight.w900,
                              height: 1.0,
                            ),
                            colors: AppPalette.heroGrad,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              ' / $total',
                              style: displayFont(
                                size: 22,
                                weight: FontWeight.w700,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'הישגים',
                            style: bodyFont(
                              size: 14,
                              color: Colors.white70,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor:
                              const AlwaysStoppedAnimation(AppPalette.gold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: badgeCatalog.length,
                  itemBuilder: (_, i) {
                    final b = badgeCatalog[i];
                    return _BadgeTile(
                        badge: b, earned: earnedIds.contains(b.id));
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});
  final BadgeDefinition badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: earned
            ? AppPalette.gold.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: earned
              ? AppPalette.gold.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.06),
          width: earned ? 1.4 : 1,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: AppPalette.gold.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: earned ? 1 : 0.22,
            child: Text(badge.icon, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 8),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: displayFont(
              size: 12,
              weight: FontWeight.w800,
              color: earned ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: bodyFont(
              size: 10,
              color: earned ? Colors.white70 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
